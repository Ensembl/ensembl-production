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

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::FileDumpMySQL_conf;

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

    # Database type factory
    group => [],

    # Database factory
    species      => [],
    antispecies  => [],
    division     => [],
    dbname       => [],
    run_all      => 0,
    meta_filters => {},

    # Include mart databases
    marts => 0,

    # Include non-species-related databases, e.g. ensembl_ontology, ncbi_taxonomy
    pan_ensembl => 0,
    pan_ensembl_dir => 'pan_ensembl',
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

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    'dump_dir'   => $self->o('dump_dir'),
    'server_url' => $self->o('server_url'),
  };
}

sub pipeline_analyses {
  my $self = shift @_;

  return [
    {
      -logic_name        => 'DumpMySQL',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 1,
      -input_ids         => [ {} ],
      -flow_into         => ['GroupFactory', 'MultiDbFactory'],
    },
    {
      -logic_name        => 'GroupFactory',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              inputlist    => $self->o('group'),
                              column_names => ['group'],
                            },
      -flow_into         => {
                              '2' => ['DbFactory'],
                            },
    },
    {
      -logic_name        => 'DbFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              species      => $self->o('species'),
                              antispecies  => $self->o('antispecies'),
                              division     => $self->o('division'),
                              dbname       => $self->o('dbname'),
                              run_all      => $self->o('run_all'),
                              meta_filters => $self->o('meta_filters'),
                            },
      -flow_into         => {
                              '2' => ['GetDivision'],
                            },
    },
    {
      -logic_name        => 'GetDivision',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::GetDivision',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {},
      -flow_into         => ['MySQL_TXT'],
    },
    {
      -logic_name        => 'MultiDbFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::MultiDbFactory',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              ensembl_release => $self->o('ensembl_release'),
                              division        => $self->o('division'),
                              marts           => $self->o('marts'),
                              pan_ensembl     => $self->o('pan_ensembl'),
                              pan_ensembl_dir => $self->o('pan_ensembl_dir'),
                            },
      -flow_into         => {
                              '2' => ['MySQL_Multi_TXT'],
                            },
    },
    {
      -logic_name        => 'MySQL_TXT',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::MySQL_TXT',
      -max_retry_count   => 1,
      -hive_capacity     => 10,
      -parameters        => {
                              output_dir => catdir('#dump_dir#', '#division#', 'mysql', '#dbname#'),
                            },
      -rc_name           => '2GB',
      -flow_into         => {
                              '2->A' => ['MySQL_Compress'],
                              'A->3' => ['Checksum']
                            },
    },
    {
      -logic_name        => 'MySQL_Multi_TXT',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::MySQL_TXT',
      -max_retry_count   => 1,
      -hive_capacity     => 10,
      -parameters        => {
                              db_url     => '#server_url##dbname#',
                              output_dir => catdir('#dump_dir#', '#division#', 'mysql', '#dbname#'),
                            },
      -rc_name           => '2GB',
      -flow_into         => {
                              '2->A' => ['MySQL_Compress'],
                              'A->3' => ['Checksum']
                            },
    },
    {
      -logic_name        => 'MySQL_Compress',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -batch_size        => 10,
      -parameters        => {
                              cmd => 'gzip -n -f "#output_filename#"',
                            },
      -rc_name           => '1GB',
    },
    {
      -logic_name        => 'Checksum',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -parameters        => {
                              cmd => 'cd "#output_dir#"; find -L . -type f ! -name "md5sum.txt" | sed \'s!^\./!!\' | xargs md5sum > md5sum.txt',
                            },
      -rc_name           => '1GB',
      -flow_into         => ['Verify'],
    },
    {
      -logic_name        => 'Verify',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Verify',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -batch_size        => 10,
    },
  ];
}

1;
