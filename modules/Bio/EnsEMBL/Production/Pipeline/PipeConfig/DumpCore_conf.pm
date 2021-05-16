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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf;

use strict;
use warnings;
use File::Spec;
use Data::Dumper;
use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        ## inherit other stuff from the base class
        %{$self->SUPER::default_options()},

        ## General parameters
        'registry'               => $self->o('registry'),
        'release'                => $self->o('release'),
        'pipeline_name'          => "ftp_pipeline",
        'email'                  => $self->o('ENV', 'USER') . '@ebi.ac.uk',
        'ftp_dir'                => '/nfs/nobackup/ensemblgenomes/' . $self->o('ENV', 'USER') . '/workspace/' . $self->o('pipeline_name') . '/ftp_site/release-' . $self->o('release'),
        'dumps'                  => [],

        ## 'job_factory' parameters
        'species'                => [],
        'antispecies'            => [],
        'division'               => [],
        'dbname'                 => undef,
        'run_all'                => 0,

        ## Flag to skip metadata database check for dumping DNA only for species with update assembly
        'skip_metadata_check'    => 0,

        #  'fasta' - cdna, cds, dna, ncrna, pep
        #  'chain' - assembly chain files
        #  'tsv'   - ena & uniprot

        ## gff3 & gtf parameter
        'abinitio'               => 1,
        'gene'                   => 1,

        ## gtf parameters, e! specific
        'gtftogenepred_exe'      => 'gtfToGenePred',
        'genepredcheck_exe'      => 'genePredCheck',

        ## gff3 parameters
        'gt_exe'                 => 'gt',
        'gff3_tidy'              => $self->o('gt_exe') . ' gff3 -tidy -sort -retainids -fixregionboundaries -force',
        'gff3_validate'          => $self->o('gt_exe') . ' gff3validator',

        'feature_type'           => [ 'Gene', 'Transcript', 'SimpleFeature' ], #'RepeatFeature'
        'per_chromosome'         => 1,
        'include_scaffold'       => 1,
        'logic_name'             => [],
        'db_type'                => 'core',
        'out_file_stem'          => undef,
        'xrefs'                  => 0,

        ## fasta parameters
        # types to emit
        'dna_sequence_type_list' => [ 'dna' ],
        'pep_sequence_type_list' => [ 'cdna', 'ncrna' ],
        # Do/Don't process these logic names
        'process_logic_names'    => [],
        'skip_logic_names'       => [],
        # Previous release FASTA DNA files location
        # Previous release number
        'prev_rel_dir'           => '/nfs/ensemblftp/PUBLIC/pub/',

        ## assembly_chain parameters
        #  default => ON (1)
        'compress'               => 1,
        'ucsc'                   => 1,

        ## BLAT
        # A list of vertebrates species for which we have Blast server running with their associated port number
        # We use this hash to filter our species which we don't need BLAT data and to have the port number in the file name
        'blat_species'           => {
            'homo_sapiens'                     => 30001,
            'mus_musculus'                     => 30081,
            'danio_rerio'                      => 30003,
            'rattus_norvegicus'                => 30005,
            'gallus_gallus'                    => 30010,
            'canis_lupus_familiaris'           => 30014,
            'bos_taurus'                       => 30017,
            'oryctolagus_cuniculus'            => 30025,
            'oryzias_latipes'                  => 30026,
            'sus_scrofa'                       => 30039,
            'meleagris_gallopavo'              => 30082,
            'anas_platyrhynchos_platyrhynchos' => 30066,
            'ovis_aries'                       => 30068,
            'oreochromis_niloticus'            => 30073,
            'gadus_morhua'                     => 30080,
        },
        # History file for storing record of datacheck run.
        history_file             => undef,
        datacheck_output_dir     => undef,
        ## Indexing parameters
        'skip_blat'              => 0,
        'skip_ncbiblast'         => 0,
        'skip_blat_masking'      => 1,
        'skip_ncbiblast_masking' => 0,
        ## Indexing parameters
        'skip_convert_fasta'     => 0,

    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        # inheriting database and hive tables' creation
        @{$self->SUPER::pipeline_create_commands},
        'mkdir -p ' . $self->o('ftp_dir'),
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

# Override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
    my ($self) = @_;
    return
        ' -reg_conf ' . $self->o('registry'),
    ;
}

# these parameter values are visible to all analyses, 
# can be overridden by parameters{} and input_id{}
sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},    # here we inherit anything from the base class
        'pipeline_name' => $self->o('pipeline_name'), #This must be defined for the beekeeper to work properly
        'base_path'     => $self->o('ftp_dir'),
        'release'       => $self->o('release'),
    };
}

sub resource_classes {
  my ($self) = @_;
  return {
     '32GB' => { 'LSF' => '-q production  -M 32000 -R "rusage[mem=32000]"' },
     '64GB' => { 'LSF' => '-q production - M 64000 -R "rusage[mem=64000]"' },
    '128GB' => { 'LSF' => '-q production -M 128000 -R "rusage[mem=128000]"' },
    '256GB' => { 'LSF' => '-q production -M 256000 -R "rusage[mem=256000]"' },
  }
}

sub pipeline_analyses {
    my ($self) = @_;

    my $pipeline_flow;
    # Getting list of dumps from argument
    my $dumps = $self->o('dumps');
    # Checking if the list of dumps is an array
    my @dumps = (ref($dumps) eq 'ARRAY') ? @$dumps : ($dumps);
    #Pipeline_flow will contain the dumps from the dumps list
    if (scalar @dumps) {
        $pipeline_flow = $dumps;
    }
    # Else, we run all the dumps
    else {
        $pipeline_flow = [ 'json', 'gtf', 'gff3', 'embl', 'fasta_dna', 'fasta_pep', 'genbank', 'assembly_chain_datacheck', 'tsv_uniprot', 'tsv_ena', 'tsv_metadata', 'tsv_refseq', 'tsv_entrez' ];
    }

    return [
        { -logic_name        => 'job_factory',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            -parameters      => {
                species     => $self->o('species'),
                antispecies => $self->o('antispecies'),
                division    => $self->o('division'),
                dbname      => $self->o('dbname'),
                run_all     => $self->o('run_all'),
            },
            -input_ids       => [ {} ],
            -hive_capacity   => -1,
            -max_retry_count => 1,
            -flow_into       => { '2' => 'backbone_job_pipeline', },
        },
        { -logic_name      => 'backbone_job_pipeline',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -hive_capacity => -1,
            -flow_into     => { '1->A' => $pipeline_flow,
                'A->1'                 => [ 'checksum_generator' ],
            }
        },
        ### GENERATE CHECKSUM
        { -logic_name      => 'checksum_generator',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Common::ChksumGenerator',
            -parameters    => {
                dumps              => $pipeline_flow,
                skip_convert_fasta => $self->o('skip_convert_fasta')
            },
            -hive_capacity => 10,
        },
        ### GTF
        { -logic_name      => 'gtf',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile',
            -parameters    => {
                gtf_to_genepred => $self->o('gtftogenepred_exe'),
                gene_pred_check => $self->o('genepredcheck_exe'),
                abinitio        => $self->o('abinitio'),
                gene            => $self->o('gene')
            },
            -hive_capacity => 50,
            -rc_name       => '2GB',
            -flow_into     => { '-1' => 'gtf_32GB', },
        },

        { -logic_name      => 'gtf_32GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile',
            -parameters    => {
                gtf_to_genepred => $self->o('gtftogenepred_exe'),
                gene_pred_check => $self->o('genepredcheck_exe'),
                abinitio        => $self->o('abinitio'),
                gene            => $self->o('gene')
            },
            -hive_capacity => 50,
            -rc_name       => '32GB',
            -flow_into     => { '-1' => 'gtf_64GB', },
        },

        { -logic_name      => 'gtf_64GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile',
            -parameters    => {
                gtf_to_genepred => $self->o('gtftogenepred_exe'),
                gene_pred_check => $self->o('genepredcheck_exe'),
                abinitio        => $self->o('abinitio'),
                gene            => $self->o('gene')
            },
            -hive_capacity => 50,
            -rc_name       => '64GB',
            -flow_into     => { '-1' => 'gtf_128GB', },
        },

        { -logic_name      => 'gtf_128GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile',
            -parameters    => {
                gtf_to_genepred => $self->o('gtftogenepred_exe'),
                gene_pred_check => $self->o('genepredcheck_exe'),
                abinitio        => $self->o('abinitio'),
                gene            => $self->o('gene')
            },
            -hive_capacity => 50,
            -rc_name       => '128GB',
        },

        ### GFF3
        { -logic_name      => 'gff3',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
            -parameters    => {
                feature_type     => $self->o('feature_type'),
                per_chromosome   => $self->o('per_chromosome'),
                include_scaffold => $self->o('include_scaffold'),
                logic_name       => $self->o('logic_name'),
                db_type          => $self->o('db_type'),
                abinitio         => $self->o('abinitio'),
                gene             => $self->o('gene'),
                out_file_stem    => $self->o('out_file_stem'),
                xrefs            => $self->o('xrefs'),
            },
            -hive_capacity => 50,
            -rc_name       => '2GB',
            -flow_into     => { '-1' => 'gff3_32GB', '1' => 'tidy_gff3', },
        },

        { -logic_name      => 'gff3_32GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
            -parameters    => {
                feature_type     => $self->o('feature_type'),
                per_chromosome   => $self->o('per_chromosome'),
                include_scaffold => $self->o('include_scaffold'),
                logic_name       => $self->o('logic_name'),
                db_type          => $self->o('db_type'),
                abinitio         => $self->o('abinitio'),
                gene             => $self->o('gene'),
                out_file_stem    => $self->o('out_file_stem'),
                xrefs            => $self->o('xrefs'),
            },
            -hive_capacity => 50,
            -rc_name       => '32GB',
            -flow_into     => { '-1' => 'gff3_64GB', '1' => 'tidy_gff3', },
        },
        { -logic_name      => 'gff3_64GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
            -parameters    => {
                feature_type     => $self->o('feature_type'),
                per_chromosome   => $self->o('per_chromosome'),
                include_scaffold => $self->o('include_scaffold'),
                logic_name       => $self->o('logic_name'),
                db_type          => $self->o('db_type'),
                abinitio         => $self->o('abinitio'),
                gene             => $self->o('gene'),
                out_file_stem    => $self->o('out_file_stem'),
                xrefs            => $self->o('xrefs'),
            },
            -hive_capacity => 50,
            -rc_name       => '64GB',
            -flow_into     => { '-1' => 'gff3_128GB', '1' => 'tidy_gff3', },
        },
        { -logic_name      => 'gff3_128GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
            -parameters    => {
                feature_type     => $self->o('feature_type'),
                per_chromosome   => $self->o('per_chromosome'),
                include_scaffold => $self->o('include_scaffold'),
                logic_name       => $self->o('logic_name'),
                db_type          => $self->o('db_type'),
                abinitio         => $self->o('abinitio'),
                gene             => $self->o('gene'),
                out_file_stem    => $self->o('out_file_stem'),
                xrefs            => $self->o('xrefs'),
            },
            -hive_capacity => 50,
            -rc_name       => '128GB',
            -flow_into     => { '1' => 'tidy_gff3', },
        },

        ### GFF3:post-processing
        { -logic_name      => 'tidy_gff3',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => { cmd => $self->o('gff3_tidy') . ' -gzip -o #out_file#.sorted.gz #out_file#', },
            -hive_capacity => 10,
            -batch_size    => 10,
            -flow_into     => 'move_gff3',
        },

        {
            -logic_name    => 'move_gff3',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => { cmd => 'mv #out_file#.sorted.gz #out_file#', },
            -hive_capacity => 10,
            -flow_into     => 'validate_gff3',
        },

        {
            -logic_name    => 'validate_gff3',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => { cmd => $self->o('gff3_validate') . ' #out_file#', },
            -hive_capacity => 10,
            -batch_size    => 10,
        },

        ### EMBL
        { -logic_name      => 'embl',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
            -parameters    => { type => 'embl', },
            -hive_capacity => 50,
            -rc_name       => '4GB',
            -flow_into     => { '-1' => 'embl_32GB', },
        },

        { -logic_name      => 'embl_32GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
            -parameters    => { type => 'embl', },
            -hive_capacity => 50,
            -rc_name       => '32GB',
            -flow_into     => { '-1' => 'embl_64GB', },
        },

        { -logic_name      => 'embl_64GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
            -parameters    => { type => 'embl', },
            -hive_capacity => 50,
            -rc_name       => '64GB',
            -flow_into     => { '-1' => 'embl_128GB', },
        },

        { -logic_name      => 'embl_128GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
            -parameters    => { type => 'embl', },
            -hive_capacity => 50,
            -rc_name       => '128GB',
        },

        ### GENBANK
        { -logic_name      => 'genbank',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
            -parameters    => { type => 'genbank', },
            -hive_capacity => 50,
            -rc_name       => '4GB',
            -flow_into     => { -1 => 'genbank_32GB', },
        },

        { -logic_name      => 'genbank_32GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
            -parameters    => { type => 'genbank', },
            -hive_capacity => 50,
            -rc_name       => '32GB',
            -flow_into     => { -1 => 'genbank_64GB', },
        },

        { -logic_name      => 'genbank_64GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
            -parameters    => { type => 'genbank', },
            -hive_capacity => 50,
            -rc_name       => '64GB',
            -flow_into     => { -1 => 'genbank_128GB', },
        },

        { -logic_name      => 'genbank_128GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
            -parameters    => { type => 'genbank', },
            -hive_capacity => 50,
            -rc_name       => '128GB',
        },

        ### FASTA (cdna, cds, dna, pep, ncrna)
        { -logic_name        => 'fasta_pep',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::DumpFile',
            -parameters      => {
                sequence_type_list  => $self->o('pep_sequence_type_list'),
                process_logic_names => $self->o('process_logic_names'),
                skip_logic_names    => $self->o('skip_logic_names'),
            },
            -can_be_empty    => 1,
            -max_retry_count => 1,
            -hive_capacity   => 20,
            -priority        => 5,
            -rc_name         => '2GB',
        },
        { -logic_name        => 'fasta_dna',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::CheckAssemblyGeneset',
            -parameters      => {
                skip_metadata_check => $self->o('skip_metadata_check'),
                release             => $self->o('release')
            },
            -can_be_empty    => 1,
            -flow_into       => {
                1 => WHEN(
                    '#new_assembly# >= 1 || #new_genebuild# >= 1' => 'dna',
                    ELSE 'copy_dna',
                ) },
            -max_retry_count => 1,
            -hive_capacity   => 20,
            -priority        => 5,
        },
        { -logic_name        => 'dna',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::DumpFile',
            -parameters      => {
                sequence_type_list  => $self->o('dna_sequence_type_list'),
                process_logic_names => $self->o('process_logic_names'),
                skip_logic_names    => $self->o('skip_logic_names'),
            },
            -can_be_empty    => 1,
            -flow_into       => { 1 => 'concat_fasta' },
            -max_retry_count => 1,
            -hive_capacity   => 20,
            -priority        => 5,
            -rc_name         => '4GB',
        },
        {
            -logic_name    => 'copy_dna',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::FASTA::CopyDNA',
            -can_be_empty  => 1,
            -hive_capacity => 20,
            -priority      => 5,
            -parameters    => {
                ftp_dir => $self->o('prev_rel_dir'),
                release => $self->o('release')
            },
        },
        # Creating the 'toplevel' dumps for 'dna', 'dna_rm' & 'dna_sm'
        { -logic_name        => 'concat_fasta',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::ConcatFiles',
            -can_be_empty    => 1,
            -parameters      => {
                blat_species => $self->o('blat_species'),
            },
            -max_retry_count => 5,
            -priority        => 5,
            -flow_into       => {
                1 => [ qw/primary_assembly/ ]
            },
        },

        { -logic_name        => 'primary_assembly',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::CreatePrimaryAssembly',
            -can_be_empty    => 1,
            -max_retry_count => 5,
            -priority        => 5,
        },

        ### ASSEMBLY CHAIN
        {
            -logic_name        => 'assembly_chain_datacheck',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
            -parameters        => {
                datacheck_names => [ 'MetaKeyAssembly' ],
                history_file    => $self->o('history_file'),
                output_dir      => $self->o('datacheck_output_dir'),
                failures_fatal  => 0,
            },
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -flow_into         => { '3' => 'assembly_chain',
                '4'                     => 'report_failed_assembly_chain' }
        },
        { -logic_name      => 'assembly_chain',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Chainfile::DumpFile',
            -parameters    => {
                compress => $self->o('compress'),
                ucsc     => $self->o('ucsc'),
            },
            -hive_capacity => 50,
            -flow_into     => { '-1' => 'assembly_chain_32GB', },
        },
        { -logic_name      => 'assembly_chain_32GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Chainfile::DumpFile',
            -parameters    => {
                compress => $self->o('compress'),
                ucsc     => $self->o('ucsc'),
            },
            -hive_capacity => 50,
            -rc_name       => '32GB',
        },
        {
            -logic_name        => 'report_failed_assembly_chain',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailNotify',
            -parameters        => { 'email' => $self->o('email') },
            -max_retry_count   => 1,
            -analysis_capacity => 10,
        },

        ### JSON dumps
        { -logic_name      => 'json',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::JSON::DumpGenomeJson',
            -parameters    => {},
            -hive_capacity => 50,
            -rc_name       => '4GB',
            -flow_into     => { -1 => 'json_16GB', },
        },

        { -logic_name      => 'json_16GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::JSON::DumpGenomeJson',
            -parameters    => {},
            -hive_capacity => 50,
            -rc_name       => '16GB',
            -flow_into     => { -1 => 'json_32GB', },
        },

        { -logic_name      => 'json_32GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::JSON::DumpGenomeJson',
            -parameters    => {},
            -hive_capacity => 50,
            -rc_name       => '32GB',
            -flow_into     => { -1 => 'json_64GB', },
        },

        { -logic_name      => 'json_64GB',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::JSON::DumpGenomeJson',
            -parameters    => {},
            -hive_capacity => 50,
            -rc_name       => '64GB',
        },

        ### TSV XREF
        { -logic_name      => 'tsv_uniprot',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::TSV::DumpFileXref',
            -parameters    => {
                external_db => 'UniProt%',
                type        => 'uniprot',
            },
            -hive_capacity => 50,
            -rc_name       => '2GB',
        },

        { -logic_name      => 'tsv_refseq',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::TSV::DumpFileXref',
            -parameters    => {
                external_db => 'RefSeq%',
                type        => 'refseq',
            },
            -hive_capacity => 50,
            -rc_name       => '2GB',
        },

        { -logic_name      => 'tsv_entrez',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::TSV::DumpFileXref',
            -parameters    => {
                external_db => 'Entrez%',
                type        => 'entrez',
            },
            -hive_capacity => 50,
            -rc_name       => '2GB',
        },


        { -logic_name      => 'tsv_ena',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::TSV::DumpFileEna',
            -hive_capacity => 50,
            -rc_name       => '2GB',
        },

        { -logic_name      => 'tsv_metadata',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::TSV::DumpFileMetadata',
            -hive_capacity => 50,
            -rc_name       => '2GB',
        },

    ];
}

1;

