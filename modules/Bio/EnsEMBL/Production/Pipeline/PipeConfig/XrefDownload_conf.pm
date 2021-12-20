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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::XrefDownload_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub default_options {
  my ($self) = @_;

  return {
    %{$self->SUPER::default_options()},
    'work_dir'       => $self->o('ENV', 'BASE_DIR'),
    'sql_dir'          => $self->o('work_dir')."/ensembl/misc-scripts/xref_mapping",
    'release'          => $self->o('ensembl_release'),
    'source_xref'      => '',

    # Parameters for source download
    'config_file'   => $self->o('work_dir')."/ensembl-production/modules/Bio/EnsEMBL/Production/Pipeline/Xrefs/xref_sources.json",
    'source_url'    => '',
    'source_dir'    => $self->o('work_dir')."/ensembl-production/modules/Bio/EnsEMBL/Production/Pipeline/Xrefs/sql",
    'reuse_db'      => 0,
    'skip_download' => 0,
    'skip_preparse' => 0,

    # Parameters for cleaning up files
    'clean_files'   => 1,
    'clean_dir'     => $self->o('base_path')."/clean_files",

    # Don't need lots of retries for most analyses
    'hive_default_max_retry_count' => 1,
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name => 'schedule_download',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::ScheduleDownload',
      -comment    => 'Creates the database in -source_url. Reads the sources in -config_file and creates a job for each source to download.',
      -input_ids  => [{}],
      -parameters => {
        config_file   => $self->o('config_file'),
        source_dir    => $self->o('source_dir'),
        source_url    => $self->o('source_url'),
        reuse_db      => $self->o('reuse_db'),
        skip_download => $self->o('skip_download')
      },
      -flow_into  => {
        '2->A' => 'download_source',
        'A->1' => 'schedule_cleanup'
      },
      -rc_name    => 'small'
    },
    {
      -logic_name      => 'download_source',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::DownloadSource',
      -comment         => 'Downloads the source files and stores then in -base_path.',
      -parameters      => {
        base_path => $self->o('base_path')
      },
      -rc_name         => 'normal',
      -max_retry_count => 3
    },
    {
      -logic_name => 'schedule_cleanup',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::ScheduleCleanup',
      -comment    => 'Reads the source names from the source table and creates a job for each source to be cleaned up.',
      -parameters      => {
        base_path => $self->o('base_path')
      },
      -flow_into  => {
        '1->A' => 'checksum',
        '2->A' => 'cleanup_refseq_dna',
        '3->A' => 'cleanup_refseq_peptide',
        '4->A' => 'cleanup_uniprot',
        'A->1' => 'schedule_pre_parse'
      },
      -rc_name    => 'small'
    },
    {
      -logic_name => 'checksum',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::Checksum',
      -comment    => 'Adds all checksum files into a single file and loads it into the checksum_xref table.',
      -parameters => {
        base_path     => $self->o('base_path'),
        skip_download => $self->o('skip_download')
      },
      -rc_name    => 'normal'
    },
    {
      -logic_name => 'cleanup_refseq_dna',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::CleanupRefseqDna',
      -comment    => 'Removes irrelevant data from RefSeq_dna files and stores them in -clean_dir (only if -clean_files is set to 1).',
      -parameters      => {
        base_path    => $self->o('base_path'),
        clean_files  => $self->o('clean_files'),
        skip_download => $self->o('skip_download'),
        clean_dir    => $self->o('clean_dir')
      },
      -rc_name    => 'small'
    },
    {
      -logic_name => 'cleanup_refseq_peptide',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::CleanupRefseqPeptide',
      -comment    => 'Removes irrelevant data from RefSeq_peptide files and stores them in -clean_dir (only if -clean_files is set to 1).',
      -parameters      => {
        base_path    => $self->o('base_path'),
        clean_files  => $self->o('clean_files'),
        skip_download => $self->o('skip_download'),
        clean_dir    => $self->o('clean_dir')
      },
      -rc_name    => 'small'
    },
    {
      -logic_name => 'cleanup_uniprot',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::CleanupUniprot',
      -comment    => 'Removes irrelevant data from Uniprot/SWISSPROT and Uniprot/SPTREMBL files and stores them in -clean_dir (only if -clean_files is set to 1).',
      -parameters      => {
        base_path    => $self->o('base_path'),
        clean_files  => $self->o('clean_files'),
	skip_download => $self->o('skip_download'),
        clean_dir    => $self->o('clean_dir')
      },
      -rc_name    => 'small'
    },
    {
      -logic_name => 'schedule_pre_parse',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::SchedulePreParse',
      -comment    => 'Schedule pre parsing of data for multi species sources',
      -parameters      => {
	source_url    => $self->o('source_url'),
	release       => $self->o('release'),
	sql_dir       => $self->o('sql_dir'),
	source_xref   => $self->o('source_xref'),
	skip_preparse => $self->o('skip_preparse'),
      },
      -flow_into  => {
        '2' => 'pre_parse_source',
        '3' => 'pre_parse_source_dependent',
	'4' => 'pre_parse_source_tertiary',
	'-1' => 'notify_by_email'
      },
      -rc_name    => 'small'
    },
    {
      -logic_name => 'pre_parse_source',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::PreParse',
      -comment    => 'Store data for faster species parsing',
      -rc_name    => '2GB',
      -hive_capacity => 100,
      -can_be_empty => 1,
    },
    {
      -logic_name => 'pre_parse_source_dependent',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::PreParse',
      -comment    => 'Store data for faster species parsing',
      -rc_name    => '2GB',
      -hive_capacity => 100,
      -can_be_empty => 1,
      -wait_for => 'pre_parse_source'
    },
    {
      -logic_name => 'pre_parse_source_tertiary',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::PreParse',
      -comment    => 'Store data for faster species parsing',
      -rc_name    => '2GB',
      -hive_capacity => 100,
      -can_be_empty => 1,
      -wait_for => 'pre_parse_source_dependent',
    },
    {
      -logic_name => 'notify_by_email',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::EmailNotification',
      -comment    => 'Sends an email to the initializing user with a notification that the pipeline has done running and some useful information.',
      -parameters => {
        email   => $self->o('email'),
        subject => 'Xref Download finished',
	base_path => $self->o('base_path'),
        clean_files => $self->o('clean_files')
      },
      -wait_for => 'pre_parse_source_tertiary',
      -rc_name    => 'small'
    }
  ];
}

sub resource_classes {
  my ($self) = @_;

  return {
    %{$self->SUPER::resource_classes},
    'small'  => { 'LSF' => '-q production -M 200 -R "rusage[mem=200]"' }, # Change 'production' to 'production-rh74' if running on noah
    'normal' => { 'LSF' => '-q production -M 1000 -R "rusage[mem=1000]"' }
  };
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    'pipeline_part' => 'download'
  };
}

1;
