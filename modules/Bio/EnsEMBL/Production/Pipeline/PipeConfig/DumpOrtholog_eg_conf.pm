
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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_eg_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_eg_conf;

use strict;
use warnings;
use Bio::EnsEMBL::Hive::Version 2.3;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf');

sub default_options {
	my ($self) = @_;

	return {
		# inherit other stuff from the base class
		%{ $self->SUPER::default_options() },

		'output_dir'       => '/nfs/nobackup/ensemblgenomes/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name'),
		'compara' => undef,
		'release' => undef,

		## Set to '1' for eg! run
		#   default => OFF (0)
		'eg' => 1,

		# hive_capacity values for analysis
		'getOrthologs_capacity' => '50',

		# orthologs cutoff
		'perc_id'  => '30',
		'perc_cov' => '66',

		# 'target' & 'exclude' are mutually exclusive
		#  only one of those should be defined if used
		'species_config' => {
			# Plants
			'EPl_1' => {    # compara database to get orthologs from
				            #  'plants', 'protists', 'fungi', 'metazoa', 'multi'
				'compara' => 'plants',
				# source species to project from
				'source' => 'arabidopsis_thaliana',
				# target species to project to (DEFAULT: undef)
				'target' => undef,
				# target species to exclude in projection
				'exclude' => [ 'caenorhabditis_elegans',
							   'drosophila_melanogaster',
							   'homo_sapiens',
							   'ciona_savignyi' ],
				'homology_types' =>
				  [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

			'EPl_2' => {
				'compara' => 'plants',
				'source'  => 'oryza_sativa',
				'target'  => undef,
				'exclude' => [ 'caenorhabditis_elegans',
							   'drosophila_melanogaster',
							   'homo_sapiens',
							   'ciona_savignyi' ],
				'homology_types' =>
				  [ 'ortholog_one2one', 'apparent_ortholog_one2one' ],
			},

			# Protists, dictyostelium_discoideum to all amoebozoa
			'EPr_1' => { 'compara' => 'protists',
						 'source'  => 'dictyostelium_discoideum',
						 'target'  => ['polysphondylium_pallidum_pn500',
									   'entamoeba_nuttalli_p19',
									   'entamoeba_invadens_ip1',
									   'entamoeba_histolytica_ku27',
									   'entamoeba_histolytica_hm_3_imss',
									   'entamoeba_histolytica_hm_1_imss_b',
									   'entamoeba_histolytica_hm_1_imss_a',
									   'entamoeba_histolytica',
									   'entamoeba_dispar_saw760',
									   'dictyostelium_purpureum',
									   'dictyostelium_fasciculatum',
									   'acanthamoeba_castellanii_str_neff' ],
						 'exclude' => undef,
						 'homology_types' =>
						   [ 'ortholog_one2one', 'apparent_ortholog_one2one' ],
			},

			# Fungi
			'EF_1' => { 'compara' => 'fungi',
						'source'  => 'schizosaccharomyces_pombe',
						'target'  => undef,
						'exclude' => ['saccharomyces_cerevisiae'],
						'homology_types' =>
						  [ 'ortholog_one2one', 'apparent_ortholog_one2one' ],
			},

			'EF_2' => { 'compara' => 'fungi',
						'source'  => 'saccharomyces_cerevisiae',
						'target'  => undef,
						'exclude' => ['schizosaccharomyces_pombe'],
						'homology_types' =>
						  [ 'ortholog_one2one', 'apparent_ortholog_one2one' ],
			},

			# Metazoa
			'EM_1' => { 'compara' => 'metazoa',
						'source'  => 'caenorhabditis_elegans',
						'target'  => ['caenorhabditis_brenneri',
									  'caenorhabditis_briggsae',
									  'caenorhabditis_japonica',
									  'caenorhabditis_remanei',
									  'pristionchus_pacificus',
									  'brugia_malayi',
									  'onchocerca_volvulus',
									  'strongyloides_ratti',
									  'loa_loa',
									  'trichinella_spiralis' ],
						'exclude' => undef,
						'homology_types' =>
						  [ 'ortholog_one2one', 'apparent_ortholog_one2one' ],
			},

			'EM_2' => {
				   'compara' => 'metazoa',
				   'source'  => 'drosophila_melanogaster',
				   'target'  => [
							'drosophila_ananassae',  'drosophila_erecta',
							'drosophila_grimshawi',  'drosophila_mojavensis',
							'drosophila_persimilis', 'drosophila_pseudoobscura',
							'drosophila_sechellia',  'drosophila_simulans',
							'drosophila_virilis',    'drosophila_willistoni',
							'drosophila_yakuba' ],
				   'exclude' => undef,
				   'homology_types' =>
					 [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

		}

	};
} ## end sub default_options

1;
