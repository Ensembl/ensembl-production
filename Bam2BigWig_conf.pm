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

package Bio::EnsEMBL::EGPipeline::PipeConfig::Bam2BigWig_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{ $self->SUPER::default_options() },

    pipeline_name => 'bam2bigwig_'.$self->o('ensembl_release'),

    species => [],
    antispecies => [],
    division => [],
    run_all => 0,
    meta_filters => {},

    bedtools_dir  => '/nfs/panda/ensemblgenomes/external/bedtools/bin',
    ucscutils_dir => '/nfs/panda/ensemblgenomes/external/ucsc_utils',
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

sub pipeline_analyses {
  my ($self) = @_;
  
  return
  [
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
      -batch_size        => 2,
      -max_retry_count   => 1,
      -parameters        => {
                              genome_dir => catdir($self->o('pipeline_dir'), '#species#'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['SequenceLengths'],
    },

    {
      -logic_name        => 'SequenceLengths',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::SequenceLengths',
      -analysis_capacity => 5,
      -batch_size        => 2,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              fasta_file  => '#genome_file#',
                              length_file => '#genome_file#'.'.lengths.txt',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['CreateBigWig'],
    },

    {
      -logic_name        => 'CreateBigWig',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::CreateBigWig',
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              bedtools_dir    => $self->o('bedtools_dir'),
                              ucscutils_dir   => $self->o('ucscutils_dir'),
                              length_file     => '#genome_file#'.'.lengths.txt',
                              merged_bam_file => $self->o('bam_file'),
                              clean_up        => 1,
                            },
      -rc_name           => 'normal',
    },

  ];
}

1;
