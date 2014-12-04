
=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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

Bio::EnsEMBL::EGPipeline::PipeConfig::UniProtGO_conf

=head1 DESCRIPTION

TODO

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::UniProtGO_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

sub default_options {
  my ($self) = @_;
  return {
	%{$self->SUPER::default_options},

	pipeline_name => 'uniprot_go_' . $self->o('ensembl_release'),

	species  => [],
	division => [],
	run_all  => 0,

	release => $self->o('ensembl_release'),
	email   => $self->o('ENV', 'USER') . '@ebi.ac.uk',};
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {%{$self->SUPER::pipeline_wide_parameters()},
		  release => $self->o('release')};
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my $self = shift;
  return "-reg_conf " . $self->o("registry");
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
	{-logic_name => 'ScheduleSpecies',
	 -module =>
	   'Bio::EnsEMBL::EGPipeline::CoreStatistics::EGSpeciesFactory',
	 -parameters => {species  => $self->o('species'),
					 division => $self->o('division')},
	 -input_ids       => [{}],
	 -max_retry_count => 1,
	 -flow_into       => {
	   '2' => [    # These analyses are run for all species.
				   'LoadUniProtGO']},
	 -rc_name => 'normal',},

	{-logic_name => 'LoadUniProtGO',
	 -module     => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProtGO',
	 -parameters => {
				   uniprot_user   => 'spselect',
				   uniprot_pass   => 'spselect',
				   uniprot_host   => 'whisky.ebi.ac.uk',
				   uniprot_port   => 1531,
				   uniprot_dbname => 'SWPREAD',
				   uniprot_driver => 'Oracle'},
	 -max_retry_count => 3,
	 -hive_capacity   => 10,
	 -rc_name         => 'normal',}

  
 ];
}	 ## end sub pipeline_analyses

1;
