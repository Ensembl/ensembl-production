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

Bio::EnsEMBL::EGPipeline::PipeConfig::ProjectGeneDesc_conf

=head1 DESCRIPTION

Project gene descriptions from a well-annotated species.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::ProjectGeneDesc_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    
    pipeline_name => 'gene_description_'.$self->o('ensembl_release'),
    output_dir    => catdir('/nfs/nobackup/ensemblgenomes', $self->o('ENV', 'USER'), $self->o('pipeline_name')),
    backup_tables => ['gene'],
    store_data    => 1,
    email_report  => 1,
    
    # Default parameters: start
    # Any of these parameters can be redefined in the sub-hash(es) of the 'config' hash
    source             => undef,
    species            => [],
    division           => [],
    run_all            => 0,
    antispecies        => [],
    meta_filters       => {},
    compara_name       => undef,
    compara_db_name    => undef,
    method_link        => 'ENSEMBL_ORTHOLOGUES',
    homology_types     => ['ortholog_one2one', 'ortholog_one2many'],
    percent_id_filter  => 30,
    percent_cov_filter => 66,
    ignore_source      => ['hypothetical', 'putative'],
    replace_target     => ['Uncharacterized protein', 'Predicted protein'],
    # Default parameters: end

    config => 
    {
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
                   ],
      },
      
    },
    
    # Do closest species in first pass, remoter species in second pass.
    ordering => 
    {
      'glossina_morsitans'      => 1,
      'drosophila_melanogaster' => 2,
    },
    
  };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  my $options = join(' ',
    $self->SUPER::beekeeper_extra_cmdline_options,
    "-reg_conf ".$self->o('registry')
  );
  
  return $options;
}

# Ensure that output parameters get propagated implicitly.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('output_dir'),
  ];
}

sub pipeline_analyses {
  my ($self) = @_;
  
  my $flow_into = [];
  if ($self->o('email_report')) {
    push @$flow_into, 'EmailReport';
  }
  
  return [
    {
      -logic_name      => 'SourceFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::ProjectGeneDesc::SourceFactory',
      -input_ids       => [ {} ],
      -parameters      => {
                            config     => $self->o('config'),
                            ordering   => $self->o('ordering'),
                            output_dir => $self->o('output_dir'),
                          },
      -flow_into       => {
                            '2->A' => ['TargetFactory'],
                            'A->3' => ['TargetFactory'],
                          },
      -meadow_type     => 'LOCAL',
      -max_retry_count => 1,
    },
    
    {
      -logic_name      => 'TargetFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -flow_into       => {
                            '2->A' => ['BackupTables'],
                            'A->2' => ['GeneDescProjection'],
                           },
      -meadow_type     => 'LOCAL',
      -max_retry_count => 1,
    },
    
    {
      -logic_name      => 'BackupTables',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -parameters      => {
                            table_list  => $self->o('backup_tables'),
                            output_file => catdir('#projection_dir#', '#species#', 'backup.sql.gz'),
                          },
      -rc_name         => 'normal',
      -max_retry_count => 1,
    },
    
    {
      -logic_name      => 'GeneDescProjection',
      -module          => 'Bio::EnsEMBL::EGPipeline::ProjectGeneDesc::GeneDescProjection',
      -parameters      => {
                            log_file           => catdir('#projection_dir#', '#species#', 'log.txt'),
                            store_data         => $self->o('store_data'),
                            source             => $self->o('source'),
                            compara_name       => $self->o('compara_name'),
                            compara_db_name    => $self->o('compara_db_name'),
                            method_link        => $self->o('method_link'),
                            homology_types     => $self->o('homology_types'),
                            percent_id_filter  => $self->o('percent_id_filter'),
                            percent_cov_filter => $self->o('percent_cov_filter'),
                            ignore_source      => $self->o('ignore_source'),
                            replace_target     => $self->o('replace_target'),
                          },
      -rc_name         => 'normal',
      -batch_size      =>  5,
      -hive_capacity   => 20,
      -flow_into       => $flow_into,
      -max_retry_count => 1,
    },

    {
      -logic_name      => 'EmailReport',
      -module          => 'Bio::EnsEMBL::EGPipeline::ProjectGeneDesc::EmailReport',
      -parameters      => {
                            email      => $self->o('email'),
                            subject    => 'Projection of gene descriptions from #source# to #species#',
                            log_file   => catdir('#projection_dir#', '#species#', 'log.txt'),
                            store_data => $self->o('store_data'),
                          },
      -rc_name         => 'normal',
      -max_retry_count => 1,
    },
    

  ];
}

1;
