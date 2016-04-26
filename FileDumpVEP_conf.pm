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

Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpVEP_conf

=head1 DESCRIPTION

Dump and check VEP files.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpVEP_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::FileDump_conf');

use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'file_dump_vep_'.$self->o('cache_version'),

    ensembl_dir   => $self->o('ensembl_cvs_root_dir'),
    perl_lib      => $self->o('ensembl_dir').'/ensembl-variation/modules',

    vep_script    => catdir(
                       $self->o('ensembl_dir'),
                       'ensembl-tools/scripts/variant_effect_predictor',
                       'variant_effect_predictor.pl'),

    vep_params    => ' --build all'.
                     ' --db_version '    . $self->o('ensembl_release').
                     ' --cache_version ' . $self->o('cache_version').
                     ' --registry '      . $self->o('registry'),

    vep_hc_script => catdir(
                       $self->o('ensembl_dir'),
                       'ensembl-variation/scripts/misc',
                       'healthcheck_vep_caches.pl'),

    vep_hc_params => ' --version '       . $self->o('ensembl_release').
                     ' --cache_version ' . $self->o('cache_version').
                     ' --random 0.01'.
                     ' --no_fasta 1'.
                     ' --max_vars 100',   
    };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -input_ids         => [ {} ],
      -parameters        => {
                              species         => $self->o('species'),
                              antispecies     => $self->o('antispecies'),
                              division        => $self->o('division'),
                              run_all         => $self->o('run_all'),
                              meta_filters    => $self->o('meta_filters'),
                              chromosome_flow => 0,
                              variation_flow  => 0,
                            },
      -max_retry_count   => 1,
      -flow_into         => {
                              '2' => ['vep'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'vep',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::VEPDumper',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              perl_lib   => $self->o('perl_lib'),
                              vep_script => $self->o('vep_script'),
                              vep_params => $self->o('vep_params'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1' => ['ValidateVEP'],
                            },
    },

    {
      -logic_name        => 'ValidateVEP',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::ValidateVEP',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              vep_hc_script => $self->o('vep_hc_script'),
                              vep_hc_params => $self->o('vep_hc_params'),
                            },
      -rc_name           => 'normal',
    },
  ];
}

1;
