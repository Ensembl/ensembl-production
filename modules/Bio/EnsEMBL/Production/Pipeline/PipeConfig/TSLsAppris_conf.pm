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

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::TSLsAppris_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub default_options {
  my ($self) = @_;

  return {
    %{ $self->SUPER::default_options() },

    pipeline_name => 'tsl_appris_'.$self->o('ensembl_release'),

    division => [],

    tsl_ftp_base    => 'http://hgwdev.gi.ucsc.edu/~markd/gencode/tsl-handoff/',
    appris_ftp_base => 'http://apprisws.bioinfo.cnio.es/forEnsembl'
  };
}

sub pipeline_analyses {
  my ($self) = @_;
  return [
    {
      -logic_name => 'process_appris_tsl_files',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::PostGenebuild::ProcessApprisTSLFiles',
      -max_retry_count => 1,
      -input_ids  => [ {} ],
      -parameters => {
                       appris_ftp_base => $self->o('appris_ftp_base'),
                       tsl_ftp_base    => $self->o('tsl_ftp_base'),
                       working_dir     => $self->o('working_dir'),
                       mdbname         => $self->o('mdbname'),
                       mhost           => $self->o('mhost'),
                       mport           => $self->o('mport'),
                       muser           => $self->o('muser'),
                       division        => $self->o('division'),
                       release         => $self->o('ensembl_release')
                     },
      -flow_into  => {
                       '2->A' => WHEN(
                         '#analysis# eq "appris"' => [ 'load_appris' ],
                         '#analysis# eq "tsl"' => [ 'load_tsl' ]
                       ),
                       'A->1'  => [ 'APPRIS_TSL_Datachecks'],
                     },
    },
    {
      -logic_name => 'load_appris',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::PostGenebuild::LoadAppris',
      -max_retry_count => 1
    },
    {
      -logic_name => 'load_tsl',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::PostGenebuild::LoadTsl',
      -max_retry_count => 1
    },
    {  -logic_name => 'APPRIS_TSL_Datachecks',
       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -flow_into  => {
                        '1->A' => ['APPRIS_TSL_Critical_Datachecks'],
                        'A->1' => ['APPRIS_TSL_Advisory_Datachecks'],
                      },
    },
    {
      -logic_name      => 'APPRIS_TSL_Critical_Datachecks',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters      => {
                            datacheck_names => ['AttribValuesExist'],
                            history_file    => $self->o('history_file'),
                            failures_fatal  => 1,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
    },
    {
      -logic_name      => 'APPRIS_TSL_Advisory_Datachecks',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters      => {
                            datacheck_names => ['AttribValuesCoverage'],
                            history_file    => $self->o('history_file'),
                            failures_fatal  => 0,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
      -flow_into       => {
                            '4' => 'report_failed_APPRIS_TSL_Advisory_Datachecks'
                          },
    },
    {
      -logic_name        => 'report_failed_APPRIS_TSL_Advisory_Datachecks',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailNotify',
      -parameters        => {'email' => $self->o('email')},
      -max_retry_count   => 1,
      -analysis_capacity => 10,
   },
  ];
}

1;
