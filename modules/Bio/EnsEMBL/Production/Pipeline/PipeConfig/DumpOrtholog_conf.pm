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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

sub default_options {
	my ($self) = @_;

	return {
		%{ $self->SUPER::default_options() },

		compara => undef,
    release => $self->o('ensembl_release'),

		# Cleanup projection directory before running the pipeline
		cleanup_dir => 0,

		# Ortholog parameters
		method_link_type => 'ENSEMBL_ORTHOLOGUES',
		perc_id  => '30',
		perc_cov => '66',

    # Flag controling the use of the is_tree_compliant flag from the homology table of the Compara database
    # If this flag is on (=1) then the pipeline will exclude all homologies where is_tree_compliant=0 in the homology table of the Compara db
    # This flag should be enabled for EG and disable for e! species.
    is_tree_compliant => 0,

		# hive_capacity values for analysis
		getOrthologs_capacity => '50',
	};
}

sub pipeline_create_commands {
	my ($self) = @_;

	return [
		@{ $self->SUPER::pipeline_create_commands },
		'mkdir -p ' . $self->o('output_dir'),
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

sub pipeline_wide_parameters {
	my ($self) = @_;

	return {
		%{ $self->SUPER::pipeline_wide_parameters },
		perc_id  => $self->o('perc_id'),
		perc_cov => $self->o('perc_cov'),
  };
}

sub pipeline_analyses {
	my ($self) = @_;

	return [
		{
      -logic_name => 'SourceFactory',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::SourceFactory',
      -input_ids  => [ {} ],
      -parameters => {
                      species_config => $self->o('species_config'),
                      compara        => $self->o('compara'),
                      output_dir     => $self->o('output_dir'),
                      cleanup_dir    => $self->o('cleanup_dir')
                     },
      -flow_into  => {
                      '2->A' => ['SpeciesFactory'],
                      'A->1' => ['SpeciesFactoryAll'],
                     },
    },
    {
      -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -max_retry_count => 1,
      -flow_into       => {
                            '2' => ['GetOrthologs'],
                          },
    },
    {
      -logic_name      => 'SpeciesFactoryAll',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -max_retry_count => 1,
      -flow_into       => ['SpeciesNoOrthologs'],
    },
		{
      -logic_name => 'SpeciesNoOrthologs',
		  -module     => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::SpeciesNoOrthologs',
		  -parameters => {
                      release => $self->o('release'),
                     },
		   -rc_name   => '4GB',
			 -flow_into => ['RunCreateReleaseFile'],
    },
		{
      -logic_name    => 'GetOrthologs',
		  -module        => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile',
		  -parameters    => {
                          method_link_type  => $self->o('method_link_type'),
                          is_tree_compliant => $self->o('is_tree_compliant'),
                        },
		  -rc_name       => '4GB',
		  -hive_capacity => $self->o('getOrthologs_capacity'),
		  -flow_into     => { '-1' => 'GetOrthologs_16GB' },
    },
		{
      -logic_name    => 'GetOrthologs_16GB',
		  -module        => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile',
		  -parameters    => {
                          method_link_type => $self->o('method_link_type'),
                          is_tree_compliant => $self->o('is_tree_compliant'),
                        },
		  -rc_name       => '16GB',
		  -hive_capacity => $self->o('getOrthologs_capacity'),
		  -flow_into     => { '-1' => 'GetOrthologs_32GB' },
    },
		{
      -logic_name    => 'GetOrthologs_32GB',
		  -module        => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile',
		  -parameters    => {
                          method_link_type => $self->o('method_link_type'),
                          is_tree_compliant => $self->o('is_tree_compliant'),
                        },
		  -rc_name       => '32GB',
		  -hive_capacity => $self->o('getOrthologs_capacity'),
    },
		{
      -logic_name => 'RunCreateReleaseFile',
		  -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::RunCreateReleaseFile',
		  -parameters => { 							
                      release => $self->o('release'),
                     },
		}
	];
}

1;
