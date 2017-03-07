
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

			'1' => { 'compara' => 'multi',
					 'source'  => 'mus_musculus',
					 'target'  => [
							'mus_musculus_129s1svimj', 'mus_musculus_aj',
							'mus_musculus_akrj',       'mus_musculus_balbcj',
							'mus_musculus_c3hhej',     'mus_musculus_c57bl6nj',
							'mus_musculus_casteij',    'mus_musculus_cbaj',
							'mus_musculus_dba2j',      'mus_musculus_fvbnj',
							'mus_musculus_lpj',        'mus_musculus_nodshiltj',
							'mus_musculus_nzohlltj',   'mus_musculus_pwkphj',
							'mus_musculus_wsbeij' ],
					 'exclude' => undef,
					 'homology_types' =>
					   [ 'ortholog_one2one', 'apparent_ortholog_one2one' ], },

		  }

	};
} ## end sub default_options

1;
