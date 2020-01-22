
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf_strains;

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

			'1' => { 'compara' => 'multi',
					 'source'  => 'mus_musculus',
					 'antispecies' => ['mus_musculus','mus_spretus','mus_pahari','mus_caroli'],
                      # project all the xrefs instead of display xref only. This is mainly used for the mouse strains at the moment.
                      # Taxon name of species to project to
                     'taxons'      => ['Mus'],
                      # target species division to project to
                     'division' => 'EnsemblVertebrates',
					 'homology_types' =>
					   [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

		  }

	};
} ## end sub default_options

1;
