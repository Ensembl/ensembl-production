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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::EnsemblBlastDumps_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        # Output
        dump_dir             => undef,
        overwrite            => 0,

        # BLAST executable
        blastdb_exe          => 'makeblastdb',

        # FASTA dump options
        softmasked           => 1,
        unmasked             => 1,
        hardmasked           => 0,
        cds                  => 0,
        fasta_header_prefix  => 'ENSEMBL:',

        # Enable inline blast indexing
        blast_index          => 1,

        # Genome factory - driven by dataset status/type in metadata DB
        dataset_status        => 'Submitted',
        dataset_type          => 'blast',
        update_dataset_status => 'Processing',
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
        dump_dir  => $self->o('dump_dir'),
        overwrite => $self->o('overwrite'),
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
            },
            -rc_name           => '4GB_D',
        },
        {
            -logic_name        => 'GenomeDirectoryPaths',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::BlastDirectoryPaths',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                data_category  => 'genome',
                analysis_types => ['Genome_FASTA'],
            },
            -flow_into         => {
                '3' => ['Genome_FASTA'],
            },
            -rc_name           => '4GB_D',
        },
        {
            -logic_name        => 'GenesetDirectoryPaths',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::BlastDirectoryPaths',
            -max_retry_count   => 1,
            -analysis_capacity => 20,
            -parameters        => {
                data_category  => 'geneset',
                analysis_types => ['Geneset_FASTA'],
            },
            -flow_into         => {
                '3' => ['Geneset_FASTA'],
            },
            -rc_name           => '4GB_D',
        },
        {
            -logic_name      => 'Genome_FASTA',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Genome_FASTA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                blast_index         => $self->o('blast_index'),
                blastdb_exe         => $self->o('blastdb_exe'),
                unmasked            => $self->o('unmasked'),
                softmasked          => $self->o('softmasked'),
                hardmasked          => $self->o('hardmasked'),
                overwrite           => 1,
                fasta_header_prefix => $self->o('fasta_header_prefix'),
            },
            -rc_name         => '32GB_D',
            -flow_into       => {
                '-1' => ['Genome_FASTA_mem'],
            },
        },
        {
            -logic_name      => 'Genome_FASTA_mem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Genome_FASTA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                blast_index         => $self->o('blast_index'),
                blastdb_exe         => $self->o('blastdb_exe'),
                unmasked            => $self->o('unmasked'),
                softmasked          => $self->o('softmasked'),
                hardmasked          => $self->o('hardmasked'),
                overwrite           => 1,
                fasta_header_prefix => $self->o('fasta_header_prefix'),
            },
            -rc_name         => '50GB_D',
        },
        {
            -logic_name      => 'Geneset_FASTA',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_FASTA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                blast_index         => $self->o('blast_index'),
                blastdb_exe         => $self->o('blastdb_exe'),
                cds                 => $self->o('cds'),
                fasta_header_prefix => $self->o('fasta_header_prefix'),
            },
            -rc_name         => '32GB_D',
            -flow_into       => {
                '-1' => ['Geneset_FASTA_mem'],
            },
        },
        {
            -logic_name      => 'Geneset_FASTA_mem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_FASTA',
            -max_retry_count => 1,
            -hive_capacity   => 10,
            -parameters      => {
                blast_index         => $self->o('blast_index'),
                blastdb_exe         => $self->o('blastdb_exe'),
                overwrite           => 1,
                cds                 => $self->o('cds'),
                fasta_header_prefix => $self->o('fasta_header_prefix'),
            },
            -rc_name         => '50GB_D',
        },
    ];
}

1;