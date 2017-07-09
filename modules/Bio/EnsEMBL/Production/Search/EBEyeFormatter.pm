
=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Search::EBEyeFormatter;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use List::MoreUtils qw/natatime/;

use JSON;
use Carp;
use File::Slurp;
use XML::Simple;
use POSIX 'strftime';
use XML::Writer;

use Exporter 'import';
our @EXPORT = qw(_array_nonempty _id_ver _base);

my $date = strftime '%Y-%m-%d', localtime;

sub new {
	my ( $class, @args ) = @_;
	my $self = bless( {}, ref($class) || $class );
	$self->{log} = get_logger();

	return $self;
}

sub log {
	my ($self) = @_;
	return $self->{log};
}

sub reformat_genome {
	my ( $self, $genome_file, $outfile ) = @_;

	my $genome = read_json($genome_file);

	open my $fh, '>', $outfile or croak "Could not open $outfile for writing";

	my $writer = XML::Writer->new( OUTPUT => $fh, NEWLINES => 1 );
	$writer->xmlDecl("ISO-8859-1");
	$writer->doctype("entry");

	_print_entry_start( $writer, $genome->{id} );
	_print_dates($writer);
	_print_crossrefs( $writer,
					 { ncbi_taxonomy_id => $genome->{organism}{taxonomy_id} } );
	_print_additional_fields(
				 $writer, {
				   'genomic_unit'       => $genome->{division},
				   'display_name'       => $genome->{organism}{display_name},
				   'scientific_name'    => $genome->{organism}{scientific_name},
				   'production_name'    => $genome->{organism}{production_name},
				   'common_name'        => $genome->{organism}{common_name},
				   'strain'             => $genome->{organism}{strain},
				   'serotype'           => $genome->{organism}{serotype},
				   'assembly_name'      => $genome->{assembly}{name},
				   'assembly_default'   => $genome->{assembly}{'default'},
				   'assembly_accession' => $genome->{assembly}{accession},
				   'genebuild'          => $genome->{genebuild},
				   'is_reference'       => $genome->{is_reference},
				   'has_pan_compara'    => $genome->{has_pan_compara},
				   'has_peptide_compara'   => $genome->{has_peptide_compara},
				   'has_synteny'           => $genome->{has_synteny},
				   'has_genome_alignments' => $genome->{has_genome_alignments},
				   'has_other_alignments'  => $genome->{has_other_alignments},
				   'has_variations'        => $genome->{has_variations},
				   'alias'                 => $genome->{organism}{aliases},
				   'classification'        => $genome->{organism}{lineage} } );
	_print_entry_end($writer);
	$writer->end();
	close $fh;
	return;
} ## end sub reformat_genome

sub reformat_genes {
	my ( $self, $genome_file, $genes_file, $outfile ) = @_;

	my $genome = read_json($genome_file);

	open my $writer, '>', $outfile or
	  croak "Could not open $outfile for writing";

	#	printf $writer q(<?xml version="1.0" encoding="ISO-8859-1"?>
	#<!DOCTYPE database [ <!ENTITY auml "&#228;">]>
	#<database>
	#	<name>%s</name>
	#	<description>%s %s % database</description>
	#	<release>%s</release>
	#	<entries>
	#	);
	#	_print_entry_start( $writer, $genome->{id} );
	#	_print_dates($writer);
	return;
}

sub reformat_sequences {
	my ( $self, $genome_file, $sequences_file, $outfile ) = @_;
	return;
}

sub reformat_variants {
	my ( $self, $genome_file, $variants_file, $outfile ) = @_;
	return;
}

sub _print_entry_start {
	my ( $writer, $id ) = @_;
	$writer->startTag( "entry", "id" => $id );
	return;
}

sub _print_entry_end {
	my ($writer) = @_;
	$writer->endTag("entry");
	return;
}

sub _print_additional_fields {
	my ( $writer, $fields ) = @_;
	$writer->startTag("additional_fields");
	while ( my ( $k, $v ) = each %$fields ) {
		if ( defined $v ) {
			if ( ref($v) eq 'ARRAY' ) {
				for my $e (@$v) {
					_print_field( $writer, $k, $e );
				}
			}
			else {
				_print_field( $writer, $k, $v );
			}
		}
	}
	$writer->endTag("additional_fields");
	return;
}

sub _print_field {
	my ( $writer, $key, $value ) = @_;
	return unless defined $value;
	if(ref($value) eq 'ARRAY') {
		for my $e (@{$value}) {
			_print_field($writer,$key,$e);
		}				
	} else {
		$writer->dataElement($key, $value);
	}
	return;
}

sub _print_dates {
	my ($writer) = @_;
	$writer->startTag("dates");
	$writer->emptyTag( "date", creation => $date, last_modification => $date );
	$writer->endTag("dates");
	return;
}

sub _print_crossrefs {
	my ( $writer, $xrefs ) = @_;
	$writer->startTag("cross_references");
	while ( my ( $k, $v ) = each %$xrefs ) {
		if ( ref $v eq 'ARRAY' ) {
			for my $e ( @{$v} ) {
				$writer->emptyTag( "ref", dbname => $k, dbkey => $e );
			}
		}
		else {
			$writer->emptyTag( "ref", dbname => $k, dbkey => $v );
		}
	}
	$writer->endTag("cross_references");
	return;
}

sub add_key {
	my ( $v, $to, $to_key ) = @_;
	$to->{$to_key} = $v if defined $v;
	return;
}

sub read_json {
	my ($file) = @_;
	return decode_json( read_file($file) );
}

1;
