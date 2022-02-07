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

Bio::EnsEMBL::Production::Pipeline::AttributeAnnotation::LoadAppris

=head1 DESCRIPTION

Load the APPRIS annotation as transcript attributes.

=cut

package Bio::EnsEMBL::Production::Pipeline::AttributeAnnotation::LoadAppris;

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

  my $code = 'appris';
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

  my ($appris_results, $appris_transcripts) = $self->load_file;

  my @slices =
    @{ $sa->fetch_all( $coord_system_name, $coord_system_version, 1, undef ) };

  my $stable_id_in_file = 0;
  foreach my $slice (@slices) {
    my $gene_cnt       = 0;
    my $transc_cnt     = 0;
    my $transc_no_data = 0;

    # now look for new candidates
    foreach my $gene ( @{ $slice->get_all_Genes } ) {
      $gene_cnt++;
      foreach my $transcript ( @{ $gene->get_all_Transcripts } ) {
        $transc_cnt++;
        if (exists $$appris_results{ $gene->stable_id }{ $transcript->stable_id } ){
          $stable_id_in_file++;
          my $res = $$appris_results{ $gene->stable_id }->{ $transcript->stable_id };
          $aa->store_on_Transcript( $transcript, [
                                      Bio::EnsEMBL::Attribute->new(
                                                   -NAME  => $attrib->[2],
                                                   -CODE  => $attrib->[1],
                                                   -VALUE => $res->{attrib_value},
                                                   -DESCRIPTION => $attrib->[3]
                                      ) ] );
        }
        else {
          # this is likely a new transcript that wasn't annotated last release
          $transc_no_data++;
        }
      }
    }
  }

  if ( $stable_id_in_file != $appris_transcripts ) {
    $self->throw("Not all transcripts found in database");
  }
  
  $dba->dbc->disconnect_if_idle();
}

sub load_file {
  my ($self) = @_;

  my $file = $self->param_required('file');

  my $label2code = { 'PRINCIPAL:1'   => [ 'appris', 'principal1' ],
                     'PRINCIPAL:2'   => [ 'appris', 'principal2' ],
                     'PRINCIPAL:3'   => [ 'appris', 'principal3' ],
                     'PRINCIPAL:4'   => [ 'appris', 'principal4' ],
                     'PRINCIPAL:5'   => [ 'appris', 'principal5' ],
                     'ALTERNATIVE:1' => [ 'appris', 'alternative1' ],
                     'ALTERNATIVE:2' => [ 'appris', 'alternative2' ], };

  my %appris_results;
  my %appris_transcripts;
  open( INFILE, "<$file" ) or die("Can't read $file $! \n");
  while ( my $line = <INFILE> ) {
    chomp $line;
    my ( $gene_id, $transcript_id, $label ) = split( /[ \t]+/, $line );
    $appris_transcripts{$transcript_id} = 1;

    # "appris_principal", transcript(s) expected to code for the main functional isoform based on a range of protein features (APPRIS pipeline, Nucleic Acids Res. 2013 Jan;41(Database issue):D110-7).
    # "appris_candidate", where there is no 'appris_principal' variant(s) the main functional isoform will be translated from one of the 'appris_candidate' genes. APPRIS selects one of the `appris_candidates' to be the most probable principal isoform, these have one of three labels:
    # "appris_candidate_ccds", the `appris_candidate' transcript that has an unique CCDS.
    # "appris_candidate_longest_ccds", the `appris_candidate' transcripts where there are several CCDS, in this case APPRIS labels the longest CCDS.
    # "appris_candidate_longest_seq", where there is no 'appris_candidate_ccds' or ` appris_candidate_longest_ccds' variant, the longest protein of the 'appris_candidate' variants is selected as the primary variant.
    if ( exists $label2code->{$label} ) {
      $appris_results{$gene_id}{$transcript_id}{'attrib_type_code'} =
        $label2code->{$label}->[0];
      $appris_results{$gene_id}{$transcript_id}{'attrib_value'} =
        $label2code->{$label}->[1];
    } else {
      throw("Label $label not recognised in label2code hash");
    }
  }
  close INFILE;

  return (\%appris_results, scalar(keys %appris_transcripts));
}

1;
