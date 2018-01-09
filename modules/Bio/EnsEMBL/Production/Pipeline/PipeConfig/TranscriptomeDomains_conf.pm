=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::TranscriptomeDomains_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::ProteinFeatures_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    
    pipeline_name => 'transcriptome_domains',
    
    transcriptome_dir  => undef,
    transcriptome_file => [],
    
    results_dir => $self->o('pipeline_dir'),
    
    interpro_applications =>
    [
      'CDD',
      'Gene3D',
      'Hamap',
      'PANTHER',
      'Pfam',
      'PIRSF',
      'PRINTS',
      'ProDom',
      'ProSitePatterns',
      'ProSiteProfiles',
      'SFLD',
      'SMART',
      'SUPERFAMILY',
      'TIGRFAM',
    ],
    
  };
}

sub beekeeper_extra_cmdline_options {
  my ($self) = @_;
  
  return undef;
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('results_dir'),
  ];
}

sub pipeline_analyses {
  my $self = shift @_;
  
  return [
    {
      -logic_name        => 'ProcessTranscriptome',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::ProcessTranscriptome',
      -max_retry_count   => 1,
      -input_ids         => [ {} ],
      -parameters        => {
                              transcriptome_dir  => $self->o('transcriptome_dir'),
                              transcriptome_file => $self->o('transcriptome_file'),
                              pipeline_dir       => $self->o('pipeline_dir'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['FastaSplit'],
                              'A->2' => ['MergeResults'],
                            },
      -meadow_type       => 'LOCAL',
    },
    
    {
      -logic_name        => 'FastaSplit',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::FastaSplit',
      -max_retry_count   => 1,
      -parameters        => {
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['InterProScan'],
                            },
      -meadow_type       => 'LOCAL',
    },
    
    {
      -logic_name        => 'InterProScan',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
      -analysis_capacity => 100,
      -max_retry_count   => 1,
      -parameters        =>
                            {
                              input_file                => '#split_file#',
                              seq_type                  => 'n',
                              run_mode                  => 'local',
                              interproscan_exe          => $self->o('interproscan_exe'),
                              interproscan_applications => $self->o('interpro_applications'),
                            },
      -rc_name           => '4GB_4CPU',
      -flow_into         => {
                              1 => [
                                    '?accu_name=outfile_xml&accu_address=[]',
                                    '?accu_name=outfile_tsv&accu_address=[]',
                                   ],
                            },
    },
    
    {
      -logic_name        => 'MergeResults',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::MergeResults',
      -max_retry_count   => 1,
      -parameters        => {
                              results_dir    => $self->o('results_dir'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['GenerateSolr'],
    },
    
    {
      -logic_name        => 'GenerateSolr',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::GenerateSolr',
      -max_retry_count   => 1,
      -parameters        => {
                              interproscan_version => $self->o('interproscan_version'),
                              pathway_sources      => $self->o('pathway_sources'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['EmailReport'],
    },
    
    {
      -logic_name        => 'EmailReport',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::EmailTranscriptomeReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email   => $self->o('email'),
                              subject => 'InterProScan transcriptome annotation',
                            },
      -rc_name           => 'normal',
    },
    
  ];
}

1;
