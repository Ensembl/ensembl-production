=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::EGPipeline::PipeConfig::InterPro2GO_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'interpro2go_'.$self->o('ensembl_release'),
    
    species       => [],
    antispecies   => [],
    division      => [],
    run_all       => 0,
    meta_filters => {},
    
    interpro2go_file => '/nfs/panda/ensembl/production/ensprod/interpro2go/interpro2go',
  };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  my $options = join(' ',
    $self->SUPER::beekeeper_extra_cmdline_options,
    "-reg_conf ".$self->o('registry'),
  );
  
  return $options;
}

# Ensures that species output parameter gets propagated implicitly.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

sub pipeline_analyses {
  my $self = shift @_;
  
  return [
    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -max_retry_count   => 1,
      -input_ids         => [ {} ],
      -parameters        => {
                              species         => $self->o('species'),
                              antispecies     => $self->o('antispecies'),
                              division        => $self->o('division'),
                              run_all         => $self->o('run_all'),
                              meta_filters    => $self->o('meta_filters'),
                              chromosome_flow => 0,
                              regulation_flow => 0,
                              variation_flow  => 0,
                            },
      -flow_into         => {
                              '2' => ['AnalysisSetup'],
                            },
      -meadow_type       => 'LOCAL',
    },
    
    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -parameters        => {
                              logic_name         => 'interpro2go',
                              db                 => 'InterPro2GO',
                              db_backup_required => 0,
                              delete_existing    => 1,
                              linked_tables      => ['object_xref'],
                              production_lookup  => 1,
                              production_db      => $self->o('production_db'),
                            },
      -flow_into         => ['RemoveOrphans'],
      -meadow_type       => 'LOCAL',
    },
    
    {
      -logic_name        => 'RemoveOrphans',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -max_retry_count   => 0,
      -parameters        => {
                              sql => [
                                'DELETE dx.* FROM '.
                                  'dependent_xref dx LEFT OUTER JOIN '.
                                  'object_xref ox USING (object_xref_id) '.
                                  'WHERE ox.object_xref_id IS NULL',
                                'DELETE onx.* FROM '.
                                  'ontology_xref onx LEFT OUTER JOIN '.
                                  'object_xref ox USING (object_xref_id) '.
                                  'WHERE ox.object_xref_id IS NULL',
                              ]
                            },
      -flow_into         => ['StoreGoXrefs'],
      -meadow_type       => 'LOCAL',
    },
    
    {
      -logic_name        => 'StoreGoXrefs',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::StoreGoXrefs',
      -hive_capacity     => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              interpro2go_file => $self->o('interpro2go_file'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['EmailReport'],
    },
    
    {
      -logic_name        => 'EmailReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::EmailReport',
      -hive_capacity     => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              email   => $self->o('email'),
                              subject => 'Protein features pipeline: report for #species#',
                            },
      -rc_name           => 'normal',
    },
    
  ];
}

1;
