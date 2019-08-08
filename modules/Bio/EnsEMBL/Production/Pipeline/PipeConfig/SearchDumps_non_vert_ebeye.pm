=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::RDF::Pipeline::PipeConfig::SearchDumps_non_vert_ebeye

=head1 DESCRIPTION

Simple pipeline to dump json for EBEYE search for all core species. Need at least 100 GB of scratch space.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::SearchDumps_non_vert_ebeye;
use strict;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
#use parent 'Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf';
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');
# use base ('Bio::EnsEMBL::Hive::PipeConfig::Base_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;

use Data::Dumper;

sub default_options {
  my $self = shift;
  return {
      %{$self->SUPER::default_options()},
      species         => [],
      division        => [],
      antispecies     => [],
      run_all         => 0, #always run every species
      use_pan_compara => 0,
      variant_length  => 1000000,
      probe_length    => 100000,
      dump_variant    => 0,
      release         => software_version(),
      eg_release      => $self->o('eg_release')
  };
}

# sub process_options {
#     warn Dumper(">>>>>>> In process_options");
#     return;
# }

sub pipeline_wide_parameters {
  my $self = shift;
  return { %{$self->SUPER::pipeline_wide_parameters()},
      base_path => $self->o('base_path') };
}

sub pipeline_analyses {
  my $self = shift;
  my @variant_analyses = $self->o('dump_variant') == 1 ? [ 'VariantDumpFactory' ] : [];

  return [
      {
          -logic_name => 'SpeciesFactory',
          -module     =>
              'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
          -input_ids  => [ {} ], # required for automatic seeding
          -parameters => { species => $self->o('species'),
              antispecies          => $self->o('antispecies'),
              division             => $self->o('division'),
              run_all              => $self->o('run_all') },
          -rc_name    => '4g',
          -flow_into  => {
              '2->A' => [ 'DumpGenomeJson' ],
              'A->1' => [ 'WrapGenomeEBeye' ]
          }
      },
      {
          -logic_name => 'WrapGenomeEBeye',
          -module     =>
              'Bio::EnsEMBL::Production::Pipeline::Search::WrapGenomeEBeye',
          -rc_name    => '1g',
          -parameters =>
              {
                  division => $self->o('division'),
                  release  => $self->o('eg_release'),
              },
          #-flow_into  => 'CompressXML'
      },
      {
          -logic_name    => 'DumpGenomeJson',
          -module        =>
              'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenomeJson',
          -parameters    => {},
          -analysis_capacity => 10,
          -rc_name       => '1g',
          -flow_into     => {
              2 => [ 'DumpGenesJson' ],
              7 => [ 'DumpGenesJson' ],
              4 => @variant_analyses
          }
      },
      {
          -logic_name => 'ValidateXMLFileEBeye',
          -module     =>
              'Bio::EnsEMBL::Production::Pipeline::Search::ValidateXMLFileEBeye',
          -rc_name    => '1g',
          -parameters =>
              {
                  division => $self->o('division'),
                  release  => $self->o('eg_release'),
              },
          -flow_into  =>
              {
                  1 => [ 'CompressEBeyeXMLFile' ],
                  2 => [ '?accu_name=genome_files&accu_address={species}&accu_input_variable=genome_valid_file' ]
              },
      },
      {
          -logic_name        => 'CompressEBeyeXMLFile',
          -module            =>
              'Bio::EnsEMBL::Production::Pipeline::Search::CompressEBeyeXMLFile',
          -parameters        =>
              {
                  division => $self->o('division'),
                  release  => $self->o('eg_release'),
              },
          -analysis_capacity => 4,
      },
      {
          -logic_name    => 'DumpGenesJson',
          -module        =>
              'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenesJson',
          -parameters    => {
              use_pan_compara => $self->o('use_pan_compara')
          },
          -analysis_capacity => 10,
          -rc_name       => '16g',
          -flow_into     => {
              1 => [
                  'ReformatGenomeEBeye'
              ]
          }
      },
      {
          -logic_name => 'VariantDumpFactory',
          -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
          -parameters => {
              type   => 'variation',
              table  => 'variation',
              column => 'variation_id',
              length => $self->o('variant_length') },
          -rc_name    => '1g',
          -flow_into  =>
              {
                  '2->A' => 'DumpVariantJson',
                  'A->1' => 'VariantDumpMerge'
              }
      },
      {
          -logic_name    => 'DumpVariantJson',
          -analysis_capacity => 10,
          -module        =>
              'Bio::EnsEMBL::Production::Pipeline::Search::DumpVariantJson',
          -rc_name       => '16g',
          -flow_into     => {
              2 => [
                  '?accu_name=dump_file&accu_address=[]',
                  '?accu_name=species'
              ],

          }
      },
      {
          -logic_name => 'VariantDumpMerge',
          -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpMerge',
          -parameters => { file_type => 'variants' },
          -rc_name    => '1g',
          -flow_into  =>
              {
                  1 => [
                      'ReformatVariantsEBeye',
                  ]
              }
      },
      {
          -logic_name => 'ReformatGenomeEBeye',
          -module     =>
              'Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeEBeye',
          -rc_name    => '1g',
          -flow_into  => 'ValidateXMLFileEBeye'
      },
      {
          -logic_name => 'ReformatVariantsEBeye',
          -module     =>
              'Bio::EnsEMBL::Production::Pipeline::Search::ReformatVariantsEBeye',
          -rc_name    => '1g',
          -flow_into  => {}
      }
  ];
} ## end sub pipeline_analyses

sub beekeeper_extra_cmdline_options {
  my $self = shift;
  return "-reg_conf " . $self->o("registry");
}

sub resource_classes {
  my $self = shift;
  return {
      '32g' => { LSF => '-q production-rh74 -M 32000 -R "rusage[mem=32000]"' },
      '16g' => { LSF => '-q production-rh74 -M 16000 -R "rusage[mem=16000]"' },
      '8g'  => { LSF => '-q production-rh74 -M 16000 -R "rusage[mem=8000]"' },
      '4g'  => { LSF => '-q production-rh74 -M 4000 -R "rusage[mem=4000]"' },
      '1g'  => { LSF => '-q production-rh74 -M 1000 -R "rusage[mem=1000]"' } };
}

1;
