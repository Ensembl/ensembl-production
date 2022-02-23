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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::TaxonomyInfoCore_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    # Primary function of pipeline is to copy, but can be used to just delete dbs
    username => $self->o('ENV', 'USER'),
    ensembl_release => $self->o('ENV', 'ENS_VERSION'),
    dumppath => $self->o('scratch_large_dir') ."/db_backs_meta_tables/". $self->o('ensembl_release'),
    group => [],
    division => [],
    species => [],
    removedeprecated => 1,
    dropbaks => 1,
    deprecated_keys => ['species.ensembl_common_name', 'species.ensembl_alias_name', 'species.short_name'],
  };
}

# Implicit parameter propagation throughout the pipeline.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('dumppath'),
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    'dumppath' => $self->o('dumppath'),
    'ensembl_release' => $self->o('ensembl_release'),
  };
}

sub pipeline_analyses {
  my $self = shift @_;

  return [
    {
      -logic_name      => 'MetadataDbFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::MetadataDbFactory',
      -input_ids         => [ {} ],
      -max_retry_count => 1,
      -parameters      => {
                            ensembl_release => $self->o('ensembl_release'),
                            group           => $self->o('group'),
			    division        => $self->o('division'),
			    species         => $self->o('species'),
			    dropbaks        => 0, 
                          },
      -flow_into       => {
                            '2' => 'BackUpDataBase',
                          }
    },
    {
      -logic_name        => 'BackUpDataBase',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::TaxonomyUpdate::BackUpDatabase',
      -flow_into         => { '1' => 'ProcessMeataData'} 
    },
    {
      -logic_name        => 'ProcessMeataData',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::TaxonomyUpdate::QueryMetadata',
      -flow_into         => { '1' => 'DropBackupTable'}
    },
    {
      -logic_name        => 'DropBackupTable',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::TaxonomyUpdate::BackUpDatabase',
      -parameters      => {
                             dropbaks  => 1,
                          },
    },

  ];
}

1;
