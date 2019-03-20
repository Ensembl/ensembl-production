package Bio::EnsEMBL::Production::Pipeline::Search::ValidateXMLFileEBeye;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
#use Bio::EnsEMBL::Production::Search::EBeyeFormatter;
#use Bio::EnsEMBL::Production::Search::EBeyeXMLValidator;

use JSON;
use File::Slurp qw/read_file/;
use File::Find::Rule; 
use Carp qw(croak);

use Log::Log4perl qw/:easy/;
use Data::Dumper;

sub param_defaults {
  my ($self) = @_;
  return {
    supported_types => { core => 1 },
    validator => 'xmllint', #can be xmlstarlet or xmllint
    xmlstarlet => 'xml',
    xmllint => 'xmllint',
  };
}

sub run {
	my ($self) = @_;
	if ( $self->debug() ) {
		Log::Log4perl->easy_init($DEBUG);
	}
	else {
		Log::Log4perl->easy_init($INFO);
	}
	$self->{logger} = get_logger();

	my $division = $self->param_required('division');
	my $release = $self->param_required('release');
	my $species = $self->param_required('species');
	my $bpath = $self->param('base_path');
	my $xml_validator = $self->param('validator');
        # my $validator = Bio::EnsEMBL::Production::Search::EBeyeXMLValidator->new();
        # $validator->validate_xml($bpath, $division->[0], 42, $xml_validator);
	my $genome_file = $self->param('genome_xml_file');
	my $genes_file = $self->param('genes_xml_file');
	my $sequences_file = $self->param('sequences_xml_file');
	my ($valid_genome, $valid_genes, $valid_sequences) = (0, 0, 0);
	
	my $output = { species => $species };

	$valid_genome = $self->validate_xml_file($genome_file, $xml_validator);
	$valid_genes = $self->validate_xml_file($genes_file, $xml_validator);
	$valid_sequences = $self->validate_xml_file($sequences_file, $xml_validator);
	
	if ( $valid_genome  == 0) {
		$output->{genome_valid_file} = $genome_file;
		}
	if ( $valid_genes == 0) {
		$output->{genes_valid_file} = $genes_file;
		}
	if ( $valid_sequences == 0) {
		$output->{sequences_valid_file} = $sequences_file;
		}
	$self->dataflow_output_id( $output, 1 );
	$self->dataflow_output_id( $output, 2 );
	return;
} ## end sub run

sub validate_xml_file
	{
	my ( $self, $xml_file, $xml_validator ) = @_;

        my $err_file = $xml_file . '.err';
        my $cmd = sprintf(q{xmllint --sax --stream -noout %s 2> %s},
                        $xml_file,
                        $err_file);
        my ($rc, $output) = $self->run_cmd($cmd);
       	
	# throw sprintf "XML validator xmllint reports failure(s) for %s EB-eye dump.\nSee error log at file %s", $self->param('species'), $err_file
        if ( $rc == 0 ) {
        	unlink $err_file;
		return 0;
		}
	return 1;
	}

1;


