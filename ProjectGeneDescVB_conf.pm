=head1 LICENSE

Copyright [1999-2015] EMBL-European Bioinformatics Institute
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

Bio::EnsEMBL::EGPipeline::PipeConfig::ProjectGeneDescVB_conf

=head1 DESCRIPTION

Project gene descriptions from well-annotated VectorBase species.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::ProjectGeneDescVB_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::ProjectGeneDesc_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    
    output_dir => catdir('/nfs/panda/ensemblgenomes/vectorbase/desc_projection', $self->o('pipeline_name')),

    config => 
    {
      'aedes_aegypti' =>
      {
        source  => 'aedes_aegypti',
        species => [
                    'aedes_albopictus',
                   ],
      },
      
      'anopheles_gambiae' =>
      {
        source  => 'anopheles_gambiae',
        species => [
                    'anopheles_albimanus',
                    'anopheles_arabiensis',
                    'anopheles_atroparvus',
                    'anopheles_christyi',
                    'anopheles_coluzzii',
                    'anopheles_culicifacies',
                    'anopheles_darlingi',
                    'anopheles_dirus',
                    'anopheles_epiroticus',
                    'anopheles_farauti',
                    'anopheles_funestus',
                    'anopheles_maculatus',
                    'anopheles_melas',
                    'anopheles_merus',
                    'anopheles_minimus',
                    'anopheles_quadriannulatus',
                    'anopheles_sinensis',
                    'anopheles_stephensi',
                   ],
      },
      
      'drosophila_melanogaster' =>
      {
        source  => 'drosophila_melanogaster',
        species => [
                    'glossina_austeni',
                    'glossina_brevipalpis',
                    'glossina_fuscipes',
                    'glossina_morsitans',
                    'glossina_pallidipes',
                    'glossina_palpalis',
                    'musca_domestica',
                    'stomoxys_calcitrans',
                   ],
      },
      
      'glossina_morsitans' =>
      {
        source  => 'glossina_morsitans',
        species => [
                    'glossina_austeni',
                    'glossina_brevipalpis',
                    'glossina_fuscipes',
                    'glossina_pallidipes',
                    'glossina_palpalis',
                    'musca_domestica',
                    'stomoxys_calcitrans',
                   ],
      },
      
    },
    
    # Do closest species in first pass, remoter species in second pass.
    # Only values of 2 or 3 will work, i.e. there's only one level of blocking.
    flow => 
    {
      'aedes_aegypti'           => 2,
      'anopheles_gambiae'       => 2,
      'glossina_morsitans'      => 2,
      'drosophila_melanogaster' => 3,
    },
    
  };
}

1;
