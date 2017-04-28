
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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_ensembl_conf;

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

		'output_dir'       => '/nfs/ftp/pub/databases/ensembl/projections/',
		'compara'          => 'multi',

		## Set to '1' for eg! run
		#   default => OFF (0)
		'eg' => 0,

		# hive_capacity values for analysis
		'getOrthologs_capacity' => '50',

		# orthologs cutoff
		'perc_id'  => '30',
		'perc_cov' => '66',

		# 'target' & 'exclude' are mutually exclusive
		#  only one of those should be defined if used
		'species_config' => {
			'1' => {             # compara database to get orthologs from
				    #  'plants', 'protists', 'fungi', 'metazoa', 'multi'
				'compara' => 'multi',
				# source species to project from
				'source' => 'homo_sapiens',
				# target species to project to (DEFAULT: undef)
				'target' => [ 'vicugna_pacos',
							  'anolis_carolinensis',
							  'dasypus_novemcinctus',
							  'otolemur_garnettii',
							  'felis_catus',
							  'gallus_gallus',
							  'pan_troglodytes',
							  'chlorocebus_sabaeus',
							  'dipodomys_ordii',
							  'bos_taurus',
							  'canis_familiaris',
							  'tursiops_truncatus',
							  'anas_platyrhynchos',
							  'loxodonta_africana',
							  'ficedula_albicollis',
							  'nomascus_leucogenys',
							  'gorilla_gorilla',
							  'sorex_araneus',
							  'cavia_porcellus',
							  'equus_caballus',
							  'procavia_capensis',
							  'macaca_mulatta',
							  'callithrix_jacchus',
							  'pteropus_vampyrus',
							  'myotis_lucifugus',
							  'mus_musculus',
							  'microcebus_murinus',
							  'mustela_putorius_furo',
							  'monodelphis_domestica',
							  'pongo_abelii',
							  'ailuropoda_melanoleuca',
							  'papio_anubis',
							  'sus_scrofa',
							  'ochotona_princeps',
							  'ornithorhynchus_anatinus',
							  'pelodiscus_sinensis',
							  'oryctolagus_cuniculus',
							  'ovis_aries',
							  'choloepus_hoffmanni',
							  'ictidomys_tridecemlineatus',
							  'tarsius_syrichta',
							  'sarcophilus_harrisii',
							  'echinops_telfairi',
							  'tupaia_belangeri',
							  'meleagris_gallopavo',
							  'macropus_eugenii',
							  'erinaceus_europaeus',
							  'rattus_norvegicus',
							  'taeniopygia_guttata' ],
				# target species to exclude in projection
				'exclude' => undef,
				#
				'homology_types' =>
				  [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

			'2' => { 'compara' => 'multi',
					 'source'  => 'mus_musculus',
					 'target'  => ['vicugna_pacos',
								   'anolis_carolinensis',
								   'dasypus_novemcinctus',
								   'otolemur_garnettii',
								   'felis_catus',
								   'gallus_gallus',
								   'pan_troglodytes',
								   'chlorocebus_sabaeus',
								   'dipodomys_ordii',
								   'bos_taurus',
								   'canis_familiaris',
								   'tursiops_truncatus',
								   'anas_platyrhynchos',
								   'loxodonta_africana',
								   'ficedula_albicollis',
								   'gorilla_gorilla',
								   'homo_sapiens',
								   'sorex_araneus',
								   'cavia_porcellus',
								   'equus_caballus',
								   'procavia_capensis',
								   'macaca_mulatta',
								   'callithrix_jacchus',
								   'pteropus_vampyrus',
								   'myotis_lucifugus',
								   'microcebus_murinus',
								   'mustela_putorius_furo',
								   'monodelphis_domestica',
								   'pongo_abelii',
								   'ailuropoda_melanoleuca',
								   'papio_anubis',
								   'sus_scrofa',
								   'ochotona_princeps',
								   'ornithorhynchus_anatinus',
								   'pelodiscus_sinensis',
								   'oryctolagus_cuniculus',
								   'ovis_aries',
								   'choloepus_hoffmanni',
								   'ictidomys_tridecemlineatus',
								   'tarsius_syrichta',
								   'sarcophilus_harrisii',
								   'echinops_telfairi',
								   'tupaia_belangeri',
								   'meleagris_gallopavo',
								   'macropus_eugenii',
								   'erinaceus_europaeus',
								   'rattus_norvegicus',
								   'taeniopygia_guttata' ],
					 'exclude' => undef,
					 'homology_types' =>
					   [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

			'3' => { 'compara' => 'multi',
					 'source'  => 'danio_rerio',
					 'target'  => ['astyanax_mexicanus',
								   'gadus_morhua',
								   'takifugu_rubripes',
								   'petromyzon_marinus',
								   'lepisosteus_oculatus',
								   'oryzias_latipes',
								   'poecilia_formosa',
								   'gasterosteus_aculeatus',
								   'tetraodon_nigroviridis',
								   'oreochromis_niloticus',
								   'latimeria_chalumnae',
								   'xiphophorus_maculatus',
								   'xenopus_tropicalis' ],
					 'exclude' => undef,
					 'homology_types' =>
					   [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

			'4' => { 'compara' => 'multi',
					 'source'  => 'rattus_norvegicus',
					 'target'  => [ 'homo_sapiens', 'mus_musculus' ],
					 'exclude' => undef,
					 'homology_types' =>
					   [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

			'5' => { 'compara'        => 'multi',
					 'source'         => 'xenopus_tropicalis',
					 'target'         => ['danio_rerio'],
					 'exclude'        => undef,
					 'homology_types' => [
								'ortholog_one2one', 'apparent_ortholog_one2one',
								'ortholog_one2many' ], },

		},

	};
} ## end sub default_options

1;
