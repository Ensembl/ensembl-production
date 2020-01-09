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

=cut

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
	my $bpath = $self->param('base_path');
	my $xml_validator = $self->param('validator');
	my $genome_file = $self->param('genome_xml_file');
	my $genes_file = $self->param('genes_xml_file');
	my $sequences_file = $self->param('sequences_xml_file');
	my $variants_file = $self->param('variants_xml_file');
	my $wrapped_genomes_file = $self->param('wrapped_genomes_file');
	my ($valid_genome, $valid_genes, $valid_sequences, $valid_variants, $valid_wrapped_genomes) = (0, 0, 0, 0, 0);
	
	my $output;
	$output = { species => $self->param('species') } if !defined $wrapped_genomes_file;
	$output = { division => $division } if defined $wrapped_genomes_file;

	$valid_genome = $self->validate_xml_file($genome_file, $xml_validator) if defined  $genome_file;
	$valid_genes = $self->validate_xml_file($genes_file, $xml_validator) if defined  $genes_file;
	$valid_sequences = $self->validate_xml_file($sequences_file, $xml_validator) if defined  $sequences_file;
	$valid_variants = $self->validate_xml_file($variants_file, $xml_validator) if defined  $variants_file;
  $valid_wrapped_genomes = $self->validate_xml_file($wrapped_genomes_file, $xml_validator) if defined  $wrapped_genomes_file;

	if ( $valid_genome  == 0 and defined $genome_file) {
		$output->{genome_valid_file} = $genome_file;
	}
	if ( $valid_genes == 0 and defined $genes_file) {
		$output->{genes_valid_file} = $genes_file;
	}
	if ( $valid_sequences == 0 and defined $sequences_file) {
		$output->{sequences_valid_file} = $sequences_file;
	}
	if ( $valid_variants == 0 and defined $variants_file) {
		$output->{variants_valid_file} = $variants_file;
	}
	if ( $valid_wrapped_genomes == 0 and defined $wrapped_genomes_file) {
		$output->{wrapped_genomes_valid_file} = $wrapped_genomes_file;
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


