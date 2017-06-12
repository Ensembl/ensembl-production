
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::RDF::Pipeline::PipeConfig::RDF_conf

=head1 DESCRIPTION

Simple pipeline to dump RDF for all core species. Needs a LOD mapping file to function,
and at least 100 GB of scratch space.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::SearchDumps_conf;
use strict;
use parent 'Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf';
use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
	my $self = shift;
	return {
		%{ $self->SUPER::default_options() },
		species        => [],
		division       => [],
		antispecies    => [],
		run_all        => 0,         #always run every species
		variant_length => 1000000,
		probe_length   => 100000, };
}

sub pipeline_wide_parameters {
	my $self = shift;
	return { %{ $self->SUPER::pipeline_wide_parameters() },
			 base_path => $self->o('base_path') };
}

sub pipeline_analyses {
	my $self = shift;
	return [ {
		   -logic_name => 'SpeciesFactory',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::BaseSpeciesFactory',
		   -input_ids => [ {} ],    # required for automatic seeding
		   -parameters => { species     => $self->o('species'),
							antispecies => $self->o('antispecies'),
							division    => $self->o('division'),
							run_all     => $self->o('run_all') },
		   -rc_name   => '1g',
		   -flow_into => { 2      => ['DumpGenomeJson'],
						   '4->A' => ['VariantDumpFactory'],
						   'A->4' => ['VariantDumpMerge'],
						   '6->B' => ['ProbeDumpFactory'],
						   'B->6' => ['ProbeDumpMerge'],
						   6      => 'DumpRegulationJson' } }, {
		   -logic_name => 'DumpGenomeJson',
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenomeJson',
		   -parameters    => {},
		   -hive_capacity => 8,
		   -rc_name       => '32g',
		   -flow_into     => {} },

		{  -logic_name => 'DumpRegulationJson',
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::DumpRegulationJson',
		   -parameters    => {},
		   -hive_capacity => 8,
		   -rc_name       => '8g',
		   -flow_into     => {} },

		{  -logic_name => 'VariantDumpFactory',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
		   -parameters => { type   => 'variation',
							table  => 'variation',
							column => 'variation_id',
							length => $self->o('variant_length') },
		   -rc_name   => '1g',
		   -flow_into => { 2 => 'DumpVariantJson', } },

		{  -logic_name    => 'DumpVariantJson',
		   -hive_capacity => 8,
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::DumpVariantJson',
		   -rc_name   => '32g',
		   -flow_into => {
			   1 => [ '?accu_name=dump_file&accu_address=[]',
					  '?accu_name=species' ],

		   } },

		{  -logic_name => 'VariantDumpMerge',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpMerge',
		   -parameters => { type => 'variants'
		   },

		   -rc_name   => '1g',
		   -flow_into => {} },

		{
			-logic_name => 'ProbeDumpFactory',
			  -module =>
			  'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
			  -parameters => { type   => 'funcgen',
							   table  => 'probe',
							   column => 'probe_id',
							   length => $self->o('variant_length') },
			  -rc_name   => '1g',
			  -flow_into => { 2 => 'DumpProbeJson', }
		},

		{  -logic_name    => 'DumpProbeJson',
		   -hive_capacity => 8,
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::DumpProbesJson',
		   -rc_name   => '32g',
		   -flow_into => {
			   1 => [ '?accu_name=probes_dump_file&accu_address=[]',
					  '?accu_name=probesets_dump_file&accu_address=[]',
					  '?accu_name=species' ],

		   } },

		{  -logic_name => 'ProbeDumpMerge',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpProbesMerge',
		   -rc_name    => '1g',
		   -flow_into  => {} }

	];
} ## end sub pipeline_analyses

sub beekeeper_extra_cmdline_options {
	my $self = shift;
	return "-reg_conf " . $self->o("registry");
}

sub resource_classes {
	my $self = shift;
	return {
		'32g' => { LSF => '-q production-rh7 -M 32000 -R "rusage[mem=32000]"' },
		'16g' => { LSF => '-q production-rh7 -M 16000 -R "rusage[mem=16000]"' },
		'8g'  => { LSF => '-q production-rh7 -M 16000 -R "rusage[mem=8000]"' },
		'4g'  => { LSF => '-q production-rh7 -M 4000 -R "rusage[mem=4000]"' },
		'1g'  => { LSF => '-q production-rh7 -M 1000 -R "rusage[mem=1000]"' } };
}

1;
