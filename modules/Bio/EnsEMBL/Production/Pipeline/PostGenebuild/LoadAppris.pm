
=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::PostGenebuild::LoadAppris

=cut

package Bio::EnsEMBL::Production::Pipeline::PostGenebuild::LoadAppris;

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

  # # #
  # hard code the mapping
  # # #
  my $label2code = { 'PRINCIPAL:1'   => [ 'appris', 'principal1' ],
                     'PRINCIPAL:2'   => [ 'appris', 'principal2' ],
                     'PRINCIPAL:3'   => [ 'appris', 'principal3' ],
                     'PRINCIPAL:4'   => [ 'appris', 'principal4' ],
                     'PRINCIPAL:5'   => [ 'appris', 'principal5' ],
                     'ALTERNATIVE:1' => [ 'appris', 'alternative1' ],
                     'ALTERNATIVE:2' => [ 'appris', 'alternative2' ], };

  # delete old attribs
  print STDERR " Deleting old attributes...\n";
  my $attribs = {};
  foreach my $code ( values %{$label2code} ) {
    $db->dbc()->sql_helper()->execute_update(
      -SQL => q/DELETE ta
    FROM transcript_attrib ta
    JOIN attrib_type att USING (attrib_type_id)
    WHERE att.code = ?/
        -PARAMS => [ $code->[0] ] );
    $attribs->{$code} = $aa->fetch_by_code($code);
  }

  # read in file containing new attributes
  my %appris_results;
  my %appris_transcripts;    # be lazy
  open( INFILE, "<$file" ) or die("Can't read $file $! \n");
  while ( my $line = <INFILE> ) {
    chomp $line;
    my ( $gene_id, $transcript_id, $label ) = split( /[ \t]+/, $line );
    $appris_transcripts{$transcript_id} = 1;

# "appris_principal", transcript(s) expected to code for the main functional isoform based on a range of protein features (APPRIS pipeline, Nucleic Acids Res. 2013 Jan;41(Database issue):D110-7).
# "appris_candidate", where there is no 'appris_principal' variant(s) the main functional isoform will be translated from one of the 'appris_candidate' genes. APPRIS selects one of the `appris_candidates' to be the most probable principal isoform, these have one of three labels:
    ## "appris_candidate_ccds", the `appris_candidate' transcript that has an unique CCDS.
    ## "appris_candidate_longest_ccds", the `appris_candidate' transcripts where there are several CCDS, in this case APPRIS labels the longest CCDS.
    ## "appris_candidate_longest_seq", where there is no 'appris_candidate_ccds' or ` appris_candidate_longest_ccds' variant, the longest protein of the 'appris_candidate' variants is selected as the primary variant.
    if ( exists $label2code->{$label} ) {
      $appris_results{$gene_id}{$transcript_id}{'attrib_type_code'} =
        $label2code->{$label}->[0];
      $appris_results{$gene_id}{$transcript_id}{'attrib_value'} =
        $label2code->{$label}->[1];
    }
    else {
      throw("Label $label not recognised in label2code hash");
    }
  }
  close INFILE;
  print STDERR "Fetched " . ( scalar( keys %appris_results ) ) . " genes and " .
    ( scalar( keys %appris_transcripts ) ) . " transcripts\n";

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
    my $gene_cnt       = 0;
    my $transc_cnt     = 0;
    my $transc_no_data = 0;

    # now look for new candidates
    foreach my $gene ( @{ $slice->get_all_Genes } ) {
      #print STDERR "Gene ".$gene->stable_id."\n";
      $gene_cnt++;
      foreach my $transcript ( @{ $gene->get_all_Transcripts } ) {
        $transc_cnt++;

        if (
          exists $appris_results{ $gene->stable_id }{ $transcript->stable_id } )
        {
          # oh good, found this stable ID
          $stable_id_in_file++;

          my %res =
            $appris_results{ $gene->stable_id }{ $transcript->stable_id };

          my $attrib = $attribs->{ $res{attrib_type_code} };

          $aa->store_on_Transcript( $transcript, [
                                      Bio::EnsEMBL::Attribute->new(
                                                   -NAME  => $attrib->[2],
                                                   -CODE  => $attrib->[1],
                                                   -VALUE => $res{attrib_value},
                                                   -DESCRIPTION => $attrib->[3]
                                      ) ] )

            print STDERR "  writing gene " . $gene->stable_id . " transcript" .
            $transcript->stable_id . " APPRIS " . $res{attrib_type_code} . "\n";
        }
        else {
            # this is likely a new transcript that wasn't annotated last release
          $transc_no_data++;
          #warning("No data in file for ".$transcript->stable_id);
        }
      } ## end foreach my $transcript ( @{...})
    } ## end foreach my $gene ( @{ $slice...})
    print "Slice " . $slice->seq_region_name .
" has genes $gene_cnt with $transc_cnt transcripts. There are transcripts $transc_no_data with no attributes\n";
  } ## end foreach my $slice (@slices)
  print "Matched stable_ids for " . $stable_id_in_file . " of " .
    ( scalar( keys %appris_results ) ) . " transcripts in file\n";
  if ( $stable_id_in_file != scalar( keys %appris_transcripts ) ) {
    throw("Not all transcripts found in database");
  }
  print STDERR "DONE!\n\nNow grep for:\n^Slice and ^Matched\n\n";
  
  $db->dbc()->disconnect_if_idle();
  return;
} ## end sub run

1;
