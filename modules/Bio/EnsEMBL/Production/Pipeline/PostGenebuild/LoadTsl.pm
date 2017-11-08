
=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PostGenebuild::LoadTsl

=cut

package Bio::EnsEMBL::Production::Pipeline::PostGenebuild::LoadTsl;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Attribute;
use base('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub run {
  my ($self) = @_;

  my $db = $self->core_dba();

  my $file = $self->param_required('file');

  my $sa = $db->get_SliceAdaptor();
  my $aa = $db->get_AttributeAdaptor();

  my $code = 'TSL';

  # delete old attribs
  print STDERR " Deleting old attributes...\n";
  $db->dbc()->sql_helper()->execute_update(
    -SQL => q/DELETE ta
    FROM transcript_attrib ta
    JOIN attrib_type att USING (attrib_type_id)
    WHERE att.code = ?/
      -PARAMS => [$code] );

  my $attrib = $aa->fetch_by_code($code);

  # read in file containing new attributes
  my %support_levels;
  open( INFILE, "<$file" ) or die("Can't read $file $! \n");
  while ( my $line = <INFILE> ) {
    chomp $line;
    my @fields = split( /\t/, $line );
    my ( $transcript_id, $version ) = split( /\./, $fields[0] );
    my $support_level = $fields[1];
    $support_levels{$transcript_id}{'version'}       = $version;
    $support_levels{$transcript_id}{'support_level'} = $support_level;
  }
  close INFILE;
  print STDERR "Fetched " . ( scalar( keys %support_levels ) ) .
    " new attributes\n";

  # # #
  # Fetch the sequences we are interested in - all or subset
  # # #
  my @slices =
    @{ $sa->fetch_all( $coord_system_name, $coord_system_version, 1, undef ) };
  print STDERR "Got " . ( scalar(@slices) ) . " slices\n";

  # # #
  # Now loop through each slices
  # and then each gene on the slice
  # # #
  my $stable_id_in_file = 0;
  foreach my $slice (@slices) {
    print STDERR "Doing slice " . $slice->seq_region_name . "\n";
    my $gene_cnt        = 0;
    my $transc_cnt      = 0;
    my $transc_uptodate = 0;
    my $transc_no_data  = 0;
    my $transc_updated  = 0;

    # now look for new candidates
    foreach my $gene ( @{ $slice->get_all_Genes } ) {
      #print STDERR "Gene ".$gene->stable_id."\n";
      $gene_cnt++;
      foreach my $transcript ( @{ $gene->get_all_Transcripts } ) {
        $transc_cnt++;

        if ( exists $support_levels{ $transcript->stable_id } ) {
          # oh good, found this stable ID
          if ( $transcript->version == $support_levels{ $transcript->stable_id }
               {'version'} )
          {
            # up to date
            $transc_uptodate++;
            $stable_id_in_file++;
            $aa->store_on_Transcript(
               $transcript, [
                 Bio::EnsEMBL::Attribute->new(
                   -NAME => $attrib->[2],
                   -CODE => $attrib->[1],
                   -VALUE =>
                     $support_levels{ $transcript->stable_id }{'support_level'},
                   -DESCRIPTION => $attrib->[3] ) ] );

            print STDERR "  writing " . $transcript->stable_id . " version " .
              $transcript->version . " TSL " .
              $support_levels{ $transcript->stable_id }{'support_level'} . "\n";
          }
          else {
            # annotation likely changed since last release
            $transc_updated++;
            $stable_id_in_file++;
            warning("Transcript annotation mismatch " . $transcript->stable_id .
                      " version in Ensembl=" . $transcript->version .
                      " vs version in file=" .
                      $support_levels{ $transcript->stable_id }{'version'} );

            $aa->store_on_Transcript(
              $transcript, [
                Bio::EnsEMBL::Attribute->new(
                  -NAME => $attrib->[2],
                  -CODE => $attrib->[1],
                  -VALUE =>
                    $support_levels{ $transcript->stable_id }{'support_level'} .
                    " (assigned to previous version " .
                    $support_levels{ $transcript->stable_id }{'version'} . ")",
                  -DESCRIPTION => $attrib->[3] ) ] );

            print STDERR "  writing " . $transcript->stable_id . " version " .
              $transcript->version . " TSL " .
              $support_levels{ $transcript->stable_id }{'support_level'} . "\n";
          }
        } ## end if ( exists $support_levels...)
        else {
          # this is likely a new transcript that wasn't annotated last release
          $transc_no_data++;
          warning( "No data in file for " . $transcript->stable_id );
        }
      } ## end foreach my $transcript ( @{...})
    } ## end foreach my $gene ( @{ $slice...})
    print "Slice " . $slice->seq_region_name .
" has genes $gene_cnt with $transc_cnt transcripts. There are $transc_uptodate with current attributes, $transc_updated transcripts with updated annotation and $transc_no_data with no attributes\n";
  } ## end foreach my $slice (@slices)
  print "Matched stable_ids for " . $stable_id_in_file . " of " .
    ( scalar( keys %support_levels ) ) . " transcripts in file\n";
  print STDERR "DONE!\n\nNow grep for:\n^Slice and ^Matched\n\n";
  $db->dbc()->disconnect_if_idle();

  return;
} ## end sub run

1;
