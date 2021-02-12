=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_mouse_strains_conf

=head1 DESCRIPTION

Gene name and description projection

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_mouse_strains_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_conf');

sub default_options {
  my ($self) = @_;

  return {
    %{ $self->SUPER::default_options() },

    compara_division => 'multi',
    pipeline_name    => 'gene_name_desc_projection_mouse_strains_'.$self->o('ensembl_release'),

    is_tree_compliant => 0,

    gene_name_source => ['MGI']

    project_xrefs => 1,
    white_list    => [
                       'RefSeq_mRNA',
                       'RefSeq_mRNA_predicted',
                       'RefSeq_ncRNA',
                       'RefSeq_ncRNA_predicted',
                       'RefSeq_peptide',
                       'RefSeq_peptide_predicted',
                       'EntrezGene',
                       'EntrezGene_trans_name',
                       'WikiGene',
                       'Uniprot/SPTREMBL',
                       'Uniprot/SWISSPROT',
                       'Uniprot_gn',
                       'protein_id',
                       'UniParc',
                       'ArrayExpress',
                       'RNACentral',
                       'MGI',
                       'MGI_trans_name',
                       'miRBase',
                       'miRBase_trans_name',
                       'RFAM',
                       'RFAM_trans_name',
                     ],

    gn_config => [
      {
        source              => 'mus_musculus',
        taxons              => ['Mus'],
        antispecies         => ['mus_musculus','mus_spretus','mus_pahari','mus_caroli'],
        project_trans_names => 1,
      },
    ],
    
    gd_config => [
      {
        source      => 'mus_musculus',
        taxons      => ['Mus'],
        antispecies => ['mus_musculus','mus_spretus','mus_pahari','mus_caroli'],
      },
    ],
  };
}

1;
