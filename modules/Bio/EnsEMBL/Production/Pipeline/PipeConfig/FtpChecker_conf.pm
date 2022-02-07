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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::FtpChecker_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    species      => [],
    antispecies  => [],
    division     => [],
    run_all      => 0,
    meta_filters => {},

    failures_file  => catdir($self->o('pipeline_dir'), 'failures.txt'),
 };
}

sub pipeline_create_commands {
  my ($self) = @_;

  my $failures_table_sql = q/
    CREATE TABLE failures (
      species VARCHAR(128),
      division VARCHAR(16),
      type VARCHAR(16),
      format VARCHAR(16),
      file_path TEXT
    );
  /;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('pipeline_dir'),
    $self->db_cmd($failures_table_sql),
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    base_path    => $self->o('base_path'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -max_retry_count => 1,
      -input_ids       => [ {} ],
      -parameters      => {
                            species      => $self->o('species'),
                            antispecies  => $self->o('antispecies'),
                            division     => $self->o('division'),
                            run_all      => $self->o('run_all'),
                            meta_filters => $self->o('meta_filters'),
                          },
      -flow_into       => { 
                            '2->A' => ['CheckCoreFtp'],
                            '4->A' => ['CheckVariationFtp'],
                            '5->A' => ['CheckComparaFtp'],
                            'A->1' => ['ReportFailures'],
                          },
    }, 
    {
      -logic_name    => 'CheckCoreFtp',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckCoreFtp',
      -hive_capacity => 100,
      -flow_into     => {
                          2 => ['?table_name=failures']
                        }, 
    },
    {
      -logic_name    => 'CheckVariationFtp',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckVariationFtp',
      -hive_capacity => 100,
      -flow_into     => {
                          2 => ['?table_name=failures']
                        },
    },
    {
      -logic_name    => 'CheckComparaFtp',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckComparaFtp',
      -hive_capacity => 100,
      -flow_into     => {
                          2 => ['?table_name=failures']
                        },
    },
    {
      -logic_name    => 'ReportFailures',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::FtpChecker::ReportFailures',
      -parameters    => {
                          email         => $self->o('email'),
                          pipeline_name => $self->o('pipeline_name'),
                          failures_file => $self->o('failures_file'),
                        },
    },
  ];
}

1;
