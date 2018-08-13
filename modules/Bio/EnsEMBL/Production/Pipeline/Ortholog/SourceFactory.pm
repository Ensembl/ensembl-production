
=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::Ortholog::SourceFactory

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut

package Bio::EnsEMBL::Production::Pipeline::Ortholog::SourceFactory;

use strict;
use Data::Dumper;
use base ('Bio::EnsEMBL::Hive::Process');

sub param_defaults {
	return {

	};
}

sub fetch_input {
	my ($self) = @_;

	return 0;
}

sub run {
	my ($self) = @_;

	return 0;
}

sub write_output {
	my ($self) = @_;

	my $sp_config     = $self->param_required('species_config');
	my $compara_param = $self->param('compara');
	my $cleanup_dir = $self->param('cleanup_dir');

	foreach my $pair ( keys $sp_config ) {
		my $compara = $sp_config->{$pair}->{'compara'};
		if(defined $compara_param && $compara ne $compara_param) {
			print STDERR "Skipping $compara\n";
			next;		
		}
		print STDERR "Processing $compara\n";
		my $source         = $sp_config->{$pair}->{'source'};
		my $species        = $sp_config->{$pair}->{'species'};
	    my $antispecies    = $sp_config->{$pair}->{'antispecies'};
	    my $taxons        = $sp_config->{$pair}->{'taxons'};
	    my $antitaxons    = $sp_config->{$pair}->{'antitaxons'};
		my $homology_types = $sp_config->{$pair}->{'homology_types'};
		my $division = $sp_config->{$pair}->{'division'};
		my $dir_name = $self->param('output_dir').'/'.lc($division);

		if (!defined $division){
			$self->throw("Division need to be defined");
		}
		# If cleanup_dir is set to 1
		# cleanup the projection directory before running the pipeline
		if ($cleanup_dir){
			unlink glob "$dir_name/*";
		}
		$self->dataflow_output_id( {  'output_dir'     => $dir_name,
					      'division'       => $division,
					      'compara'        => $compara,
					      'source'         => $source,
					      'species'         => $species,
					      'antispecies'     => $antispecies,
					      'taxons'         => $taxons,
					      'antitaxons'     => $antitaxons,
 	 				      'homology_types' => $homology_types, },
                       2 );
			#Flowing all the species to figure out species without orthology-based projection
	    $self->dataflow_output_id( {  'output_dir'     => $dir_name,
					      'division'       => $division },
					   1 );
	}

	return 0;
} ## end sub write_output

1;

