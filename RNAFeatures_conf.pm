=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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


=pod

=head1 NAME
Bio::EnsEMBL::EGPipeline::PipeConfig::RNAFeatures_conf

=head1 DESCRIPTION

Configuration for running the RNA Features pipeline, which
primarily adds RNA genes to a core database.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::RNAFeatures_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'rna_features_'.$self->o('ensembl_release'),

    species => [],
    antispecies => [],
    division => [],
    run_all => 0,
    meta_filters => {},

    # Parameters for dumping and splitting Fasta DNA files...
    max_seq_length          => 10000000,
    max_seq_length_per_file => $self->o('max_seq_length'),
    max_seqs_per_file       => undef,
    max_files_per_directory => 50,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),

    max_hive_capacity => 100,

    run_cmscan   => 1,
    run_trnascan => 1,

    program_dir  => '/nfs/panda/ensemblgenomes/external/bin',
    cmscan_exe   => catdir($self->o('program_dir'), 'cmscan'),

    cmscan_cm_file    => {},
    cmscan_logic_name => {},
    cmscan_db_name    => {},
    cmscan_cpu        => 1,
    cmscan_param_hash =>
    {
      cpu            => $self->o('cmscan_cpu'),
      heuristics     => 'default',
      threshold      => 0.001, # 0.000001 is probably needed to weed out FPs; but keep it low, since we can always filter on evalue in the resultant table anyway...
      recreate_index => 0,
    },
    cmscan_parameters => '',

    # The rRNA predictions via cmscan are OK; RNAMMER (formerly used for rRNA)
    # has a similar algorithm to cmscan, so doesn't produce very different
    # results. However, cmscan annotates RNA genes that are out of the relevant
    # taxonomic range; eg SSU_rRNA_microsporidia (RF02542) looks sufficiently
    # like SSU_rRNA_eukarya (RF01960) that they both get annotated in the same
    # places, as do bacterial and archaeal genes. Need to implement some
    # taxonomic filtering here...

    # The blacklist consists of Rfam models that generate an excess of
    # alignments. They are all miRNA precursors which resemble repeat features,
    # so it's not clear if asking Rfam to tweak the covariance models would
    # help much. They tend to be taxonomically restricted (e.g to rice or
    # primate species), so that would be a good way to filter. Rfam have yet
    # to respond to my query about the best way to address taxonomic filtering.
    rfam_version    => 12,
    rfam_dir        => '/nfs/panda/ensemblgenomes/external/Rfam',
    rfam_cm_file    => catdir($self->o('rfam_dir'), $self->o('rfam_version'), 'Rfam.cm'),
    rfam_logic_name => 'cmscan_rfam_'.$self->o('rfam_version'),
    rfam_db_name    => 'RFAM',
    rfam_trna       => 0,
    rfam_rrna       => 1,
    rfam_blacklist  => [], # ['RF00885', 'RF00886', ],

    # For tRNA, the generic cmscan approach with Rfam CMs produces too many
    # false positives for comfort, so tRNASCAN-SE remains the tool of choice,
    # even though that also tends to have a lot of false positives.
    trnascan_dir        => '/nfs/panda/ensemblgenomes/external/tRNAscan-SE-1.3.1/bin',
    trnascan_exe        => catdir($self->o('trnascan_dir'), 'tRNAscan-SE'),
    trnascan_logic_name => 'trnascan',
    trnascan_param_hash =>
    {
      db_name => 'TRNASCAN_SE',
      pseudo  => 0,
    },
    trnascan_parameters => '',

    analyses =>
    [
      {
        'logic_name'      => $self->o('rfam_logic_name'),
        'db'              => 'Rfam',
        'db_version'      => $self->o('rfam_version'),
        'db_file'         => $self->o('rfam_cm_file'),
        'program'         => 'Infernal',
        'program_version' => '1.1',
        'program_file'    => $self->o('cmscan_exe'),
        'parameters'      => $self->o('cmscan_parameters'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::CMScan',
        'linked_tables'   => ['dna_align_feature'],
      },
      {
        'logic_name'      => 'cmscan_custom',
        'program'         => 'Infernal',
        'program_version' => '1.1',
        'program_file'    => $self->o('cmscan_exe'),
        'parameters'      => $self->o('cmscan_parameters'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::CMScan',
        'linked_tables'   => ['dna_align_feature'],
      },
      {
        'logic_name'      => $self->o('trnascan_logic_name'),
        'program'         => 'tRNAscan-SE',
        'program_version' => '1.3.1',
        'program_file'    => $self->o('trnascan_exe'),
        'parameters'      => $self->o('trnascan_parameters'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::tRNAscan',
        'linked_tables'   => ['dna_align_feature'],
      },
    ],

    # Remove existing DNA features; if => 0 then existing analyses
    # and their features will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,

    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,

    # By default, an email is sent for each species when the pipeline
    # is complete, showing a summary of the RNA annotation.
    email_rna_report => 1,
  };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  my $options = join(' ',
    $self->SUPER::beekeeper_extra_cmdline_options,
    "-reg_conf ".$self->o('registry')
  );
  
  return $options;
}

# Ensures that species output parameter gets propagated implicitly.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('pipeline_dir'),
  ];
}

sub pipeline_analyses {
  my ($self) = @_;

  my $flow_to_email = [];
  if ($self->o('email_rna_report')) {
    $flow_to_email = ['EmailRNAReport'];
  }

  return [
    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              species         => $self->o('species'),
                              antispecies     => $self->o('antispecies'),
                              division        => $self->o('division'),
                              run_all         => $self->o('run_all'),
                              meta_filters    => $self->o('meta_filters'),
                              chromosome_flow => 0,
                              variation_flow  => 0,
                            },
      -input_ids         => [ {} ],
      -flow_into         => {
                              '2->A' => ['BackupDatabase'],
                              'A->2' => ['MetaCoords'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'BackupDatabase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -analysis_capacity => 5,
      -max_retry_count   => 1,
      -parameters        => {
                              output_file => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1->A' => ['RNAAnalysisFactory'],
                              'A->1' => ['DumpGenome'],
                            },
    },

    {
      -logic_name        => 'RNAAnalysisFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::RNAAnalysisFactory',
      -max_retry_count   => 0,
      -batch_size        => 10,
      -parameters        => {
                              analyses            => $self->o('analyses'),
                              run_cmscan          => $self->o('run_cmscan'),
                              run_trnascan        => $self->o('run_trnascan'),
                              rfam_logic_name     => $self->o('rfam_logic_name'),
                              trnascan_logic_name => $self->o('trnascan_logic_name'),
                              cmscan_cm_file      => $self->o('cmscan_cm_file'),
                              cmscan_logic_name   => $self->o('cmscan_logic_name'),
                              pipeline_dir        => $self->o('pipeline_dir'),
                              db_backup_file      => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['AnalysisSetup'],
                            },
    },

    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -batch_size        => 10,
      -parameters        => {
                              db_backup_required => 1,
                              delete_existing    => $self->o('delete_existing'),
                              production_lookup  => $self->o('production_lookup'),
                              production_db      => $self->o('production_db'),
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'DumpGenome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpGenome',
      -analysis_capacity => 5,
      -parameters        => {
                              genome_dir => catdir($self->o('pipeline_dir'), '#species#'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['SplitDumpFile'],
    },

    {
      -logic_name        => 'SplitDumpFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::SplitDumpFile',
      -parameters        => {
                              fasta_file              => '#genome_file#',
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              run_cmscan              => $self->o('run_cmscan'),
                              run_trnascan            => $self->o('run_trnascan'),
                            },
      -rc_name           => '8Gb_mem',
      -flow_into         => {
                              '3' => ['CMScanFactory'],
                              '4' => ['tRNAscan'],
                            },
    },

    {
      -logic_name        => 'CMScanFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CMScanFactory',
      -batch_size        => 100,
      -max_retry_count   => 1,
      -parameters        => {
                              rfam_cm_file      => $self->o('rfam_cm_file'),
                              rfam_logic_name   => $self->o('rfam_logic_name'),
                              cmscan_cm_file    => $self->o('cmscan_cm_file'),
                              cmscan_logic_name => $self->o('cmscan_logic_name'),
                              cmscan_db_name    => $self->o('cmscan_db_name'),
                              parameters_hash   => $self->o('cmscan_param_hash'),
                              max_seq_length    => $self->o('max_seq_length'),
                            },
      -rc_name           => '8Gb_mem',
      -flow_into         => {
                              '2' => ['CMScan'],
                            },
    },

    {
      -logic_name        => 'CMScan',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CMScan',
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 1,
      -parameters        => {
                              rfam_trna      => $self->o('rfam_trna'),
                              rfam_rrna      => $self->o('rfam_rrna'),
                              rfam_blacklist => $self->o('rfam_blacklist'),
                            },
      -rc_name           => 'cmscan_4Gb_mem',
      -flow_into         => {
                              '-1' => ['CMScan_HighMem'],
                            },
    },

    {
      -logic_name        => 'CMScan_HighMem',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CMScan',
      -can_be_empty      => 1,
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 0,
      -parameters        => {
                              rfam_trna      => $self->o('rfam_trna'),
                              rfam_rrna      => $self->o('rfam_rrna'),
                              rfam_blacklist => $self->o('rfam_blacklist'),
                            },
      -rc_name           => 'cmscan_8Gb_mem',
    },

    {
      -logic_name        => 'tRNAscan',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::tRNAscan',
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 1,
      -parameters        => {
                              trnascan_dir    => $self->o('trnascan_dir'),
                              logic_name      => $self->o('trnascan_logic_name'),
                              parameters_hash => $self->o('trnascan_param_hash'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'MetaCoords',
      -module            => 'Bio::EnsEMBL::EGPipeline::CoreStatistics::MetaCoords',
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => $flow_to_email,
    },

    {
      -logic_name        => 'EmailRNAReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::EmailRNAReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email             => $self->o('email'),
                              subject           => 'RNA features pipeline: cmscan report for #species#',
                              run_cmscan        => $self->o('run_cmscan'),
                              run_trnascan      => $self->o('run_trnascan'),
                              rfam_logic_name   => $self->o('rfam_logic_name'),
                              cmscan_cm_file    => $self->o('cmscan_cm_file'),
                              cmscan_logic_name => $self->o('cmscan_logic_name'),
                            },
      -rc_name           => 'normal',
    }

  ];
}

sub resource_classes {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::resource_classes},
    'cmscan_4Gb_mem' => {'LSF' => '-q production-rh6 -n '.$self->o('cmscan_cpu').' -M 4000 -R "rusage[mem=4000]"'},
    'cmscan_8Gb_mem' => {'LSF' => '-q production-rh6 -n '.$self->o('cmscan_cpu').' -M 8000 -R "rusage[mem=8000]"'},
  }
}

1;
