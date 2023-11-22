=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::FileDumpVEP_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::VEP::Pipeline::DumpVEP::DumpVEP_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use File::Spec::Functions qw(catdir);

sub default_options {
	my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    # Override defaults in variation conf
    hive_force_init => 0,

    # Need to reinstate these from EnsemblGeneric_conf
    # (the vep conf overrides them with values we don't want)
    ensembl_release => Bio::EnsEMBL::ApiVersion::software_version(), 
    pipeline_name   => $self->default_pipeline_name().'_'.$self->o('rel_with_suffix'),

    # The sub_dir is there to allow for this pipeline to match
    # the current main site structure, but also give flexibility
    # for RR structure, if/when that becomes necessary.
    target_dir   => catdir($self->o('dump_dir'), $self->o('sub_dir')),
    pipeline_dir => catdir($self->o('vep_dir'), $self->o('sub_dir')),
	};
}

sub pipeline_create_commands {
  my ($self) = @_;
  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('target_dir'),
  ];
}

sub pipeline_analyses {
  my ($self) = @_;

  my $analyses = $self->SUPER::pipeline_analyses;

  delete $$analyses[0]{'-input_ids'};

  my $local_analyses = [
    {
      -logic_name        => 'FileDump',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 1,
      -analysis_capacity => 1,
      -input_ids         => [ {} ],
      -parameters        => {},
      -flow_into         => {
                              '1->A' => ['species_factory'],
                              'A->1' => ['DivisionFactory'],
                            }
    },
    {
      -logic_name        => 'DivisionFactory',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -max_retry_count   => 1,
      -analysis_capacity => 1,
      -parameters        => {
                              inputlist => $self->o('division'),
                              column_names => ['division_name'],
                            },
      -flow_into         => {
                              2 =>['Copy'],
                            },
    },
    {
      -logic_name        => 'Copy',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -analysis_capacity => 1,
      -parameters        => {
                              cmd =>
                                'mkdir -p #target_dir#/#division_name#/variation ;'.
                                'rsync -avW #pipeline_dir#/#division_name#/dumps/production/ #target_dir#/#division_name#/variation/vep ;'.
                                'rsync -avW #pipeline_dir#/#division_name#/dumps/web/ #target_dir#/#division_name#/variation/indexed_vep_cache ;',
                              ,
                              target_dir => $self->o('target_dir'),
                            },
    },
  ];
  unshift @$analyses, @$local_analyses;

  return $analyses;
}

1;
