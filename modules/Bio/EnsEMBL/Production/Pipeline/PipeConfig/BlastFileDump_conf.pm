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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::BlastFileDump_conf;

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

        genome_types           => [], # Possible values: 'Assembly_Chain', 'Chromosome_TSV', 'Genome_FASTA'
        geneset_types          => [], # Possible values: 'Geneset_EMBL', 'Geneset_FASTA', 'Geneset_GFF3', 'Geneset_GFF3_ENA', 'Geneset_GTF', 'Xref_TSV'
        rnaseq_types           => [], # Possible values: 'RNASeq_Exists'

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
        rr_ens_version         => $self->o('ENV', 'RR_ENS_VERSION'),
        ref_dbname             => 'ensembl_compara_references',
        compara_host_uri       => '',

        #blast param for new site
        'hardmasked'          => 1,
        'cds'                 => 1,   
        'timestamped_dir'     => 1,
        #genome factory params
      	'dataset_status' => 'Submitted', #fetch genomes with dataset status submitted
    	'dataset_type'   => 'blast', #fetch genomes with dataset blast
    	'update_dataset_status' => 'Processing', #updates dataset status to processing in new metadata db
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
            -logic_name        => 'SpeciesFactory',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {},
            -flow_into         => {
                '2' => [
                    'GenomeDirectoryPaths',
                    'GenesetDirectoryPaths',
                ],
            }
            
        },        
        {
            -logic_name        => 'GenomeDirectoryPaths',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::BlastDirectoryPaths',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                data_category  => 'genome',
                analysis_types => $self->o('genome_types'),
            },
            -flow_into         => {
                '3' => $self->o('genome_types'),
            },
        },
        {
            -logic_name        => 'GenesetDirectoryPaths',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::BlastDirectoryPaths',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                data_category  => 'geneset',
                analysis_types => $self->o('geneset_types'),
            },
            -flow_into         => {
                '3' => $self->o('geneset_types'),
                
            },
        },
        {
            -logic_name      => 'Genome_FASTA',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Genome_FASTA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                blast_index    => 0,
                blastdb_exe    => $self->o('blastdb_exe'),
                per_chromosome => $self->o('dna_per_chromosome'),
                hardmasked  => $self->o('hardmasked'),
                timestamped => $self->o('timestamped'),
            },
            -rc_name         => '4GB',
            -flow_into       => {
                '-1'   => [ 'Genome_FASTA_mem' ],
            },
        },
        {
            -logic_name      => 'Geneset_FASTA',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_FASTA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                blast_index => 0,
                blastdb_exe => $self->o('blastdb_exe'),
                cds         => $self->o('cds'),
            },
            -rc_name         => '1GB',
            -flow_into       => {
                '-1' => [ 'Geneset_FASTA_mem' ],
            },
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
                hardmasked     => $self->o('hardmasked'),
                overwrite      => 1,
            },
            -rc_name         => '8GB',
        },
        {
            -logic_name      => 'Geneset_FASTA_mem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_FASTA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                blast_index => 0,
                blastdb_exe => $self->o('blastdb_exe'),
                overwrite   => 1,
                cds         => $self->o('cds'),
            },
            -rc_name         => '4GB',

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
        },        

    ];
}

1;
