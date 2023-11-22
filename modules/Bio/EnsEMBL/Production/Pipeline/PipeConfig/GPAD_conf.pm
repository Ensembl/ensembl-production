=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GPAD_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::Version 2.5;
use File::Spec::Functions qw(catdir);

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options()},

        gpad_directory     => '/nfs/ftp/public/contrib/goa/ensembl_projections',
        gpad_dirname       => undef,

        species            => [],
        antispecies        => [ qw/mus_musculus_129s1svimj mus_musculus_aj mus_musculus_akrj mus_musculus_balbcj mus_musculus_c3hhej mus_musculus_c57bl6nj mus_musculus_casteij mus_musculus_cbaj mus_musculus_dba2j mus_musculus_fvbnj mus_musculus_lpj mus_musculus_nodshiltj mus_musculus_nzohlltj mus_musculus_pwkphj mus_musculus_wsbeij/ ],
        division           => [],
        run_all            => 0,
        meta_filters       => {},

        # Remove existing GO annotations and associated analysis
        delete_existing    => 1,

        # Analysis information
        logic_name         => 'goa_import',
        db                 => 'GO',
        program            => 'goa_import',
        production_lookup  => 1,
        linked_tables      => [ 'object_xref' ],

        # Datachecks
        history_file       => undef,
        config_file        => undef,
        old_server_uri     => undef,
        advisory_dc_output => $self->o('pipeline_dir') . '/advisory_dc_output',

        #filewatcher
        file_name          => 'annotations_ensembl-{}.gpa',
        directory          => $self->o('gpad_directory') . '/' . $self->o('gpad_dirname'),
        watch_until        => 48,
        wait               => 0,

    };
}

sub pipeline_create_commands {
    my ($self) = @_;

    return [
        @{$self->SUPER::pipeline_create_commands},
        'mkdir -p ' . $self->o('pipeline_dir'),
    ];
}

# Ensures output parameters gets propagated implicitly
sub hive_meta_table {
    my ($self) = @_;

    return {
        %{$self->SUPER::hive_meta_table},
        'hive_use_param_stack' => 1,
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
        {
            -logic_name      => 'FileWatcher',
            -module          => 'ensembl.production.hive.FileWatcher',
            -max_retry_count => 0,
            -language        => 'python3',
            -parameters      => {
                directory   => $self->o('directory'),
                file_name   => $self->o('file_name'),
                species     => $self->o('species'),
                watch_until => $self->o('watch_until'),
                wait        => $self->o('wait'),
            },
            -flow_into       => { 1 => [ 'AdvisoryDCReportInit' ] },
            -input_ids       => [ {} ],
            -rc_name         => 'default'
        },
        {
            -logic_name => 'AdvisoryDCReportInit',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => [ 'DbFactory' ],
                'A->1' => [ 'DataCheckResults' ],
            }
        },
        {
            -logic_name => 'DataCheckResults',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1' => [ 'ConvertTapToJson' ],
            },
        },
        {
            -logic_name        => 'ConvertTapToJson',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::ConvertTapToJson',
            -analysis_capacity => 10,
            -max_retry_count   => 0,
            -parameters        => {
                tap        => $self->o('advisory_dc_output'),
                output_dir => $self->o('advisory_dc_output'),
            },
            -flow_into         => [ 'AdvisoryDataCheckReport' ],
        },
        {
            -logic_name => 'AdvisoryDataCheckReport',
            -module     => 'Bio::EnsEMBL::DataCheck::Pipeline::DataCheckMailSummary',
            -rc_name    => 'default',
            -parameters => {
                pipeline_name => $self->o('pipeline_name'),
                email         => $self->o('email'),
                output_dir    => $self->o('advisory_dc_output'),
            }
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
                chromosome_flow => 0,
                regulation_flow => 0,
                variation_flow  => 0,
            },
            -flow_into       => {
                '2->A' => [ 'BackupTables' ],
                'A->2' => [ 'LoadAndDatacheck' ],
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
                    'dependent_xref',
                    'object_xref',
                    'ontology_xref',
                ],
                output_file => catdir($self->o('pipeline_dir'), '#dbname#', 'pre_pipeline_bkp.sql.gz'),
            },
            -flow_into         => {
                '1->A' => [ 'AnalysisSetup' ],
                'A->1' => [ 'RemoveOrphans' ],
            }
        },
        {
            -logic_name        => 'AnalysisSetup',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::AnalysisSetup',
            -max_retry_count   => 0,
            -analysis_capacity => 20,
            -parameters        => {
                db_backup_required => 0,
                delete_existing    => $self->o('delete_existing'),
                production_lookup  => $self->o('production_lookup'),
                logic_name         => $self->o('logic_name'),
                db                 => $self->o('db'),
                program            => $self->o('program'),
                linked_tables      => $self->o('linked_tables')
            }
        },
        {
            -logic_name        => 'RemoveOrphans',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::SqlCmd',
            -max_retry_count   => 0,
            -analysis_capacity => 20,
            -parameters        => {
                sql => [
                    'DELETE dx.* FROM ' .
                        'dependent_xref dx LEFT OUTER JOIN ' .
                        'object_xref ox USING (object_xref_id) ' .
                        'WHERE ox.object_xref_id IS NULL',
                    'DELETE onx.* FROM ' .
                        'ontology_xref onx LEFT OUTER JOIN ' .
                        'object_xref ox USING (object_xref_id) ' .
                        'WHERE ox.object_xref_id IS NULL',
                ]
            },
        },
        {
            -logic_name => 'LoadAndDatacheck',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => [ 'SpeciesFactory' ],
                'A->1' => [ 'RunXrefDatacheck' ],
            },
        },
        {
            -logic_name      => 'SpeciesFactory',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::DbAwareSpeciesFactory',
            -max_retry_count => 1,
            -parameters      => {
                chromosome_flow    => 0,
                otherfeatures_flow => 0,
                regulation_flow    => 0,
                variation_flow     => 0,
            },
            -flow_into       => {
                '2' => [ 'FindFile' ],
            }
        },
        {
            -logic_name        => 'FindFile',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::GPAD::FindFile',
            -analysis_capacity => 30,
            -parameters        => {
                gpad_directory => $self->o('gpad_directory'),
                gpad_dirname   => $self->o('gpad_dirname'),
            },
            -flow_into         => {
                '2' => [ 'LoadFile' ],
            },
            -rc_name           => 'default',
        },
        {
            -logic_name        => 'LoadFile',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::GPAD::LoadFile',
            -analysis_capacity => 20,
            -parameters        => {
                logic_name => $self->o('logic_name')
            },
            -rc_name           => 'default',
        },
        {
            -logic_name => 'RunXrefDatacheck',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => [ 'RunXrefCriticalDatacheck' ],
                'A->1' => [ 'RunXrefAdvisoryDatacheck' ]
            },
        },
        {
            -logic_name        => 'RunXrefCriticalDatacheck',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -parameters        => {
                datacheck_names  => [ 'ForeignKeys' ],
                datacheck_groups => [ 'xref' ],
                datacheck_types  => [ 'critical' ],
                registry_file    => $self->o('registry'),
                config_file      => $self->o('config_file'),
                history_file     => $self->o('history_file'),
                old_server_uri   => $self->o('old_server_uri'),
                failures_fatal   => 1,
            },
        },
        {
            -logic_name        => 'RunXrefAdvisoryDatacheck',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {
                datacheck_groups => [ 'xref_go_projection' ],
                datacheck_types  => [ 'advisory' ],
                registry_file    => $self->o('registry'),
                config_file      => $self->o('config_file'),
                history_file     => $self->o('history_file'),
                old_server_uri   => $self->o('old_server_uri'),
                output_dir       => $self->o('advisory_dc_output'),
                failures_fatal   => 0,
            },
        },
    ];
}

1;
