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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_ensembl_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf');

use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
	my ($self) = @_;

	return {
		%{ $self->SUPER::default_options() },

		compara => 'multi',

		output_dir => '/nfs/ftp/pub/databases/ensembl/projections/',

		species_config => {
			'1' => {
              compara     => 'multi',
              source      => 'homo_sapiens',
              species     => [],
              antispecies => [
                'homo_sapiens',
                'mus_musculus_129s1svimj',
                'mus_musculus_aj',
                'mus_musculus_akrj',
                'mus_musculus_balbcj',
                'mus_musculus_c3hhej',
                'mus_musculus_c57bl6nj',
                'mus_musculus_casteij',
                'mus_musculus_cbaj',
                'mus_musculus_dba2j',
                'mus_musculus_fvbnj',
                'mus_musculus_lpj',
                'mus_musculus_nodshiltj',
                'mus_musculus_nzohlltj',
                'mus_musculus_pwkphj',
                'mus_musculus_wsbeij'
              ],
              division    => 'EnsemblVertebrates',
              taxons      => ['Amniota'],
              antitaxons  => [],
              exclude     => [],
              homology_types =>
                ['ortholog_one2one', 'apparent_ortholog_one2one'],
      },

			'2' => {
              compara => 'multi',
              source  => 'mus_musculus',
              species     => [],
              antispecies => [
                'mus_musculus',
                'mus_musculus_129s1svimj',
                'mus_musculus_aj',
                'mus_musculus_akrj',
                'mus_musculus_balbcj',
                'mus_musculus_c3hhej',
                'mus_musculus_c57bl6nj',
                'mus_musculus_casteij',
                'mus_musculus_cbaj',
                'mus_musculus_dba2j',
                'mus_musculus_fvbnj',
                'mus_musculus_lpj',
                'mus_musculus_nodshiltj',
                'mus_musculus_nzohlltj',
                'mus_musculus_pwkphj',
                'mus_musculus_wsbeij'
              ],
              division    => 'EnsemblVertebrates',
              taxons      => ['Amniota'],
              antitaxons  => [],
              exclude     => [],
              homology_types =>
                ['ortholog_one2one', 'apparent_ortholog_one2one'],
      },

			'3' => {
              compara     => 'multi',
              source      => 'danio_rerio',
              species     => [],
              antispecies => ['danio_rerio'],
              division    => 'EnsemblVertebrates',
              taxons      => [
                'Neopterygii',
                'Cyclostomata',
                'Coelacanthimorpha',
                'Amphibia',
                'Tunicata'
              ],
              antitaxons  => [],
              exclude     => undef,
              homology_types =>
                ['ortholog_one2one', 'apparent_ortholog_one2one'],
      },

			'4' => {
              compara  => 'multi',
              source   => 'rattus_norvegicus',
              species  => ['homo_sapiens', 'mus_musculus'],
              division => 'EnsemblVertebrates',
              exclude  => undef,
              homology_types =>
                ['ortholog_one2one', 'apparent_ortholog_one2one'],
      },

			'5' => {
              compara  => 'multi',
              source   => 'xenopus_tropicalis',
              species  => ['danio_rerio'],
              division => 'EnsemblVertebrates',
              exclude  => undef,
              homology_types => [
								'ortholog_one2one', 'apparent_ortholog_one2one',
								'ortholog_one2many'
              ],
      },
		},
	};
}

1;
