
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

        # Flag controling the use of the is_tree_compliant flag from the homology table of the Compara database
	    # If this flag is on (=1) then the pipeline will exclude all homologies where is_tree_compliant=0 in the homology table of the Compara db
        # This flag should be enabled for EG and disable for e! species.

        'is_tree_compliant' => '0',

		# hive_capacity values for analysis
		'getOrthologs_capacity' => '50',

		# Cleanup projection directory before running the pipeline
		'cleanup_dir' => 0,

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
				# target species to project to
                'species'     => [],
                # target species to exclude
                'antispecies' => ['homo_sapiens','mus_musculus_129s1svimj', 'mus_musculus_aj', 'mus_musculus_akrj', 'mus_musculus_balbcj', 'mus_musculus_c3hhej', 'mus_musculus_c57bl6nj', 'mus_musculus_casteij', 'mus_musculus_cbaj', 'mus_musculus_dba2j', 'mus_musculus_fvbnj', 'mus_musculus_lpj', 'mus_musculus_nodshiltj', 'mus_musculus_nzohlltj', 'mus_musculus_pwkphj', 'mus_musculus_wsbeij'],
                # target species division to project to
                'division' => 'Ensembl',
				# Taxon name of species to project to
                'taxons'      => ['Amniota'],
                # Taxon name of species to exclude
                'antitaxons' => [],
				# target species to exclude in projection
				'exclude' => [],
				'homology_types' =>
				  [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

			'2' => { 'compara' => 'multi',
					 'source'  => 'mus_musculus',
					 'species'     => [],
                     # target species to exclude
                     'antispecies' => ['mus_musculus','mus_musculus_129s1svimj', 'mus_musculus_aj', 'mus_musculus_akrj', 'mus_musculus_balbcj', 'mus_musculus_c3hhej', 'mus_musculus_c57bl6nj', 'mus_musculus_casteij', 'mus_musculus_cbaj', 'mus_musculus_dba2j', 'mus_musculus_fvbnj', 'mus_musculus_lpj', 'mus_musculus_nodshiltj', 'mus_musculus_nzohlltj', 'mus_musculus_pwkphj', 'mus_musculus_wsbeij'],
                     # target species division to project to
                     'division' => 'Ensembl',
                     # Taxon name of species to project to
                     'taxons'      => ['Amniota'],
                     # Taxon name of species to exclude
                     'antitaxons' => [],
					 'exclude' => [],
					 'homology_types' =>
					   [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

			'3' => { 'compara' => 'multi',
					 # source species to project from
                     'source'      => 'danio_rerio', # 'schizosaccharomyces_pombe'
                     # target species to project
                     'species' => [],
                     # target species to exclude
                     'antispecies' => ['danio_rerio'],
                     # target species division to project to
                     'division' => 'Ensembl',
                     # Taxon name of species to project to
                     'taxons'      => ['Neopterygii','Cyclostomata','Coelacanthimorpha','Amphibia','Tunicata'],
                     # Taxon name of species to exclude
                     'antitaxons' => [],
					 'exclude' => undef,
					 'homology_types' =>
					   [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

			'4' => { 'compara' => 'multi',
					 'source'  => 'rattus_norvegicus',
					 'species'  => [ 'homo_sapiens', 'mus_musculus' ],
					 # target species division to project to
                     'division' => 'Ensembl',
					 'exclude' => undef,
					 'homology_types' =>
					   [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

			'5' => { 'compara'        => 'multi',
					 'source'         => 'xenopus_tropicalis',
					 'species'         => ['danio_rerio'],
					 # target species division to project to
                     'division' => 'Ensembl',
					 'exclude'        => undef,
					 'homology_types' => [
								'ortholog_one2one', 'apparent_ortholog_one2one',
								'ortholog_one2many' ], },

		},

	};
} ## end sub default_options

1;
