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

package Bio::EnsEMBL::EGPipeline::PipeConfig::RepeatModeler_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'repeat_modeler',

    species => [],
    antispecies => [],
    division => [],
    run_all => 0,
    meta_filters => {},

    # Parameters for dumping and splitting Fasta DNA files
    max_seq_length          => 25000000,
    max_seq_length_per_file => $self->o('max_seq_length'),
    max_seqs_per_file       => undef,
    max_files_per_directory => 50,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),
    
    # Program paths
    repeatmodeler_dir => '/nfs/panda/ensemblgenomes/external/RepeatModeler',
    builddatabase_exe => catdir($self->o('repeatmodeler_dir'), 'BuildDatabase'),
    repeatmodeler_exe => catdir($self->o('repeatmodeler_dir'), 'RepeatModeler'),
    
    # Blast engine can be wublast or ncbi
    blast_engine => 'ncbi',
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
    'mkdir -p '.$self->o('results_dir'),
  ];
}

sub pipeline_analyses {
  my ($self) = @_;

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
                              '2' => ['DumpGenome'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'DumpGenome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpGenome',
      -analysis_capacity => 5,
      -max_retry_count   => 1,
      -parameters        => {
                              genome_dir => catdir($self->o('results_dir'), '#species#'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1->A' => ['SplitDumpFiles'],
                              'A->1' => ['MergeResults'],
                            },
    },

    {
      -logic_name        => 'SplitDumpFiles',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -analysis_capacity => 5,
      -max_retry_count   => 0,
      -parameters        => {
                              fasta_file              => '#genome_file#',
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              unique_file_names       => 1,
                            },
      -rc_name           => '8Gb_mem',
      -flow_into         => ['BuildDatabase'],
    },

    {
      -logic_name        => 'BuildDatabase',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 25,
      -max_retry_count   => 0,
      -batch_size        => 25,
      -parameters        =>
      {
        cmd => 'cd '.$self->o('results_dir').'; '.
               'RM_DB=$(basename #split_file#); '.
               'mkdir $RM_DB; '.
               'cd $RM_DB; '.
               $self->o('builddatabase_exe').' -engine '.$self->o('blast_engine').' -name $RM_DB #split_file#',
      },
      -rc_name           => 'normal',
      -flow_into         => ['RepeatModeler'],
    },

    {
      -logic_name        => 'RepeatModeler',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 25,
      -max_retry_count   => 0,
      -parameters        =>
      {
        cmd => 'RM_DB=$(basename #split_file#); '.
               'cd '.$self->o('results_dir').'/$RM_DB; '.
               $self->o('repeatmodeler_exe').' -pa 9 -engine '.$self->o('blast_engine').' -database $RM_DB',
      },
      -rc_name           => '4Gb_mem_10_cores',
    },
    
    {
      -logic_name        => 'MergeResults',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 0,
      -parameters        =>
      {
        cmd => 'cat '.$self->o('results_dir').'/*/RM_*/consensi.fa.classified > '.$self->o('results_dir').'/#species#.rm.lib',
      },
      -rc_name           => 'normal',
    },
    
  ];
}

sub resource_classes {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::resource_classes},
    '4Gb_mem_10_cores' => {'LSF' => '-q production-rh6 -M 4000 -n 10 -R "span[hosts=1]" "rusage[mem=4000,tmp=4000]"'},
  }
}

1;
