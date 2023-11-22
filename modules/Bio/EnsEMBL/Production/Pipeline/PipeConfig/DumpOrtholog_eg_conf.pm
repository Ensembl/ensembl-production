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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_eg_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf');

use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
	my ($self) = @_;

	return {
		%{ $self->SUPER::default_options() },

		release => undef,

		output_dir  => '/nfs/ftp/pub/databases/ensembl/projections/',
		cleanup_dir => 1,

    is_tree_compliant => 1,

		species_config => {
			# Fungi
			'EF_1' => {
                  compara     => 'fungi',
                  source      => 'schizosaccharomyces_pombe',
                  species     => undef,
                  antispecies => [
                    'saccharomyces_cerevisiae',
                    'schizosaccharomyces_pombe'
                  ],
			            division    => 'EnsemblFungi',
                  homology_types =>
                    ['ortholog_one2one', 'apparent_ortholog_one2one'],
			},
			'EF_2' => {
                  compara     => 'fungi',
                  source      => 'saccharomyces_cerevisiae',
                  species     => undef,
                  antispecies => [
                    'schizosaccharomyces_pombe',
                    'saccharomyces_cerevisiae'
                  ],
                  division    => 'EnsemblFungi',
                  homology_types =>
                    ['ortholog_one2one', 'apparent_ortholog_one2one'],
			},

			# Metazoa
			'EM_1' => {
                  compara     => 'metazoa',
                  source      => 'caenorhabditis_elegans',
                  species     => [
                    'caenorhabditis_brenneri',
                    'caenorhabditis_briggsae',
                    'caenorhabditis_japonica',
                    'caenorhabditis_remanei',
                    'pristionchus_pacificus',
                    'brugia_malayi',
                    'loa_loa',
                    'onchocerca_volvulus',
                    'strongyloides_ratti',
                    'trichinella_spiralis'
                  ],
                  antispecies => 'caenorhabditis_elegans',
			            division    => 'EnsemblMetazoa',
                  exclude     => undef,
                  homology_types =>
                    ['ortholog_one2one', 'apparent_ortholog_one2one'],
			},
			'EM_2' => {
                  compara     => 'metazoa',
                  source      => 'drosophila_melanogaster',
                  species     => [
                    'drosophila_ananassae',
                    'drosophila_erecta',
                    'drosophila_grimshawi',
                    'drosophila_mojavensis',
                    'drosophila_persimilis',
                    'drosophila_pseudoobscura',
                    'drosophila_sechellia',
                    'drosophila_simulans',
                    'drosophila_virilis',
                    'drosophila_willistoni',
                    'drosophila_yakuba'
                  ],
                  antispecies => 'drosophila_melanogaster',
                  division    => 'EnsemblMetazoa',
                  exclude     => undef,
                  homology_types =>
                    ['ortholog_one2one', 'apparent_ortholog_one2one'],
      },

			# Plants
			'EPl_1' => {
                  compara     => 'plants',
                  source      => 'arabidopsis_thaliana',
                  species     => undef,
                  antispecies => 'arabidopsis_thaliana',
                  division    => 'EnsemblPlants',
                  homology_types =>
                    ['ortholog_one2one', 'apparent_ortholog_one2one'],
                 },
			'EPl_2' => {
                  compara     => 'plants',
                  source      => 'oryza_sativa',
                  species     => undef,
                  antispecies => 'oryza_sativa',
                  division    => 'EnsemblPlants',
                  homology_types =>
                    ['ortholog_one2one', 'apparent_ortholog_one2one'],
			},

			# Protists
			'EPr_1' => {
                  compara     => 'protists',
                  source      => 'dictyostelium_discoideum',
                  species     => [
                    'entamoeba_nuttalli_p19_gca_000257125',
                    'entamoeba_invadens_ip1_gca_000330505',
                    'entamoeba_histolytica_ku27_gca_000338855',
                    'entamoeba_histolytica_hm_3_imss_gca_000346345',
                    'entamoeba_histolytica_hm_1_imss_b_gca_000344925',
                    'entamoeba_histolytica_hm_1_imss_a_gca_000365475',
                    'entamoeba_histolytica',
                    'entamoeba_dispar_saw760_gca_000209125',
                    'dictyostelium_purpureum_gca_000190715',
                    'cavenderia_fasciculata_gca_000203815',
                    'acanthamoeba_castellanii_str_neff_gca_000313135'
                  ],
                  antispecies => 'dictyostelium_discoideum',
                  division    => 'EnsemblProtists',
                  homology_types =>
                    ['ortholog_one2one', 'apparent_ortholog_one2one'],
			},
    },
  };
}

1;
