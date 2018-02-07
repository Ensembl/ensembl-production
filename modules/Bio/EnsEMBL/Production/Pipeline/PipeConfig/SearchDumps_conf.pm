
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
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
		   -input_ids => [ {} ],    # required for automatic seeding
		   -parameters => { species     => $self->o('species'),
							antispecies => $self->o('antispecies'),
							division    => $self->o('division'),
							run_all     => $self->o('run_all') },
		   -rc_name   => '4g',
		   -flow_into => { 2 => ['DumpGenomeJson'], } }, {
		   -logic_name => 'DumpGenomeJson',
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenomeJson',
		   -parameters    => {},
		   -hive_capacity => 8,
		   -rc_name       => '1g',
		   -flow_into     => {
			   2 => ['DumpGenesJson'],
			   7 => ['DumpGenesJson'],
			   4 => [ 'VariantDumpFactory', 'StructuralVariantDumpFactory',
					  'DumpPhenotypesJson' ],
			   6 => [ 'DumpRegulationJson', 'ProbeDumpFactory' ]

		   } }, {
		   -logic_name => 'DumpGenesJson',
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenesJson',
		   -parameters    => {},
		   -hive_capacity => 8,
		   -rc_name       => '32g',
		   -flow_into     => {
					 1 => ['ReformatGenomeAdvancedSearch', 'ReformatGenomeSolr',
						   'ReformatGenomeEBeye' ] } }, {
		   -logic_name => 'DumpRegulationJson',
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::DumpRegulationJson',
		   -parameters    => {},
		   -hive_capacity => 8,
		   -rc_name       => '8g',
		   -flow_into     => { 2 => 'ReformatRegulationSolr' } },

		{  -logic_name => 'VariantDumpFactory',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
		   -parameters => { type   => 'variation',
							table  => 'variation',
							column => 'variation_id',
							length => $self->o('variant_length') },
		   -rc_name => '1g',
		   -flow_into =>
			 { '2->A' => 'DumpVariantJson', 'A->1' => 'VariantDumpMerge' } },

		{  -logic_name    => 'DumpVariantJson',
		   -hive_capacity => 8,
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::DumpVariantJson',
		   -rc_name   => '32g',
		   -flow_into => {
			   2 => [ '?accu_name=dump_file&accu_address=[]',
					  '?accu_name=species' ],

		   } },

		{  -logic_name => 'VariantDumpMerge',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpMerge',
		   -parameters => { file_type => 'variants' },
		   -rc_name    => '1g',
		   -flow_into =>
			 { 1 => [ 'ReformatVariantsSolr', 'ReformatGenomeEBeye', 'ReformatVariantsAdvancedSearch' ] } },

		{  -logic_name => 'StructuralVariantDumpFactory',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
		   -parameters => { type   => 'variation',
							table  => 'structural_variation',
							column => 'structural_variation_id',
							length => $self->o('variant_length') },
		   -rc_name   => '1g',
		   -flow_into => { '2->A' => 'DumpStructuralVariantJson',
						   'A->1' => 'StructuralVariantDumpMerge', } },

		{  -logic_name    => 'DumpStructuralVariantJson',
		   -hive_capacity => 8,
		   -module =>
'Bio::EnsEMBL::Production::Pipeline::Search::DumpStructuralVariantJson',
		   -rc_name   => '32g',
		   -flow_into => {
			   2 => [ '?accu_name=dump_file&accu_address=[]',
					  '?accu_name=species' ],

		   } },

		{  -logic_name => 'StructuralVariantDumpMerge',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpMerge',
		   -parameters => { file_type => 'structuralvariants' },
		   -rc_name    => '1g',
		   -flow_into => { 1 => 'ReformatStructuralVariantsSolr' } },

		{  -logic_name => 'DumpPhenotypesJson',
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::DumpPhenotypesJson',
		   -parameters    => {},
		   -hive_capacity => 8,
		   -rc_name       => '1g',
		   -flow_into     => { 2 => 'ReformatPhenotypesSolr' } }, {
		   -logic_name => 'ProbeDumpFactory',
		   -module => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
		   -parameters => { type   => 'funcgen',
							table  => 'probe',
							column => 'probe_id',
							length => $self->o('probe_length') },
		   -rc_name => '1g',
		   -flow_into =>
			 { '2->A' => 'DumpProbeJson', 'A->1' => 'ProbeDumpMerge' } },

		{  -logic_name    => 'DumpProbeJson',
		   -hive_capacity => 8,
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::DumpProbesJson',
		   -rc_name   => '32g',
		   -flow_into => {
			   2 => [ '?accu_name=probes_dump_file&accu_address=[]',
					  '?accu_name=probesets_dump_file&accu_address=[]',
					  '?accu_name=species' ],

		   } },

		{  -logic_name => 'ProbeDumpMerge',
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::DumpProbesMerge',
		   -rc_name => '1g',
		   -flow_into =>
			 { 2 => 'ReformatProbesSolr', 3 => 'ReformatProbeSetsSolr', } },

		{  -logic_name => 'ReformatGenomeAdvancedSearch',
		   -module =>
'Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeAdvancedSearch',
		   -rc_name   => '1g',
		   -flow_into => {} },
		   
		      {  -logic_name => 'ReformatVariantsAdvancedSearch',
       -module =>
'Bio::EnsEMBL::Production::Pipeline::Search::ReformatVariantsAdvancedSearch',
       -rc_name   => '1g',
       -flow_into => {} },
        {
		   -logic_name => 'ReformatGenomeSolr',
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeSolr',
		   -rc_name   => '1g',
		   -flow_into => {} }, {
		   -logic_name => 'ReformatGenomeEBeye',
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeEBeye',
		   -rc_name   => '1g',
		   -flow_into => {} }, {
		   -logic_name => 'ReformatVariantsSolr',
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatVariantsSolr',
		   -rc_name   => '1g',
		   -flow_into => {} }, {
		   -logic_name => 'ReformatVariantsEBeye',
		   -module =>
'Bio::EnsEMBL::Production::Pipeline::Search::ReformatVariantsEBeye',
		   -rc_name   => '1g',
		   -flow_into => {} }, {
		   -logic_name => 'ReformatStructuralVariantsSolr',
		   -module =>
'Bio::EnsEMBL::Production::Pipeline::Search::ReformatStructuralVariantsSolr',
		   -rc_name   => '1g',
		   -flow_into => {} }, {
		   -logic_name => 'ReformatPhenotypesSolr',
		   -module =>
'Bio::EnsEMBL::Production::Pipeline::Search::ReformatPhenotypesSolr',
		   -rc_name   => '1g',
		   -flow_into => {} }, {
		   -logic_name => 'ReformatProbesSolr',
		   -module =>
			 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatProbesSolr',
		   -rc_name   => '1g',
		   -flow_into => {} },
		, {-logic_name => 'ReformatProbeSetsSolr',
		   -module =>
'Bio::EnsEMBL::Production::Pipeline::Search::ReformatProbeSetsSolr',
		   -rc_name   => '1g',
		   -flow_into => {} }, {
		   -logic_name => 'ReformatRegulationSolr',
		   -module =>
'Bio::EnsEMBL::Production::Pipeline::Search::ReformatRegulationSolr',
		   -rc_name   => '1g',
		   -flow_into => {} }

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
