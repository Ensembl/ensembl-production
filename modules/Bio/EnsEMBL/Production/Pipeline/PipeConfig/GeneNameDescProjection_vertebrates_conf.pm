=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_vertebrates_conf

=head1 DESCRIPTION

Gene name and description projection

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_vertebrates_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_conf');

sub default_options {
  my ($self) = @_;

  return {
    %{ $self->SUPER::default_options() },

    compara_division => 'multi',
    pipeline_name    => 'gene_name_desc_projection_vertebrates_'.$self->o('ensembl_release'),

    is_tree_compliant => 0,

    gn_config => [
      {
        source              => 'homo_sapiens',
        taxons              => ['Sarcopterygii'],
        antispecies         => ['homo_sapiens'],
        antitaxons          => ['Castorimorpha','Myomorpha'],
        gene_name_source    => ['HGNC'],
        project_trans_names => 1,
      },
      {
        source              => 'homo_sapiens',
        species             => ['mus_musculus'],
        gene_name_source    => ['HGNC'],
        project_trans_names => 1,
      },
      {
        source              => 'mus_musculus',
        taxons              => ['Castorimorpha','Myomorpha'],
        antispecies         => [
                                 'mus_musculus',
                                 'mus_musculus_129s1svimj',
                                 'mus_musculus_aj',
                                 'mus_musculus_akrj',
                                 'mus_musculus_balbcj',
                                 'mus_musculus_c3hhej',
                                 'mus_musculus_c57bl6nj',
                                 'mus_musculus_casteij',
                                 'mus_musculus_cbaj',
                                 'mus_musculus_dba2j',
                                 'mus_musculus_fvbnj',
                                 'mus_musculus_lpj', 
                                 'mus_musculus_nodshiltj',
                                 'mus_musculus_nzohlltj',
                                 'mus_musculus_pwkphj',
                                 'mus_musculus_wsbeij'
                               ],
        gene_name_source    => ['MGI'],
        project_trans_names => 1,
      },
      {
        source                 => 'danio_rerio',
        taxons                 => ['Actinopterygii','Cyclostomata','Coelacanthimorpha','Chondrichthyes'],
        antispecies            => ['danio_rerio'],
        gene_name_source       => ['ZFIN_ID'],
        project_trans_names    => 1,
        homology_types_allowed => ['ortholog_one2one','ortholog_one2many'],
      },
      {
        source                 => 'homo_sapiens',
        taxons                 => ['Actinopterygii','Cyclostomata','Chondrichthyes'],
        antispecies            => ['homo_sapiens'],
        gene_name_source       => ['HGNC'],
        project_trans_names    => 1,
        homology_types_allowed => ['ortholog_one2one','ortholog_one2many'],
      },
    ],

    gd_config => [
      {
        source           => 'homo_sapiens',
        taxons           => ['Sarcopterygii'],
        antispecies      => ['homo_sapiens'],
        antitaxons       => ['Castorimorpha','Myomorpha'],
        gene_name_source => ['HGNC'],
        gene_desc_rules  => [], 
      },
      {
        source           => 'homo_sapiens',
        species          => ['mus_musculus'],
        gene_name_source => ['HGNC'],
        gene_desc_rules  => [], 
      },
      {
        source           => 'mus_musculus',
        taxons           => ['Castorimorpha','Myomorpha'],
        antispecies      => [
                              'mus_musculus',
                              'mus_musculus_129s1svimj',
                              'mus_musculus_aj',
                              'mus_musculus_akrj',
                              'mus_musculus_balbcj',
                              'mus_musculus_c3hhej',
                              'mus_musculus_c57bl6nj',
                              'mus_musculus_casteij',
                              'mus_musculus_cbaj',
                              'mus_musculus_dba2j',
                              'mus_musculus_fvbnj',
                              'mus_musculus_lpj', 
                              'mus_musculus_nodshiltj',
                              'mus_musculus_nzohlltj',
                              'mus_musculus_pwkphj',
                              'mus_musculus_wsbeij'
                            ],
        gene_name_source => ['MGI'],
        gene_desc_rules  => [], 
      },
      {
        source                 => 'danio_rerio',
        taxons                 => ['Actinopterygii','Cyclostomata','Coelacanthimorpha','Chondrichthyes'],
        antispecies            => ['danio_rerio'],
        gene_name_source       => ['ZFIN_ID'],
        gene_desc_rules        => [], 
        homology_types_allowed => ['ortholog_one2one','ortholog_one2many'],
      },
      {
        source                 => 'homo_sapiens',
        taxons                 => ['Actinopterygii','Cyclostomata','Chondrichthyes'],
        antispecies            => ['homo_sapiens'],
        gene_name_source       => ['HGNC'],
        gene_desc_rules        => [], 
        homology_types_allowed => ['ortholog_one2one','ortholog_one2many'],
      },
    ],
  };
}

1;
