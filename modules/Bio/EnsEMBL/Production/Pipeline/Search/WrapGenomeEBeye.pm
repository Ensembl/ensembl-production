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
	my $release = $self->param_required('release');
	my $ebeye_base_path = $self->param('base_path');
        my $wrapper = Bio::EnsEMBL::Production::Search::EBeyeGenomeWrapper->new();
        $wrapped_genomes_file = $wrapper->wrap_genomes($ebeye_base_path, $division->[0], $release);
        $self->dataflow_output_id( {  filename     => $wrapped_genomes_file }, 1 );
	return;
} ## end sub run

1;





