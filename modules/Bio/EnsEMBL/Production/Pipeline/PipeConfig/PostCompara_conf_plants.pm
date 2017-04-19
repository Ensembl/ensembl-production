=head1 LICENSE

Copyright [1999-2016] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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

Bio::EnsEMBL::Production::Pipeline::PipeConfig::PostCompara_conf_plants

=head1 DESCRIPTION

Configuration for running the Post Compara pipeline, which
run the Gene name, description and GO projections as well as Gene coverage.

=head1 Author

ckong

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::PostCompara_conf_plants;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::PostCompara_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
  my ($self) = @_;    
  return {
          # inherit other stuff from the base class
          %{ $self->SUPER::default_options() },
          flag_GeneNames    => '1',
          flag_GeneDescr    => '1',
          ## GeneName Projection 
          gn_config => { 
                        '1'=>{
                              'source'          => 'arabidopsis_thaliana',
                              'division'        => [],
 			      'run_all'         =>  0, # 1/0
                              # Taxon name of species to project to
                              'taxons'      => ['eudicotyledons'],
                              # source species GeneName filter for GeneDescription
                              'geneName_source'                => ['UniProtKB/Swiss-Prot', 'Uniprot_gn', 'TAIR_SYMBOL'],
                              # homology types filter
 				  'method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
			      'homology_types_allowed' => ['ortholog_one2one'],
                              # homology percentage identity filter 
                              'percent_id_filter'      => '30', 
                              'percent_cov_filter'     => '66',
                             }, 
                        '2'=>{
                              'source'          => 'oryza_sativa',
                              'division'        => [],
 			      'run_all'         =>  0, # 1/0
                              # Taxon name of species to project to
                              'taxons'      => ['Liliopsida'],
                              # source species GeneName filter for GeneDescription
                              'geneName_source'                => ['UniProtKB/Swiss-Prot', 'Uniprot_gn', 'TAIR_SYMBOL'],
                              # homology types filter
 				  'method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
			      'homology_types_allowed' => ['ortholog_one2one'],
                              # homology percentage identity filter 
                              'percent_id_filter'      => '30', 
                              'percent_cov_filter'     => '66',
                             }
                       },
          parallel_GeneDescription_projections => '0',
          ## GeneDescription Projection 
          gd_config => { 
                        '1'=>{
                              'source'          => 'arabidopsis_thaliana',
                              'division'        => [],
                              'antispecies'     => ['arabidopsis_thaliana'],
 			      'run_all'         =>  0, # 1/0
                              # Taxon name of species to project to
                              'taxons'      => ['eudicotyledons'],
                              # source species GeneDescription filter
                              'geneDesc_rules'   	  => ['hypothetical', 'putative', 'unknown protein'],
                              'geneName_source'                => ['UniProtKB/Swiss-Prot', 'Uniprot_gn', 'TAIR_SYMBOL'],
                              # target species GeneDescription filter
                              'geneDesc_rules_target'  => ['Uncharacterized protein', 'Predicted protein', 'Gene of unknown', 'hypothetical protein'] ,
                              # homology types filter
 				  'method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
			      'homology_types_allowed' => ['ortholog_one2one'],
                              # homology percentage identity filter 
                              'percent_id_filter'      => '30',
                              'percent_cov_filter'     => '66',
                             },
                        '2'=>{
                              'source'          => 'oryza_sativa',
                              'species'         => [], 
                              'division'        => [],
                              'antispecies'     => ['oryza_sativa'],
 			      'run_all'         =>  0, # 1/0
                              # Taxon name of species to project to
                              'taxons'      => ['Liliopsida'],
                              # source species GeneDescription filter
                              'geneDesc_rules'   	  => ['hypothetical', 'putative', 'unknown protein'],
                              'geneName_source'                => ['UniProtKB/Swiss-Prot', 'Uniprot_gn', 'TAIR_SYMBOL'],
                              # target species GeneDescription filter
                              'geneDesc_rules_target'  => ['Uncharacterized protein', 'Predicted protein', 'Gene of unknown', 'hypothetical protein'] ,
                              # homology types filter
 				  'method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
			      'homology_types_allowed' => ['ortholog_one2one'],
                              # homology percentage identity filter
                              'percent_id_filter'      => '30',
                              'percent_cov_filter'     => '66',
                             },
                        '3'=>{
                              'source'          => 'arabidopsis_thaliana',
                              'division'        => [],
                              'antispecies'     => ['oryza_sativa'],
 			      'run_all'         =>  0, # 1/0
                              # Taxon name of species to project to
                              'taxons'      => ['Liliopsida'],
                              # source species GeneDescription filter
                              'geneDesc_rules'   	  => ['hypothetical', 'putative', 'unknown protein'],
                              'geneName_source'                => ['UniProtKB/Swiss-Prot', 'Uniprot_gn', 'TAIR_SYMBOL'],
                              # target species GeneDescription filter
                              'geneDesc_rules_target'  => ['Uncharacterized protein', 'Predicted protein', 'Gene of unknown', 'hypothetical protein'] ,
                              # homology types filter
 				  'method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
			      'homology_types_allowed' => ['ortholog_one2one'],
                              # homology percentage identity filter 
                              'percent_id_filter'      => '30',
                              'percent_cov_filter'     => '66',
                             },
                        '4'=>{
                              'source'          => 'oryza_sativa',
                              'species'         => [], 
                              'antispecies' => ['arabidopsis_thaliana'],
                              'division'        => [],
 			      'run_all'         =>  0, # 1/0
                              # Taxon name of species to project to
                              'taxons'      => ['eudicotyledons'],
                              # source species GeneDescription filter
                              'geneDesc_rules'   	  => ['hypothetical', 'putative', 'unknown protein'],
                              'geneName_source'                => ['UniProtKB/Swiss-Prot', 'Uniprot_gn', 'TAIR_SYMBOL'],
                              # target species GeneDescription filter
                              'geneDesc_rules_target'  => ['Uncharacterized protein', 'Predicted protein', 'Gene of unknown', 'hypothetical protein'] ,
                              # homology types filter
 				  'method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
			      'homology_types_allowed' => ['ortholog_one2one'],
                              # homology percentage identity filter
                              'percent_id_filter'      => '30',
                              'percent_cov_filter'     => '66',
                             }
                       }
         };
}
1;
