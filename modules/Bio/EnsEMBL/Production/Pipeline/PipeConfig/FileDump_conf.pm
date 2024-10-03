=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::FileDump_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use File::Spec::Functions qw(catdir);

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        species                => [],
        antispecies            => [],
        division               => [],
        run_all                => 0,
        dbname                 => [],
        meta_filters           => {},

        dump_dir               => undef,
        ftp_root               => undef,
        run_bgz                => 1,
        genome_types           => [], # Possible values: 'Assembly_Chain', 'Chromosome_TSV', 'Genome_FASTA'
        geneset_types          => [], # Possible values: 'Geneset_EMBL', 'Geneset_FASTA', 'Geneset_GFF3', 'Geneset_GFF3_ENA', 'Geneset_GTF', 'Xref_TSV'
        rnaseq_types           => [], # Possible values: 'RNASeq_Exists'
        vep_types              => [], # Here just for the sake of completions. Might remove this from the pipeline when things get complicated.
        homology_types         => [], # Possible values : 'Homologies_TSV'

        dump_metadata          => 0,
        dump_mysql             => 0,
        overwrite              => 0,
        per_chromosome         => 0,

        rnaseq_email           => $self->o('email'),

        # Pre-dump datachecks
        run_datachecks         => 0,
        config_file            => undef,
        history_file           => undef,
        output_dir             => undef,
        datacheck_names        => [],
        datacheck_groups       => [],
        datacheck_types        => [],

        # External programs
        blastdb_exe            => 'makeblastdb',
        gtf_to_genepred_exe    => 'gtfToGenePred',
        genepred_check_exe     => 'genePredCheck',
        gt_gff3_exe            => 'gt gff3',
        gt_gff3validator_exe   => 'gt gff3validator',

        # Parameters specific to particular dump_types
        blast_index            => 0,
        chain_ucsc             => 1,
        dna_per_chromosome     => $self->o('per_chromosome'),
        embl_per_chromosome    => $self->o('per_chromosome'),
        gff3_per_chromosome    => $self->o('per_chromosome'),
        gtf_per_chromosome     => $self->o('per_chromosome'),
        xref_external_dbs      => [],
        dump_homologies_script => $self->o('ENV', 'ENSEMBL_ROOT_DIR') . "/ensembl-compara/scripts/dumps/dump_homologies.py",
        rr_ens_version         => $self->o('ENV', 'RR_ENS_VERSION'),
        ref_dbname             => 'ensembl_compara_references',
        compara_host_uri       => '',
        species_dirname        => 'organisms',

        #genome factory params
      	dataset_status         => 'Submitted', #fetch genomes with dataset status submitted
    	dataset_type           => 'ftp_dumps', #fetch genomes with dataset blast
    	update_dataset_status  => 'Processing', #updates dataset status to processing in new metadata db
        genome_factory_dynamic_output_flow => {
                      '3->A'    => { 'FileDump'  => INPUT_PLUS()  },
                      'A->3'    => [{'UpdateDatasetStatus'=> INPUT_PLUS()}],
        attribute_dict       => {},  # Placeholder for attribute dictionary
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
        dump_metadata  => $self->o('dump_metadata'),
        dump_mysql     => $self->o('dump_mysql'),
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
#            -input_ids         => [ {} ],
            -parameters        => {},
            -flow_into         => {
                '1' => WHEN('#dump_metadata#' =>
                    [ 'MetadataDump' ],
                    ELSE
                        [ 'DbFactory' ]
                )
            }
        },
        {
            -logic_name        => 'MetadataDump',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -max_retry_count   => 1,
            -analysis_capacity => 1,
            -parameters        => {},
            -flow_into         => {
                '1->A' => [ 'DbFactory' ],
                'A->1' => [ 'Metadata_JSON' ],
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
                '2' => WHEN(
                    '#run_datachecks#'                  => [ 'FTPDumpDummy' ],
                    '#dump_mysql# && !#run_datachecks#' => [ 'MySQL_TXT', 'SpeciesFactory' ],
                    ELSE
                        [ 'SpeciesFactory' ]
                )
            },
        },
        {
            -logic_name        => 'FTPDumpDummy',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -max_retry_count   => 1,
            -analysis_capacity => 1,
            -parameters        => {},
            -flow_into         => {
                '1->A' => [ 'RunDataChecks' ],
                'A->1' => [ 'SpeciesFactory' ],
            }
        },
        {
            -logic_name        => 'RunDataChecks',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -parameters        => {
                registry_file    => $self->o('registry'),
                history_file     => $self->o('history_file'),
                output_dir       => $self->o('output_dir'),
                config_file      => $self->o('config_file'),
                datacheck_names  => $self->o('datacheck_names'),
                datacheck_groups => $self->o('datacheck_groups'),
                datacheck_types  => $self->o('datacheck_types'),
                failures_fatal   => 1,
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
                    'GenomeDirectoryPaths',
                    'GenesetDirectoryPaths',
                    'RNASeqDirectoryPaths',
                    'HomologyDirectoryPaths',
                    'VEPDirectoryPaths'
                ],
            }
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
                '3->A' => $self->o('homology_types'),
                'A->3' => [ 'Checksum' ]
            }
        },
        {
            -logic_name        => 'GenomeDirectoryPaths',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::DirectoryPaths',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                data_category   => 'genome',
                analysis_types  => $self->o('genome_types'),
                species_dirname => $self->o('species_dirname')
            },
            -flow_into         => {
                '3->A' => $self->o('genome_types'),
                'A->3' => [ 'Checksum' ]
            },
        },
        {
            -logic_name        => 'GenesetDirectoryPaths',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::DirectoryPaths',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                data_category   => 'geneset',
                analysis_types  => $self->o('geneset_types'),
                species_dirname => $self->o('species_dirname')
            },
            -flow_into         => {
                '3->A' => $self->o('geneset_types'),
                'A->3' => [ 'Checksum' ]
            },
        },
        {
            -logic_name        => 'RNASeqDirectoryPaths',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::DirectoryPaths',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                data_category   => 'rnaseq',
                analysis_types  => $self->o('rnaseq_types'),
                species_dirname => $self->o('species_dirname')
            },
            -flow_into         => {
                '3' => $self->o('rnaseq_types'),
            }
        },
        #######################NEW HERE. DELETE THIS LINE WHEN DONE.
        {
            -logic_name        => 'VEPDirectoryPaths',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::DirectoryPaths',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                data_category   => 'vep',
                species_dirname => $self->o('species_dirname'),
                analysis_types  => $self->o('vep_types')
            },
            -flow_into         => {
                '3->A' => [ 'ProcessFASTA', 'ProcessGFF' ],
                'A->3' => [ 'Checksum' ],
            }
        },
        ####################### END OF NEW.


        {
            -logic_name      => 'Metadata_JSON',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Metadata_JSON',
            -max_retry_count => 1,
            -parameters      => {},
            -rc_name         => '1GB',
            -flow_into       => {
                '2' => WHEN('defined #ftp_root#' => [ 'Sync_Metadata' ])
            }
        },
        {
            -logic_name      => 'MySQL_TXT',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::MySQL_TXT',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {},
            -rc_name         => '1GB',
            -flow_into       => {
                '2->A' => [ 'MySQL_Compress' ],
                'A->3' => [ 'Checksum' ]
            },
        },
        {
            -logic_name        => 'Homologies_TSV',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DumpSpeciesDBToTsv',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                ref_dbname             => $self->o('ref_dbname'),
                dump_homologies_script => $self->o('dump_homologies_script'),
                per_species_db         => $self->o("compara_host_uri") . '#species#' . '_compara_' . $self->o('rr_ens_version'),
            },
            -flow_into         => {
                '2' => [
                    'CompressHomologyTSV',
                ],
            }
        },
        {
            -logic_name        => 'CompressHomologyTSV',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                cmd => 'if [ -s "#filepath#" ]; then gzip -n -f "#filepath#"; fi',
            },
        },
        {
            -logic_name      => 'Assembly_Chain',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Assembly_Chain',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                ucsc => $self->o('chain_ucsc'),
            },
            -rc_name         => '1GB',
            -flow_into       => {
                '2' => [ 'Genome_Compress' ],
            },
        },
        {
            -logic_name      => 'Genome_FASTA',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Genome_FASTA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                blast_index    => $self->o('blast_index'),
                blastdb_exe    => $self->o('blastdb_exe'),
                per_chromosome => $self->o('dna_per_chromosome'),
            },
            -rc_name         => '4GB',
            -flow_into       => {
                '-1'   => [ 'Genome_FASTA_mem' ],
                '2->A' => [ 'Genome_Compress' ],
                'A->2' => [ 'Symlink_Genome_FASTA' ],
                'A->2' => WHEN('#run_bgz#' => [ 'ProcessFASTA' ]),
            },
        },
        {
            -logic_name      => 'Chromosome_TSV',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Chromosome_TSV',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {},
            -rc_name         => '1GB',
            -flow_into       => {
                '2' => [ 'Genome_Compress' ]
            },
        },
        {
            -logic_name      => 'Geneset_EMBL',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_EMBL',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                per_chromosome => $self->o('embl_per_chromosome'),
            },
            -rc_name         => '2GB',
            -flow_into       => {
                '-1' => [ 'Geneset_EMBL_mem' ],
                '2'  => [ 'Geneset_Compress' ]
            },
        },
        {
            -logic_name      => 'Geneset_FASTA',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_FASTA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                blast_index => $self->o('blast_index'),
                blastdb_exe => $self->o('blastdb_exe'),
            },
            -rc_name         => '1GB',
            -flow_into       => {
                '-1' => [ 'Geneset_FASTA_mem' ],
                '2'  => [ 'Geneset_Compress' ]
            },
        },
        {
            -logic_name      => 'Geneset_GFF3',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                per_chromosome       => $self->o('gff3_per_chromosome'),
                gt_gff3_exe          => $self->o('gt_gff3_exe'),
                gt_gff3validator_exe => $self->o('gt_gff3validator_exe'),
            },
            -rc_name         => '1GB',
            -flow_into       => {
                '-1' => [ 'Geneset_GFF3_mem' ],
                '2->A'  => [ 'Geneset_Compress' ],
                'A->1' =>    WHEN('#run_bgz#' => [ 'ProcessGFF' ]),

            },
        },
        {
            -logic_name      => 'Geneset_GFF3_ENA',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3_ENA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                per_chromosome       => $self->o('gff3_per_chromosome'),
                gt_gff3_exe          => $self->o('gt_gff3_exe'),
                gt_gff3validator_exe => $self->o('gt_gff3validator_exe'),
            },
            -rc_name         => '2GB',
            -flow_into       => {
                '-1' => [ 'Geneset_GFF3_ENA_mem' ],
                '2'  => [ 'Geneset_Compress' ]
            },
        },
        {
            -logic_name      => 'Geneset_GTF',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GTF',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                per_chromosome      => $self->o('gtf_per_chromosome'),
                gtf_to_genepred_exe => $self->o('gtf_to_genepred_exe'),
                genepred_check_exe  => $self->o('genepred_check_exe'),
            },
            -rc_name         => '1GB',
            -flow_into       => {
                '-1' => [ 'Geneset_GTF_mem' ],
                '2'  => [ 'Geneset_Compress' ],
            },
        },
        {
            -logic_name      => 'Xref_TSV',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Xref_TSV',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                external_dbs => $self->o('xref_external_dbs'),
            },
            -rc_name         => '1GB',
            -flow_into       => {
                '-1'   => [ 'Xref_TSV_mem' ],
                '2->A' => [ 'Geneset_Compress' ],
                'A->2' => [ 'Symlink_Xref_TSV' ],
            },
        },
        {
            -logic_name      => 'RNASeq_Exists',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::RNASeq_Exists',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {},
            -rc_name         => '1GB',
            -flow_into       => {
                '2->A' => [ 'Symlink_RNASeq' ],
                'A->2' => [ 'Verify_Unzipped' ],
                '3'    => [ 'RNASeq_Missing' ],
            },
        },
        {
            -logic_name      => 'RNASeq_Missing',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::RNASeq_Missing',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -batch_size      => 10,
            -parameters      => {
                email => $self->o('rnaseq_email'),
            }
        },
        {
            -logic_name      => 'Genome_FASTA_mem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Genome_FASTA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                blast_index    => $self->o('blast_index'),
                blastdb_exe    => $self->o('blastdb_exe'),
                per_chromosome => $self->o('dna_per_chromosome'),
                overwrite      => 1,
            },
            -rc_name         => '8GB',
            -flow_into       => {
                '2->A' => [ 'Genome_Compress' ],
                'A->2' => [ 'Symlink_Genome_FASTA' ],
                'A->2' => WHEN('#run_bgz#' => [ 'ProcessFASTA' ]),
            },
        },
        {
            -logic_name      => 'Geneset_EMBL_mem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_EMBL',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                per_chromosome => $self->o('embl_per_chromosome'),
                overwrite      => 1,
            },
            -rc_name         => '4GB',
            -flow_into       => {
                '2' => [ 'Geneset_Compress' ]
            },
        },
        {
            -logic_name      => 'Geneset_FASTA_mem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_FASTA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                blast_index => $self->o('blast_index'),
                blastdb_exe => $self->o('blastdb_exe'),
                overwrite   => 1,
            },
            -rc_name         => '4GB',
            -flow_into       => {
                '2' => [ 'Geneset_Compress' ]
            },
        },
        {
            -logic_name      => 'Geneset_GFF3_mem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                per_chromosome       => $self->o('gff3_per_chromosome'),
                gt_gff3_exe          => $self->o('gt_gff3_exe'),
                gt_gff3validator_exe => $self->o('gt_gff3validator_exe'),
                overwrite            => 1,
            },
            -rc_name         => '8GB',
            -flow_into       => {
               '2->A' => [ 'Geneset_Compress' ],
                'A->1' =>    WHEN('#run_bgz#' => [ 'ProcessGFF' ]),
            },
        },
        {
            -logic_name      => 'Geneset_GFF3_ENA_mem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3_ENA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                per_chromosome       => $self->o('gff3_per_chromosome'),
                gt_gff3_exe          => $self->o('gt_gff3_exe'),
                gt_gff3validator_exe => $self->o('gt_gff3validator_exe'),
                overwrite            => 1,
            },
            -rc_name         => '8GB',
            -flow_into       => {
                '2' => [ 'Geneset_Compress' ]
            },
        },
        {
            -logic_name      => 'Geneset_GTF_mem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GTF',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                per_chromosome      => $self->o('gtf_per_chromosome'),
                gtf_to_genepred_exe => $self->o('gtf_to_genepred_exe'),
                genepred_check_exe  => $self->o('genepred_check_exe'),
                overwrite           => 1,
            },
            -rc_name         => '4GB',
            -flow_into       => {
                '2' => [ 'Geneset_Compress' ]
            },
        },
        {
            -logic_name      => 'Xref_TSV_mem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Xref_TSV',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                external_dbs => $self->o('xref_external_dbs'),
                overwrite    => 1,
            },
            -rc_name         => '2GB',
            -flow_into       => {
                '2->A' => [ 'Geneset_Compress' ],
                'A->2' => [ 'Symlink_Xref_TSV' ],
            },
        },
        {
            -logic_name        => 'MySQL_Compress',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::Gzip',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {
                compress => "#output_filename#"
            },
            -rc_name           => '1GB',
        },
        {
            -logic_name        => 'Genome_Compress',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::Gzip',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {
                compress => "#output_filename#"
            },
            -rc_name           => '1GB',
            -flow_into         => {
                '-1' => [ 'Genome_Compress_mem' ],
            },
        },
        {
            -logic_name        => 'Genome_Compress_mem',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::Gzip',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {
                compress => "#output_filename#"
            },
            -rc_name           => '4GB',
        },
        {
            -logic_name        => 'Geneset_Compress',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::Gzip',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {
                compress => "#output_filename#"
            },
            -rc_name           => '1GB',
            -flow_into         => {
                '-1' => [ 'Geneset_Compress_mem' ],
            },
        },
        {
            -logic_name        => 'Geneset_Compress_mem',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::Gzip',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {
                compress => "#output_filename#"
            },
            -rc_name           => '4GB',
        },
        {
            -logic_name        => 'Symlink_Genome_FASTA',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Symlink',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {},
        },
        {
            -logic_name        => 'Symlink_RNASeq',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Symlink_RNASeq',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {},
        },
        {
            -logic_name        => 'Symlink_Xref_TSV',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Symlink',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {},
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
            -flow_into         => WHEN('defined #ftp_dir#' => [ 'Sync' ])
        },
        {
            -logic_name        => 'Verify_Unzipped',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Verify',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {
                check_unzipped => 0,
            },
            -flow_into         => WHEN('defined #ftp_dir#' => [ 'Sync' ])
        },
        {
            -logic_name        => 'Sync',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {
                cmd => 'mkdir -p #ftp_dir#; rsync -aLW #output_dir#/ #ftp_dir#',
            },
            -flow_into         => WHEN('#data_category# eq "geneset" || #data_category# eq "genome"' => [ 'README' ]),
            -rc_name           => "dm"
        },
        {
            -logic_name        => 'README',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::README',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
        },
        {
            -logic_name        => 'Sync_Metadata',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {
                cmd => 'rsync -aLW #output_filename# #ftp_root#',
            },
            -rc_name           => "dm"
        },
        #######################NEW HERE. DELETE THIS LINE WHEN DONE.
{
    -logic_name        => 'ProcessFASTA',
    -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
    -parameters        => {
        cmd            => 'bgzip -c #sm_filename# > #out_filename#.bgz && samtools faidx #out_filename#.bgz',
        sm_filename    => '#sm_filename#',
        outdir_suffix  => 'processed_fasta',
    },
    -flow_into         => {
        1 => { ':1' => { 'semaphore' => 'semaphore1' } },  # Signals completion
    },
    -can_be_empty      => 1,
    -hive_capacity     => 10,
    -rc_name           => '4GB',
},

{
    -logic_name        => 'ProcessGFF',
    -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
    -parameters        => {
        cmd            => 'sort -k1,1 -k4,4n -k5,5n -t$\'\\t\' #gff# | bgzip -c > #out_filename#.bgz && tabix -p gff -C #out_filename#.bgz',
        gff            => '#gff#',
        outdir_suffix  => 'processed_gff',
    },
    -flow_into         => {
        1 => { ':1' => { 'semaphore' => 'semaphore2' } },  # Signals completion
    },
    -can_be_empty      => 1,
    -hive_capacity     => 10,
    -rc_name           => '4GB',
},
{
    -logic_name      => 'UpdateDatasetAttribute',
    -module          => 'ensembl.production.hive.HiveDatasetFactory',
    -language        => 'python3',
    -rc_name         => 'default',
    -parameters      => {
        'metadata_db_uri'      => $self->o('metadata_db_uri'),
        'attribute_dict'       => {
            'vep.bgz_location'  => '#output_dir#'  # Only use the directory path, no specific file names
        },
    },
    -semaphore       => 'semaphore1 + semaphore2',  # Wait for both ProcessFASTA and ProcessGFF
    -flow_into       => {
        1 => [ 'Verify' ],  # Continue to verification step after attribute update
    },
},




    ];
}

1;
