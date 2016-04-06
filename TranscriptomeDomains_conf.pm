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

package Bio::EnsEMBL::EGPipeline::PipeConfig::TranscriptomeDomains_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'transcriptome_domains_'.$self->o('ensembl_release'),
    
    transcriptome_file => [],
    
    pipeline_dir => "/nfs/nobackup/ensemblgenomes/".$self->o('ENV', 'USER')."/transcriptome_domains",
    results_dir  => "/nfs/panda/ensemblgenomes/vectorbase/transcriptomes/domains",
    
    # Parameters for dumping and splitting Fasta files
    max_seqs_per_file       => 100,
    max_seq_length_per_file => undef,
    max_files_per_directory => 100,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),
    
    # InterPro settings
    interproscan_dir      => '/nfs/panda/ensemblgenomes/development/InterProScan',
    interproscan_version  => 'interproscan-5.17-56.0',
    interproscan_exe      => catdir(
                               $self->o('interproscan_dir'),
                               $self->o('interproscan_version'),
                               'interproscan.sh'
                             ),
    interpro_applications =>
    [
      'Gene3D',
      'Hamap',
      'PANTHER',
      'Pfam',
      'PIRSF',
      'PRINTS',
      'ProDom',
      'ProSitePatterns',
      'ProSiteProfiles',
      'SMART',
      'SUPERFAMILY',
      'TIGRFAM',
    ],
    
    # Pathway data sources
    pathway_sources =>
    [
      'KEGG',
      'UniPathway',
    ],
    
  };
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
    'mkdir -p '.$self->o('results_dir'),
  ];
}

sub pipeline_analyses {
  my $self = shift @_;
  
  return [
    {
      -logic_name        => 'ProcessTranscriptome',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::ProcessTranscriptome',
      -max_retry_count   => 1,
      -input_ids         => [ {} ],
      -parameters        => {
                              transcriptome_file => $self->o('transcriptome_file'),
                              pipeline_dir       => $self->o('pipeline_dir'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['FastaSplit'],
                              'A->2' => ['MergeResults'],
                            },
      -meadow            => 'LOCAL',
    },
    
    {
      -logic_name        => 'FastaSplit',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
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
      -meadow            => 'LOCAL',
    },
    
    {
      -logic_name        => 'InterProScan',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::InterProScan',
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
                                    ':////accu?outfile_xml=[]',
                                    ':////accu?outfile_tsv=[]',
                                   ],
                            },
    },
    
    {
      -logic_name        => 'MergeResults',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::MergeResults',
      -max_retry_count   => 1,
      -parameters        => {
                              results_dir    => $self->o('results_dir'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['GenerateSolr'],
    },
    
    {
      -logic_name        => 'GenerateSolr',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::GenerateSolr',
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
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::EmailTranscriptomeReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email   => $self->o('email'),
                              subject => 'InterProScan transcriptome annotation',
                            },
      -rc_name           => 'normal',
    },
    
  ];
}

sub resource_classes {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::resource_classes},
    '4GB_4CPU' => {'LSF' => '-q production-rh6 -n 4 -M 4000 -R "rusage[mem=4000,tmp=4000] span[hosts=1]"'},
  }
}

1;
