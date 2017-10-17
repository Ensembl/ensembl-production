
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::FactoryTest_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'factory_test',
    
    species      => [],
    antispecies  => [],
    taxons       => [],
    antitaxons   => [],
    division     => [],
    run_all      => 0,
    meta_filters => {},
    
    db_type => 'core',
    
    check_intentions => 0,
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
      -logic_name        => 'DbFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -max_retry_count   => 0,
      -input_ids         => [ {} ],
      -parameters        => {
                              species      => $self->o('species'),
                              antispecies  => $self->o('antispecies'),
                              taxons       => $self->o('taxons'),
                              antitaxons   => $self->o('antitaxons'),
                              division     => $self->o('division'),
                              run_all      => $self->o('run_all'),
                              meta_filters => $self->o('meta_filters'),
                              db_type      => $self->o('db_type'),
                            },
      -flow_into         => {
                              '2->A' => ['DbFlow'],
                              'A->2' => ['SpeciesFactory'],
                              '5'    => ['ComparaFlow'],
                            },
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'DbFlow',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity => 10,
      -batch_size        => 100,
      -max_retry_count   => 0,
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -analysis_capacity => 10,
      -batch_size        => 100,
      -max_retry_count   => 0,
      -parameters        => {
                              check_intentions => $self->o('check_intentions'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['CoreFlow'],
                              '3->A' => ['ChromosomeFlow'],
                              '4->A' => ['VariationFlow'],
                              '5->A' => ['ComparaFlow'],
                              '6->A' => ['RegulationFlow'],
                              '7->A' => ['OtherfeaturesFlow'],
                              'A->1' => ['SingleFlow'],
                            },
    },
    
    {
      -logic_name        => 'CoreFlow',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity => 10,
      -batch_size        => 100,
      -max_retry_count   => 0,
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'SingleFlow',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity => 10,
      -batch_size        => 100,
      -max_retry_count   => 0,
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'ChromosomeFlow',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity => 10,
      -batch_size        => 100,
      -max_retry_count   => 0,
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'VariationFlow',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity => 10,
      -batch_size        => 100,
      -max_retry_count   => 0,
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'ComparaFlow',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity => 10,
      -batch_size        => 100,
      -max_retry_count   => 0,
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'RegulationFlow',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity => 10,
      -batch_size        => 100,
      -max_retry_count   => 0,
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'OtherfeaturesFlow',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity => 10,
      -batch_size        => 100,
      -max_retry_count   => 0,
      -rc_name           => 'normal',
    },
    
  ];
}

1;
