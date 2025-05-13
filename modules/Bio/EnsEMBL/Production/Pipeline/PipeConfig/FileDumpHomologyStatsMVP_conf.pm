=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2025] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::FileDumpHomologyStatsMVP_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use File::Spec::Functions qw(catdir);

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        species                            => [],
        antispecies                        => [],
        division                           => [],
        run_all                            => 0,
        dbname                             => [],
        meta_filters                       => {},

        dump_dir                           => undef,
        ftp_root                           => undef,
        genome_types                       => [ 'Assembly_Chain', 'Chromosome_TSV', 'Genome_FASTA' ],
        geneset_types                      => [ 'Geneset_EMBL' ,  'Geneset_FASTA', 'Geneset_GFF3', 'Geneset_GTF', 'Xref_TSV' ],
        homology_types                     => [ 'Homologies_TSV' ], # Possible values :

        overwrite                          => 0,
        per_chromosome                     => 0,

        # Pre-dump datachecks
        run_datachecks                     => 1,
        config_file                        => undef,
        history_file                       => undef,
        output_dir                         => undef,
        datacheck_names                    => [],
        datacheck_groups                   => [ 'rapid_release' ],
        datacheck_types                    => [],

        # External programs
        blastdb_exe                        => 'makeblastdb',
        gtf_to_genepred_exe                => 'gtfToGenePred',
        genepred_check_exe                 => 'genePredCheck',
        gt_gff3_exe                        => 'gt gff3',
        gt_gff3validator_exe               => 'gt gff3validator',

        # Parameters specific to particular dump_types
        blast_index                        => 0,
        chain_ucsc                         => 1,
        xref_external_dbs                  => [],
        dump_homologies_script             => $self->o('ENV', 'ENSEMBL_ROOT_DIR') . "/ensembl-compara/scripts/dumps/dump_homologies.py",
        ref_dbname                         => 'ensembl_compara_references_mvp',
        ens_version                        => $self->o('ENV', 'ENS_VERSION'),
        compara_host_uri                   => '',
        species_dirname                    => 'organisms',

        #genome factory params
        dataset_status                     => 'Submitted',  #fetch genomes with dataset status submitted
        dataset_type                       => 'ftp_dumps',  #fetch genomes with dataset blast
        update_dataset_status              => 'Processing', #updates dataset status to processing in new metadata db
        genome_factory_dynamic_output_flow => {
            '3->A'         => { 'FileDump' => INPUT_PLUS() },
            'A->3'         => [ { 'UpdateDatasetStatus' => INPUT_PLUS() } ],
            # attribute_dict => {}, # Placeholder for attribute dictionary
        },

    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},
        'mkdir -p ' . $self->o('dump_dir'),
    ];
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},
        hive_use_param_stack => 1,
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},
        dump_dir       => $self->o('dump_dir'),
        ftp_root       => $self->o('ftp_root'),
        overwrite      => $self->o('overwrite'),
        run_datachecks => $self->o('run_datachecks'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
        @{Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf::factory_analyses($self)},
        {
            -logic_name        => 'FileDump',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -max_retry_count   => 1,
            -analysis_capacity => 1,
            -parameters        => {},
            -flow_into         => {
                '1' => [ 'DbFactory' ],
            }
        },
        {
            -logic_name        => 'DbFactory',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
            -max_retry_count   => 1,
            -analysis_capacity => 1,
            -parameters        => {
                species      => $self->o('species'),
                antispecies  => $self->o('antispecies'),
                division     => $self->o('division'),
                run_all      => $self->o('run_all'),
                dbname       => $self->o('dbname'),
                meta_filters => $self->o('meta_filters'),
            },
            -flow_into         => {
                '2' =>  [ 'SpeciesFactory' ]
            },
        },
        {
            -logic_name        => 'SpeciesFactory',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbAwareSpeciesFactory',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {},
            -flow_into         => {
                '2' => [
                    'HomologyDirectoryPaths',
                ],
            },
        },
        {
            -logic_name        => 'HomologyDirectoryPaths',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::DirectoryPaths',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                analysis_types  => $self->o('homology_types'),
                data_category   => 'homology',
                species_dirname => $self->o('species_dirname')
            },
            -flow_into         => {
                '3->A' => 'Homologies_TSV',
                'A->3' => [ 'Checksum' ]
            }
        },
        {
            -logic_name        => 'Homologies_TSV',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DumpSpeciesDBToTsv',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                ref_dbname             => $self->o('ref_dbname'),
                dump_homologies_script => $self->o('dump_homologies_script'),
                per_species_db         => $self->o("compara_host_uri") . '#species#' . '_compara_' . $self->o('ens_version'),
            },
            -flow_into         => {
                '2' => [
                    'CompressHomologyTSV',
                ],
            }
        },
        {
            -logic_name        => 'CompressHomologyTSV',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::Gzip',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {
                compress => "#filepath#"
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
            -flow_into         => [ 'Verify' ],
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
