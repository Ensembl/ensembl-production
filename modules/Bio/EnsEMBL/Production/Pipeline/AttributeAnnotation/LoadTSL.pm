=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::AttributeAnnotation::LoadTSL

=head1 DESCRIPTION

Load the TSL annotation as transcript attributes.

=cut

package Bio::EnsEMBL::Production::Pipeline::AttributeAnnotation::LoadTSL;

use strict;
use warnings;

use base('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Bio::EnsEMBL::Attribute;

sub run {
  my ($self) = @_;

  my $dba = $self->core_dba();
  my $aa  = $dba->get_adaptor('Attribute');
  my $mca = $dba->get_adaptor('MetaContainer');
  my $sa  = $dba->get_adaptor('Slice');

  my $code = 'TSL';
  my $coord_system_name = 'toplevel';
  my $coord_system_version = $mca->single_value_by_key('assembly.default');

  my $sql = q/
    DELETE ta.* FROM
      transcript_attrib ta INNER JOIN
      attrib_type att USING (attrib_type_id)
    WHERE att.code = ?
  /;
  $dba->dbc->sql_helper->execute_update(-SQL => $sql, -PARAMS => [$code]);

  my $attrib = $aa->fetch_by_code($code);

  my %support_levels = %{ $self->load_file };

  my @slices =
    @{ $sa->fetch_all( $coord_system_name, $coord_system_version, 1, undef ) };

  my $stable_id_in_file = 0;
  foreach my $slice (@slices) {
    my $gene_cnt        = 0;
    my $transc_cnt      = 0;
    my $transc_uptodate = 0;
    my $transc_no_data  = 0;
    my $transc_updated  = 0;

    # now look for new candidates
    foreach my $gene ( @{ $slice->get_all_Genes } ) {
      $gene_cnt++;
      foreach my $transcript ( @{ $gene->get_all_Transcripts } ) {
        $transc_cnt++;

        if ( exists $support_levels{ $transcript->stable_id } ) {
          if ( $transcript->version == $support_levels{ $transcript->stable_id }{'version'} )
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

          }
          else {
            # annotation likely changed since last release
            $transc_updated++;
            $stable_id_in_file++;

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
          }
        }
        else {
          # this is likely a new transcript that wasn't annotated last release
          $transc_no_data++;
        }
      }
    }
    $self->info("Slice " . $slice->seq_region_name .
                " has $gene_cnt genes with $transc_cnt transcripts. " .
                "There are $transc_uptodate with current attributes, " .
                "$transc_updated transcripts with updated annotation " .
                "and $transc_no_data with no attributes");
  }

  $self->info("Matched stable_ids for $stable_id_in_file of " .
              (scalar(keys %support_levels)) . " transcripts in file");

  $dba->dbc->disconnect_if_idle();
}

sub load_file {
  my ($self) = @_;

  my $file = $self->param_required('file');
  (my $unzipped_file = $file) =~ s/\.gz$//;
  $self->run_cmd("gunzip -c $file > $unzipped_file");

  my %support_levels;

  open( INFILE, "<$unzipped_file" ) or die("Can't read $unzipped_file $! \n");
  while ( my $line = <INFILE> ) {
    chomp $line;
    my @fields = split( /\t/, $line );
    my ( $transcript_id, $version ) = split( /\./, $fields[0] );
    my $support_level = $fields[1];
    $support_levels{$transcript_id}{'version'}       = $version;
    $support_levels{$transcript_id}{'support_level'} = $support_level;
  }
  close INFILE;

  unlink $unzipped_file;
  
  return \%support_levels;
}

1;
