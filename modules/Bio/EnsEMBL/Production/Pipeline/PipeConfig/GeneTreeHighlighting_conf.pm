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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneTreeHighlighting_conf;

=head1 DESCRIPTION

Populate compara table with GO and InterPro terms,
to enable highlighting in the genome browser.

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneTreeHighlighting_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        species                 => [],
        division                => [],
        run_all                 => 0,
        antispecies             => [],
        meta_filters            => {},
        history_file            => undef,
        output_dir              => undef,
        config_file             => undef,
        ## Allow division of compara database to be explicitly specified
        compara_division        => undef,
        ensembl_cvs_root_dir    => $ENV{'BASE_DIR'},
        external_db_sql         => "insert ignore into external_db " .
            "(external_db_id, db_name, status, priority, db_display_name, type) " .
            "values (1000, 'GO', 'XREF', 5, 'GO', 'MISC'), " .
            "(1200, 'Interpro', 'XREF', 5, 'InterPro', 'MISC');",

        delete_members_xref_sql => "delete mx.* from member_xref mx where mx.external_db_id in (1000, 1200);",
        highlighting_capacity   => 20,
    }
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
        {
            -logic_name => 'populate_external_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -input_ids  => [ {} ],
            -parameters => {
                cmd             => '#compara_host# #compara_db# -e "#external_db_sql#"',
                compara_db      => $self->o('compara_db'),
                compara_host    => $self->o('compara_host'),
                external_db_sql => $self->o('external_db_sql')
            },
            -flow_into  => [ 'delete_member_xref' ],
        },
        {
            -logic_name => 'delete_member_xref',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                cmd                     => '#compara_host# #compara_db# -e "#delete_members_xref_sql#"',
                compara_db              => $self->o('compara_db'),
                compara_host            => $self->o('compara_host'),
                delete_members_xref_sql => $self->o('delete_members_xref_sql')
            },
            # -flow_into  => [ 'job_factory' ],
            -flow_into  => {
                '1->A' => [ 'job_factory' ],
                # 'A->1' => [ 'check_duplicates_member_xref' ]
                'A->1' => [ 'run_dc' ]
            }
        },
        {
            -logic_name => 'job_factory',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            -parameters => {
                species      => $self->o('species'),
                antispecies  => $self->o('antispecies'),
                division     => $self->o('division'),
                run_all      => $self->o('run_all'),
                meta_filters => $self->o('meta_filters'),
            },
            -flow_into  => {
                '2->A' => [ 'highlight_go' ],
                'A->2' => [ 'highlight_interpro' ],
            }
        },
        {
            -logic_name    => 'highlight_go',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::GeneTreeHighlight::HighlightGO',
            -hive_capacity => $self->o('highlighting_capacity'),
            -parameters    => {
                compara_division => $self->o('compara_division'),
            },
        },
        {
            -logic_name    => 'highlight_interpro',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::GeneTreeHighlight::HighlightInterPro',
            -hive_capacity => $self->o('highlighting_capacity'),
            -parameters    => {
                compara_division => $self->o('compara_division'),
            }
        },
        {
            -logic_name        => 'run_dc',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
            -analysis_capacity => 1,
            -max_retry_count   => 0,
            -parameters        => {
                datacheck_groups => [ 'compara_annot_highlight' ],
                registry_file    => $self->o('registry'),
                history_file     => $self->o('history_file'),
                dbname           => $self->o('compara_db'),
                failures_fatal   => 1,
            }
        }
    ];
}

1;
