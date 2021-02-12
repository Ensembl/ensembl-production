=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Search::WrapGenomeEBeye;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
#use Bio::EnsEMBL::Production::Search::EBeyeFormatter;
use Bio::EnsEMBL::Production::Search::EBeyeGenomeWrapper;

use JSON;
use File::Slurp qw/read_file/;
use File::Find::Rule; 
use Carp qw(croak);

use Log::Log4perl qw/:easy/;
use Data::Dumper;



sub run {
	my ($self) = @_;
	my $wrapped_genomes_file;
	if ( $self->debug() ) {
		Log::Log4perl->easy_init($DEBUG);
	}
	else {
		Log::Log4perl->easy_init($INFO);
	}
	$self->{logger} = get_logger();

	my $division = $self->param_required('division');
  my @division = ( ref($division) eq 'ARRAY' ) ? @$division : ($division);
	my $release = $self->param_required('release');
	my $ebeye_base_path = $self->param('base_path');
  my $wrapper = Bio::EnsEMBL::Production::Search::EBeyeGenomeWrapper->new();
  foreach my $division (@division) {
    $wrapped_genomes_file = $wrapper->wrap_genomes($ebeye_base_path, $division, $release);
    $self->dataflow_output_id( {  wrapped_genomes_file     => $wrapped_genomes_file }, 1 );
	}
	return;
} ## end sub run

1;





