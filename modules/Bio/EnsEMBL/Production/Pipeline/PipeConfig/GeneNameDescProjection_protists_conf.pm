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

=cut


=pod

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_protists_conf

=head1 DESCRIPTION

Gene name and description projection

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_protists_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_conf');

sub default_options {
  my ($self) = @_;

  return {
    %{ $self->SUPER::default_options() },

    compara_division => 'protists',

    gene_name_source => [ 'ENA_GENE', 'Uniprot/SWISSPROT', 'Uniprot_gn' ],

    gn_config => [
      {
        source      => 'dictyostelium_discoideum',
        taxons      => ['Amoebozoa'],
        antispecies => ['dictyostelium_discoideum'],
      },
    ],
    
    gd_config => [
      {
        source      => 'dictyostelium_discoideum',
        taxons      => ['Amoebozoa'],
        antispecies => ['dictyostelium_discoideum'],
      },
    ],
  };
}

1;
