
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

package Bio::EnsEMBL::Production::Search::EBeyeFormatter;

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
use POSIX 'strftime';
use XML::Writer;
use Bio::EnsEMBL::Production::Search::JSONReformatter;

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

        # Extract only the division name and make it lowercase
        # EnsemblPlants -> Plants -> plants, EnsemblFungi -> Fungi -> fungi, EnsemblProtists -> Protists -> protists  etc...
        my $genome_division = $genome->{division};
        my $genomic_unit_val = lc substr($genome_division,7);

	open my $fh, '>', $outfile or croak "Could not open $outfile for writing";

	my $writer =
	  XML::Writer->new( OUTPUT => $fh, DATA_MODE => 1, DATA_INDENT => 2 );
	$writer->xmlDecl("ISO-8859-1");
	$writer->doctype("entry");

	_print_entry_start( $writer, $genome->{id} );
	_print_dates($writer);
	_print_crossrefs( $writer,
					 { ncbi_taxonomy_id => $genome->{organism}{taxonomy_id} } );
	_print_additional_fields(
				 $writer, {
				   'division'		=> $genome->{division},
				   'genomic_unit'       => $genomic_unit_val,
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
	my ( $self, $genome_file, $database, $genes_file, $outfile ) = @_;
	my $genome = read_json($genome_file);
        # Extract only the division name and make it lowercase
        # EnsemblPlants -> Plants -> plants, EnsemblFungi -> Fungi -> fungi, EnsemblProtists -> Protists -> protists  etc...
	my $genome_division = $genome->{division};
	my $genomic_unit_val = lc substr($genome_division,7);

	open my $fh, '>', $outfile or croak "Could not open $outfile for writing";
	my $writer =
	  XML::Writer->new( OUTPUT => $fh, DATA_MODE => 1, DATA_INDENT => 2 );
	$writer->xmlDecl("ISO-8859-1");
	$writer->doctype("database");
	$writer->startTag('database');
	$writer->dataElement( 'name', $database );
	$database =~ m/.*_([a-z]+)_([0-9]+)_([0-9]+)(_([0-9]+))?/;
	my $type    = $1;
	my $release = $2;
	$writer->dataElement( 'description',
						  sprintf( "%s %s %s database",
								   $genome->{division},
								   $genome->{organism}{display_name},
								   $type, $release ) );
	$writer->dataElement( 'release', $release );
	_print_dates($writer);
	$writer->startTag('entries');
	process_json_file(
		$genes_file,
		sub {
			my ($gene) = @_;
			_print_entry_start( $writer, $gene->{id} );
			$writer->dataElement( 'name', $gene->{name} )
			  if defined $gene->{name};
			$writer->dataElement( 'description', $gene->{description} )
			  if defined $gene->{description};
			my $xrefs =
			  { ncbi_taxonomy_id => $genome->{organism}{taxonomy_id} };
			my $fields = {
				 species     => $genome->{organism}{display_name},
				 system_name => $genome->{organism}{name},
				 featuretype => 'Gene',
				 source      => $gene->{source} . ' ' . $gene->{biotype},
				 haplotype   => (
					 ( defined $gene->{haplotype} && $gene->{haplotype} eq '1' )
					 ? 'haplotype' :
					   'reference' ),
				 genomic_unit => $genomic_unit_val,
				 location =>
				   sprintf( '%s:%s-%s',
							$gene->{seq_region_name}, $gene->{start},
							$gene->{end} ),
				 database => $type };

			$fields->{gene_synonyms} = $gene->{synonyms}
			  if defined $gene->{synonyms};
			$fields->{gene_version} = $gene->{id} . '.' . $gene->{version}
			  if defined $gene->{version} && $gene->{version} > 0;

			_add_xrefs( $xrefs, $gene );

			if ( defined $gene->{probes} ) {
				for my $probe ( @{ $gene->{probes} } ) {
					push @{ $fields->{probes} }, $probe->{probe};
				}
			}

			if ( defined $gene->{homologues} ) {
				my $gts = {};
				for my $homologue ( @{ $gene->{homologues} } ) {
					$gts->{ $homologue->{gene_tree_id} }++ if defined $homologue->{gene_tree_id};
				}
				$fields->{genetree} = [ keys %$gts ];
			}

			if ( defined $gene->{seq_region_synonyms} ) {
				for my $sr ( @{ $gene->{seq_region_synonym} } ) {
					push @{ $fields->{seq_region_synonym} }, $sr->{id};
				}
			}

			my $exons = {};
			for my $transcript ( @{ $gene->{transcripts} } ) {
				$fields->{transcript_count}++;
				push @{ $fields->{transcript} }, $transcript->{id};
				push @{ $fields->{transcript_version} },
				  $transcript->{id} . '.' . $transcript->{version}
				  if defined $transcript->{version} &&
				  $transcript->{version} > 0;
				_add_xrefs( $xrefs, $transcript );
				for my $translation ( @{ $transcript->{translations} } ) {
					push @{ $fields->{peptide} }, $translation->{id};
					push @{ $fields->{peptide_version} },
					  $translation->{id} . '.' . $translation->{version}
					  if defined $translation->{version} &&
					  $translation->{version} > 0;
					_add_xrefs( $xrefs, $translation );
					for my $pf ( @{ $translation->{protein_features} } ) {
						$fields->{domains}++;
						push @{ $fields->{domain} }, $pf->{name};

					}
				}
				for my $exon ( @{ $transcript->{exons} } ) {
					$exons->{ $exon->{id} }++;
				}
			} ## end for my $transcript ( @{...})
			$fields->{exon}       = [ keys %$exons ];
			$fields->{exon_count} = scalar values %$exons;
			_print_crossrefs( $writer, $xrefs );
			_print_additional_fields( $writer, $fields );
			_print_entry_end($writer);
			return;
		} );
	$writer->endTag('entries');
	$writer->endTag('database');
	$writer->end();
	close $fh;
	return;
} ## end sub reformat_genes

sub _add_xrefs {
	my ( $xrefs, $o ) = @_;
	for my $xref ( @{ $o->{xrefs} } ) {
		push @{ $xrefs->{ $xref->{dbname} } }, $xref->{primary_id};
		push @{ $xrefs->{ $xref->{dbname} } }, $xref->{display_id}
		  if $xref->{primary_id} ne $xref->{display_id};

	}
	return;
}

sub reformat_sequences {
	my ( $self, $genome_file, $database, $sequences_file, $outfile ) = @_;
	my $genome = read_json($genome_file);
	
	# Extract only the division name and make it lowercase
	# EnsemblPlants -> Plants -> plants, EnsemblFungi -> Fungi -> fungi, EnsemblProtists -> Protists -> protists  etc...        
	my $genome_division = $genome->{division};
	my $genomic_unit_val = lc substr($genome_division,7);
	
	open my $fh, '>', $outfile or croak "Could not open $outfile for writing";
	my $writer =
	  XML::Writer->new( OUTPUT => $fh, DATA_MODE => 1, DATA_INDENT => 2 );
	$writer->xmlDecl("ISO-8859-1");
	$writer->doctype("database");
	$writer->startTag('database');
	$writer->dataElement( 'name', $database );
	$database =~ m/.*_([a-z]+)_([0-9]+)_([0-9]+)(_([0-9]+))?/;
	my $type    = $1;
	my $release = $2;
	$writer->dataElement( 'description',
						  sprintf( "%s %s %s database",
								   $genome->{division},
								   $genome->{organism}{display_name},
								   $type, $release ) );
	$writer->dataElement( 'release', $release );
	_print_dates($writer);
	$writer->startTag('entries');
	process_json_file(
		$sequences_file,
		sub {
			my ($seq) = @_;
			_print_entry_start( $writer, $seq->{id} );
			$writer->dataElement( 'name', $seq->{id} );
			_print_crossrefs( $writer, {
								 ncbi_taxonomy_id =>
								   $genome->{organism}{taxonomy_id} }
			);
			_print_additional_fields(
								$writer, {
								  species => $genome->{organism}{display_name},
								  genomic_unit => $genomic_unit_val, 
								  system_name  => $genome->{organism}{name},
								  coord_system => $seq->{type},
								  length       => $seq->{length},
								  location =>
									sprintf( '%s:%d-%d',
										$seq->{id}, $seq->{start}, $seq->{end} )
								} );
			_print_entry_end($writer);
			return;
		} );
	$writer->endTag('entries');
	$writer->endTag('database');
	$writer->end();
	close $fh;
	return;
} ## end sub reformat_sequences

sub reformat_variants {
	my ( $self, $genome_file, $database, $variants_file, $outfile ) = @_;
	my $genome = read_json($genome_file);

	# Extract only the division name and make it lowercase
        # EnsemblPlants -> Plants -> plants, EnsemblFungi -> Fungi -> fungi, EnsemblProtists -> Protists -> protists  etc...
	my $genome_division = $genome->{division};
	my $genomic_unit_val = lc substr($genome_division,7);

	open my $fh, '>', $outfile or croak "Could not open $outfile for writing";
	my $writer =
	  XML::Writer->new( OUTPUT => $fh, DATA_MODE => 1, DATA_INDENT => 2 );
	$writer->xmlDecl("ISO-8859-1");
	$writer->doctype("database");
	$writer->startTag('database');
	$writer->dataElement( 'name', $database );
	$database =~ m/.*_([a-z]+)_([0-9]+)_([0-9]+)(_([0-9]+))?/;
	my $type    = $1;
	my $release = $2;
	$writer->dataElement( 'description',
						  sprintf( "%s %s %s database",
								   $genome->{division},
								   $genome->{organism}{display_name},
								   $type, $release ) );
	$writer->dataElement( 'release', $release );
	_print_dates($writer);
	$writer->startTag('entries');
	process_json_file(
		$variants_file,
		sub {
			my ($var) = @_;
			_print_entry_start( $writer, $var->{id} );
			$writer->dataElement( 'name', $var->{id} );
			_print_crossrefs( $writer, {
								 ncbi_taxonomy_id =>
								   $genome->{organism}{taxonomy_id} } );
			_print_additional_fields(
								$writer, {
								  species 	   => $genome->{organism}{display_name},
								  genomic_unit 	   => $genomic_unit_val,
								  system_name      => $genome->{organism}{name},
								  variation_source => $var->{source}{name},
								  description =>
									sprintf( 'A %s Variant', $var->{source}{name} ) }
			);
			_print_entry_end($writer);
			return;
		} );
	$writer->endTag('entries');
	$writer->endTag('database');
	$writer->end();
	close $fh;
	return;
} ## end sub reformat_variants

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
				for my $e ( sort @$v ) {
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
	if ( ref($value) eq 'ARRAY' ) {
		for my $e ( @{$value} ) {
			_print_field( $writer, $key, $e );
		}
	}
	else {
		$writer->dataElement( 'field', $value, name => $key );
	}
	return;
}

sub _print_dates {
	my ($writer) = @_;
	$writer->startTag("dates");
	$writer->emptyTag( "date", type => 'creation',          value => $date );
	$writer->emptyTag( "date", type => 'last_modification', value => $date );
	$writer->endTag("dates");
	return;
}

sub _print_crossrefs {
	my ( $writer, $xrefs ) = @_;
	$writer->startTag("cross_references");
	while ( my ( $k, $v ) = each %$xrefs ) {
		if ( ref $v eq 'ARRAY' ) {
			for my $e ( sort @{$v} ) {
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
