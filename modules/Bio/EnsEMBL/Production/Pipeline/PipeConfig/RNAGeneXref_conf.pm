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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::RNAGeneXref_conf;

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

    species      => [],
    antispecies  => [],
    division     => [],
    run_all      => 0,
    meta_filters => {},

    rnacentral_ebi_path => '/nfs/ftp/public/databases/RNAcentral/current_release/md5',
    rnacentral_ftp_uri  => 'ftp://ftp.ebi.ac.uk/pub/databases/RNAcentral/current_release/md5',
    rnacentral_file     => 'md5.tsv.gz',

    rnacentral_file_local => catdir($self->o('pipeline_dir'), $self->o('rnacentral_file')),

    rnacentral_logic_name => 'rnacentral_checksum',

    analyses =>
    [
      {
        logic_name => $self->o('rnacentral_logic_name'),
        db         => 'RNACentral',
        local_file => $self->o('rnacentral_file_local'),
      },
    ],

    # Remove existing analyses; if =0 then existing analyses
    # will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,

    # Config/history files for storing record of datacheck run.
    config_file  => undef,
    history_file => undef,
  };
}

# Ensures that species output parameter gets propagated implicitly.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  my $rnacentral_table_sql = q/
    CREATE TABLE rnacentral (
      urs VARCHAR(13) NOT NULL,
      md5sum VARCHAR(32) NOT NULL COLLATE latin1_swedish_ci
    );
  /;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('pipeline_dir'),
    $self->db_cmd($rnacentral_table_sql),
  ];
}

sub pipeline_analyses {
  my $self = shift @_;

  return [
    {
      -logic_name      => 'RNAGeneXref',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -input_ids       => [ {} ],
      -parameters      => {},
      -flow_into       => {
                            '1->A' => ['FetchRNACentral'],
                            'A->1' => ['DbFactory'],
                          }
    },

    {
      -logic_name      => 'FetchRNACentral',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::FetchFile',
      -max_retry_count => 1,
      -parameters      => {
                            ebi_path    => $self->o('rnacentral_ebi_path'),
                            ftp_uri     => $self->o('rnacentral_ftp_uri'),
                            remote_file => $self->o('rnacentral_file'),
                            local_file  => $self->o('rnacentral_file_local'),
                          },
      -flow_into       => ['LoadRNACentral'],
      -rc_name         => 'dm',
    },

    {
      -logic_name      => 'LoadRNACentral',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::RNAGeneXref::LoadRNACentral',
      -max_retry_count => 1,
      -parameters      => {
                            rnacentral_file_local => $self->o('rnacentral_file_local'),
                          },
    },

    {
      -logic_name      => 'DbFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -max_retry_count => 1,
      -parameters      => {
                            species         => $self->o('species'),
                            antispecies     => $self->o('antispecies'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            meta_filters    => $self->o('meta_filters'),
                          },
      -flow_into       => {
                            '2' => ['AnalysisConfiguration'],
                          }
    },

    {
      -logic_name        => 'AnalysisConfiguration',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::RNAGeneXref::AnalysisConfiguration',
      -max_retry_count   => 0,
      -parameters        => {
                              analyses => $self->o('analyses'),
                            },
      -flow_into 	       => {
                              '2->A' => ['BackupTables'],
                              'A->3' => ['SpeciesFactory'],
                            }
    },

    {
      -logic_name        => 'BackupTables',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DatabaseDumper',
      -max_retry_count   => 1,
      -analysis_capacity => 20,
      -parameters        => {
                              table_list  => [
                                'analysis',
                                'analysis_description',
                                'object_xref',
                                'xref',
                              ],
                              output_file => catdir($self->o('pipeline_dir'), '#dbname#', 'pre_pipeline_bkp.sql.gz'),
                              overwrite   => 1,
                            },
      -flow_into         => ['AnalysisSetup'],
    },

    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::AnalysisSetup',
      -max_retry_count   => 0,
      -analysis_capacity => 20,
      -parameters        => {
                              db_backup_required => 1,
                              db_backup_file     => catdir($self->o('pipeline_dir'), '#dbname#', 'pre_pipeline_bkp.sql.gz'),
                              delete_existing    => $self->o('delete_existing'),
                              linked_tables      => ['object_xref'],
                              production_lookup  => 1,
                            },
    },

    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbAwareSpeciesFactory',
      -max_retry_count   => 1,
      -analysis_capacity => 20,
      -parameters        => {},
      -flow_into         => {
                              '2' => ['RNACentralXref'],
                            }
    },

    {
      -logic_name        => 'RNACentralXref',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::RNAGeneXref::RNACentralXref',
      -max_retry_count   => 0,
      -analysis_capacity => 50,
      -parameters        => {
                              logic_name => $self->o('rnacentral_logic_name'),
                            },
      -flow_into         => ['RunDatachecks'],
    },

    {
      -logic_name        => 'RunDatachecks',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -parameters        => {
                              datacheck_names  => ['ForeignKeys'],
                              config_file      => $self->o('config_file'),
                              history_file     => $self->o('history_file'),
                              failures_fatal   => 1,
                            },
    },

  ];
}

1;
