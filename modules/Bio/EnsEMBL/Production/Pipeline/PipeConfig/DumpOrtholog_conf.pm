
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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf;

use strict;
use warnings;
use Bio::EnsEMBL::Hive::Version 2.3;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub default_options {
	my ($self) = @_;

	return {
		# inherit other stuff from the base class
		%{ $self->SUPER::default_options() },

		'registry'         => '',
		'method_link_type' => 'ENSEMBL_ORTHOLOGUES',
		'compara' => undef,
		'release' => software_version(),
		# Cleanup projection directory before running the pipeline
		'cleanup_dir' => 0,

        # Flag controling the use of the is_tree_compliant flag from the homology table of the Compara database
	    # If this flag is on (=1) then the pipeline will exclude all homologies where is_tree_compliant=0 in the homology table of the Compara db
        # This flag should be enabled for EG and disable for e! species.

        'is_tree_compliant' => '0',

		# hive_capacity values for analysis
		'getOrthologs_capacity' => '50',


	};
} ## end sub default_options

sub pipeline_create_commands {
	my ($self) = @_;
	return [
		# inheriting database and hive tables' creation
		@{ $self->SUPER::pipeline_create_commands },
		'mkdir -p ' . $self->o('output_dir'), ];
}

# Ensures output parameters gets propagated implicitly
sub hive_meta_table {
	my ($self) = @_;

	return { %{ $self->SUPER::hive_meta_table }, 'hive_use_param_stack' => 1, };
}

# override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
	my ($self) = @_;
	return ' -reg_conf ' . $self->o('registry'),;
}

# these parameter values are visible to all analyses,
# can be overridden by parameters{} and input_id{}
sub pipeline_wide_parameters {
	my ($self) = @_;
	return {
		%{ $self->SUPER::pipeline_wide_parameters }
		,    # here we inherit anything from the base class
		'perc_id'  => $self->o('perc_id'),
		'perc_cov' => $self->o('perc_cov'), };
}

sub pipeline_analyses {
	my ($self) = @_;

	return [

		{  -logic_name => 'SourceFactory',
		   -input_ids  => [ {} ],
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Ortholog::SourceFactory',
		   -parameters => { 'species_config' => $self->o('species_config'),
		   	 'compara' => $self->o('compara'),
				    'output_dir'       => $self->o('output_dir'),
						'cleanup_dir'     => $self->o('cleanup_dir')
		   	 },
		    -flow_into  => { '2->A'              => ['SpeciesFactory'],
				    'A->1' => [ 'SpeciesFactoryAll'  ],
						},
		    -rc_name    => 'default',
		 },

		 {  -logic_name      => 'SpeciesFactory',
             -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
             -max_retry_count => 1,
             -flow_into       => {
                                  '2' => ['GetOrthologs'],
                                 },
             -rc_name         => 'default',
          },
			{  -logic_name      => 'SpeciesFactoryAll',
             -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
             -max_retry_count => 1,
             -flow_into       => {
                                  '1' => ['SpeciesNoOrthologs'],
                                 },
             -rc_name         => 'default',
          },

		{  -logic_name => 'SpeciesNoOrthologs',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::SpeciesNoOrthologs',
		   -parameters => {
			      'release' => $self->o('release'),
       },
		   -batch_size    => 1,
			 -flow_into       => {
				 '1' => ['RunCreateReleaseFile'],
			 } ,
		   -rc_name       => 'default',},

		{  -logic_name => 'GetOrthologs',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile',
		   -parameters => { 'is_tree_compliant' => $self->o('is_tree_compliant'),
							'method_link_type' => $self->o('method_link_type'),
		   },
		   -batch_size    => 1,
		   -rc_name       => 'default',
		   -hive_capacity => $self->o('getOrthologs_capacity'),
		   -flow_into     => { '-1' => 'GetOrthologs_16GB', }, },

		{  -logic_name => 'GetOrthologs_16GB',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile',
		   -parameters => {
				   'method_link_type' => $self->o('method_link_type'),
		   },
		   -batch_size    => 1,
		   -rc_name       => '16Gb_mem',
		   -hive_capacity => $self->o('getOrthologs_capacity'),
		   -flow_into     => { '-1' => 'GetOrthologs_32GB', }, },

		{  -logic_name => 'GetOrthologs_32GB',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile',
		   -parameters => {
				   'method_link_type' => $self->o('method_link_type'),
		   },
		   -batch_size    => 1,
		   -rc_name       => '32Gb_mem',
		   -hive_capacity => $self->o('getOrthologs_capacity'), },
		   
		{  -logic_name => 'RunCreateReleaseFile',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Common::RunCreateReleaseFile',
		   -parameters => { 							
			'release' => $self->o('release'),
		   },
		   -batch_size    => 1,
		   -rc_name       => 'default'
		}
	];
} ## end sub pipeline_analyses

sub resource_classes {
	my ($self) = @_;
    return {
      'default' =>
        { 'LSF' => '-q production-rh74 -M  4000 -R "rusage[mem=4000]"' },
      'normal' =>
        { 'LSF' => '-q production-rh74 -M  4000 -R "rusage[mem=4000]"' },
      '2Gb_mem' =>
        { 'LSF' => '-q production-rh74 -M  2000 -R "rusage[mem=2000]"' },
      '4Gb_mem' =>
        { 'LSF' => '-q production-rh74 -M  4000 -R "rusage[mem=4000]"' },
      '8Gb_mem' =>
        { 'LSF' => '-q production-rh74 -M  8000 -R "rusage[mem=8000]"' },
      '12Gb_mem' =>
        { 'LSF' => '-q production-rh74 -M 12000 -R "rusage[mem=12000]"' },
      '16Gb_mem' =>
        { 'LSF' => '-q production-rh74 -M 16000 -R "rusage[mem=16000]"' },
      '24Gb_mem' =>
        { 'LSF' => '-q production-rh74 -M 24000 -R "rusage[mem=24000]"' },
      '32Gb_mem' =>
        { 'LSF' => '-q production-rh74 -M 32000 -R "rusage[mem=32000]"' },
      '2Gb_mem_4Gb_tmp' => {
        'LSF' =>
          '-q production-rh74 -M  2000 -R "rusage[mem=2000,tmp=4000]"'
      },
      '4Gb_mem_4Gb_tmp' => {
        'LSF' =>
          '-q production-rh74 -M  4000 -R "rusage[mem=4000,tmp=4000]"'
      },
      '8Gb_mem_4Gb_tmp' => {
        'LSF' =>
          '-q production-rh74 -M  8000 -R "rusage[mem=8000,tmp=4000]"'
      },
      '12Gb_mem_4Gb_tmp' => {
        'LSF' =>
          '-q production-rh74 -M 12000 -R "rusage[mem=12000,tmp=4000]"'
      },
      '16Gb_mem_4Gb_tmp' => {
        'LSF' =>
          '-q production-rh74 -M 16000 -R "rusage[mem=16000,tmp=4000]"'
      },
      '16Gb_mem_16Gb_tmp' => {
        'LSF' =>
          '-q production-rh74 -M 16000 -R "rusage[mem=16000,tmp=16000]"'
      },
      '24Gb_mem_4Gb_tmp' => {
        'LSF' =>
          '-q production-rh74 -M 24000 -R "rusage[mem=24000,tmp=4000]"'
      },
      '32Gb_mem_4Gb_tmp' => {
        'LSF' =>
          '-q production-rh74 -M 32000 -R "rusage[mem=32000,tmp=4000]"'
      },
    };
} ## end sub resource_classes

1;
