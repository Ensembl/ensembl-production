
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

=cut

package Bio::EnsEMBL::Production::Search::GenomeSolrFormatter;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use List::MoreUtils qw/natatime/;

use Bio::EnsEMBL::Production::Search::JSONReformatter;
use Bio::EnsEMBL::Production::Search::SolrFormatter;

use JSON;
use Carp;
use File::Slurp;

use base qw/Bio::EnsEMBL::Production::Search::SolrFormatter/;
sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  return $self;
}

sub reformat_genes {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'core';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($gene)          = @_;
			my $transcripts     = [];
			my $transcripts_ver = [];
			my $peptides        = [];
			my $peptides_ver    = [];
			my $exons           = {};
			my $xrefs           = {};
			my $hr              = [];
			$self->_add_xrefs( $gene, 'Gene', $xrefs, $hr );

			for my $transcript ( @{ $gene->{transcripts} } ) {
				$self->_add_xrefs( $transcript, 'Transcript', $xrefs, $hr );
				push @$transcripts,     $transcript->{id};
				push @$transcripts_ver, _id_ver($transcript);
				if ( defined $transcript->{translations} ) {
					for my $translation ( @{ $transcript->{translations} } ) {
						$self->_add_xrefs( $translation, 'Translation', $xrefs, $hr );
						push @$peptides,     $translation->{id};
						push @$peptides_ver, _id_ver($translation);
					}
				}
				for my $exon ( @{ $transcript->{exons} } ) {
					$exons->{ $exon->{id} }++;
				}
			}

			return { %{ _base( $genome, $type, 'Gene' ) },
					 id                => $gene->{id},
					 id_ver            => _id_ver($gene),
					 name              => $gene->{name},
					 description       => $gene->{description},
					 _hr               => $hr,
					 xrefs             => join( ' ', keys %$xrefs ),
					 name_synonym      => $gene->{synonyms} || [],
					 transcript_count  => scalar(@$transcripts),
					 transcript        => $transcripts,
					 transcript_ver    => $transcripts_ver,
					 translation_count => scalar(@$peptides),
					 peptide           => $peptides,
					 peptide_ver       => $peptides_ver,
					 exon_count        => scalar( keys %$exons ),
					 exon              => [ keys %$exons ],
					 location          => sprintf( "%s:%d-%d:%d",
									   $gene->{seq_region_name}, $gene->{start},
									   $gene->{end}, $gene->{strand} ),
					 source => $gene->{analysis},
					 domain_url =>
					   sprintf( "%s/Gene/Summary?g=%s&amp;db=%s",
								$genome->{organism}->{url_name}, $gene->{id},
								$type ) };
		} );
	return;
} ## end sub reformat_genes

sub reformat_transcripts {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'core';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($gene) = @_;
			my $transcripts = [];
			for my $transcript ( @{ $gene->{transcripts} } ) {

				my $peptides     = [];
				my $peptides_ver = [];
				my $exons        = {};
				my $xrefs        = {};
				my $hr           = [];
				my $pfs          = [];

				$self->_add_xrefs( $transcript, 'Transcript', $xrefs, $hr );
				if ( defined $transcript->{translations} ) {

					for my $translation ( @{ $transcript->{translations} } ) {
						$self->_add_xrefs( $translation, 'Translation', $xrefs, $hr );
						push @$peptides,     $translation->{id};
						push @$peptides_ver, _id_ver($translation);
						my $interpro = {};
						for my $pf ( @{ $translation->{protein_features} } ) {
							push @$pfs, $pf->{name};
							if ( defined $pf->{interpro_ac} ) {
								push @{ $interpro->{ $pf->{interpro_ac} } },
								  $pf->{name};
							}
						}
						while ( my ( $ac, $ids ) = each %$interpro ) {
							push @$hr,
							  sprintf(
"Interpro domain %s with %d records from signature databases (%s) is found on Translation %s",
								$ac, scalar(@$ids), join( ', ', @$ids ),
								$translation->{id} );
							push @$pfs, $ac;
						}

					}
				} ## end if ( defined $transcript...)
				for my $exon ( @{ $transcript->{exons} } ) {
					$exons->{ $exon->{id} }++;
				}
				if ( defined $transcript->{supporting_evidence} ) {
					for my $evidence ( @{ $transcript->{supporting_evidence} } )
					{
						push @$hr,
						  sprintf(
"%s (%s) is used as supporting evidence for transcript %s",
							$evidence->{id}, $evidence->{db_display_name},
							$transcript->{id} );
					}
				}

				push @$transcripts, {
					%{ _base( $genome, $type, 'Transcript' ) },
					id                => $transcript->{id},
					id_ver            => _id_ver($transcript),
					name              => $transcript->{name},
					description       => $transcript->{description},
					_hr               => $hr,
					xrefs             => join( ' ', keys %$xrefs ),
					name_synonym      => $transcript->{synonyms} || [],
					translation_count => scalar(@$peptides),
					peptide           => $peptides,
					peptide_ver       => $peptides_ver,
					prot_domain       => $pfs,
					exon_count        => scalar( keys %$exons ),
					exon              => [ keys %$exons ],
					location          => sprintf( "%s:%d-%d:%d",
						   $transcript->{seq_region_name}, $transcript->{start},
						   $transcript->{end}, $transcript->{strand} ),
					source => $gene->{analysis},
					domain_url =>
					  sprintf( "%s/Transcript/Summary?g=%s&amp;db=%s",
							   $genome->{organism}->{url_name},
							   $transcript->{id},
							   $type ) };

			} ## end for my $transcript ( @{...})
			return $transcripts;
		} );
	return;
} ## end sub reformat_transcripts

sub reformat_ids {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;

	$type ||= 'core';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($id) = @_;

			my $desc = sprintf( "Ensembl %s %s is no longer in the database",
								ucfirst( $id->{type} ), $id->{id} );
			my $deprecated_id_c =
			  _array_nonempty( $id->{deprecated_mappings} ) ?
			  scalar( @{ $id->{deprecated_mappings} } ) :
			  0;
			my $current_id_c =
			  _array_nonempty( $id->{current_mappings} ) ?
			  scalar( @{ $id->{current_mappings} } ) :
			  0;

			my $dep_txt  = '';
			my $curr_txt = '';
			if ( $deprecated_id_c > 0 ) {
				$dep_txt =
				  $deprecated_id_c > 1 ?
				  "$deprecated_id_c deprecated identifiers" :
				  "$deprecated_id_c deprecated identifier";
			}
			if ( $current_id_c > 0 ) {
				my $example_id = $id->{current_mappings}->[0];
				$curr_txt =
				  $current_id_c > 1 ? "$current_id_c current identifiers" :
				                      "$current_id_c current identifier";
				$curr_txt .= $example_id ? " (e.g. $example_id)" : '';
			}
			if ( $current_id_c > 0 && $deprecated_id_c > 0 ) {
				$desc .= " and has been mapped to $curr_txt and $dep_txt";
			}
			elsif ( $current_id_c > 0 && $deprecated_id_c == 0 ) {
				$desc .= " and has been mapped to $curr_txt";
			}
			elsif ( $current_id_c == 0 && $deprecated_id_c > 0 ) {
				$desc .= " and has been mapped to $dep_txt";
			}
			else {
				$desc .= ' and has not been mapped to any newer identifiers.';
			}
			return { %{ _base( $genome, $type, ucfirst( $id->{type} ) ) },
					 id          => $id->{id},
					 description => $desc,
					 domain_url =>
					   sprintf( "%s/%s/?g=%s&amp;db=%s",
								$genome->{organism}->{url_name},
								ucfirst( $id->{type} ),
								$id->{id}, $type ) };
		} );

	return;
} ## end sub reformat_ids

sub reformat_sequences {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;

	$type ||= 'core';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($seq) = @_;
			my $desc = sprintf( '%s %s (length %d bp)',
								ucfirst( $seq->{type} ),
								$seq->{id}, $seq->{length} );
			if ( defined $seq->{parent} ) {
				$desc = sprintf( "%s is mapped to %s %s",
								 $desc, $seq->{parent_type}, $seq->{parent} );
			}
			if ( _array_nonempty( $seq->{synonyms} ) ) {
				$desc .= '. It has synonyms of ' .
				  join( ', ', @{ $seq->{synonyms} } ) . '.';
			}
			return { %{ _base( $genome, $type, 'Sequence' ) },
					 id          => $seq->{id},
					 description => $desc,
					 domain_url =>
					   sprintf( "%s/Location/View?r=%s:%d-%d&amp;db=%s",
								$genome->{organism}->{url_name},
								$seq->{id}, 1, $seq->{length}, $type ) };
		} );

	return;
} ## end sub reformat_sequences

sub reformat_lrgs {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'core';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($lrg) = @_;
			return {
				%{ _base( $genome, $type, 'Sequence' ) },
				id => $lrg->{id},
				description =>
				  sprintf(
'%s is a fixed reference sequence of length %d with a fixed transcript(s) for reporting purposes. It was created for %s gene %s.',
					$lrg->{id},              $lrg->{length},
					$lrg->{source_database}, $lrg->{source_gene} ),
				domain_url => sprintf( "%s/LRG/Summary?lrg=%s&amp;db=%s",
									   $genome->{organism}->{url_name},
									   $lrg->{id}, $type ) };
		} );

	return;
}

sub reformat_markers {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'core';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($marker) = @_;
			my $m = { %{ _base( $genome, $type, 'Marker' ) },
					  contigviewbottom => 'marker_core_marker=normal',
					  id               => $marker->{id},
					  domain_url =>
						sprintf( "%s/Marker/Details?m=%s",
								 $genome->{organism}->{url_name},
								 $marker->{id} ) };
			$m->{synonyms} = $marker->{synonyms}
			  if _array_nonempty( $marker->{synonyms} );
			return $m;
		} );

	return;
}

sub reformat_domains {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	my $ipr = {};
	process_json_file(
		$infile,
		sub {
			my ($gene) = @_;
			for my $transcript ( @{ $gene->{transcripts} } ) {
				if ( defined $transcript->{translations} ) {
					for my $translation ( @{ $transcript->{translations} } ) {
						for my $pf ( grep { defined $_->{interpro_ac} }
									 @{ $translation->{protein_features} } )
						{
							my $i = $ipr->{ $pf->{interpro_ac} };
							if ( !defined $i ) {
								$i = { id => $pf->{interpro_ac} };
								$i->{interpro_description} =
								  $pf->{interpro_description}
								  if defined $pf->{interpro_description};
								$ipr->{ $pf->{interpro_ac} } = $i;
							}
							$i->{genes}{ $gene->{id} }++;
							$i->{ids}{ $pf->{name} }++;
						}
					}
				}
			}
			return;
		} );

	my $ds = [];
	for my $i ( values %{$ipr} ) {

		my $desc =
		  defined $i->{interpro_description} ?
		  " [" . $i->{interpro_description} . "]" :
		  '';

		my $ids = [ keys %{ $i->{ids} } ];
		push @$ds, {
			%{ _base( $genome, $type, 'Domain' ) },
			id          => $i->{id},
			synonyms    => $ids,
			description => sprintf(
"Interpro domain %s%s is found in %d genes in Human and has %d records from signature databases: %s",
				$i->{id},                        $desc,
				scalar( keys %{ $i->{genes} } ), scalar(@$ids),
				join( ", ", @$ids ) ),
			domain_url => sprintf( "%s/Location/Genome?ftype=Domain;id=%s",
								   $genome->{organism}->{url_name},
								   $i->{id} ) };
	}
	open my $fh, ">", $outfile or die "Could not open $outfile for writing";
	print $fh encode_json($ds);
	close $fh;
	return;
} ## end sub reformat_domains

sub reformat_gene_families {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'compara';
	my $families = {};
	process_json_file(
		$infile,
		sub {
			my ($gene) = @_;
			for my $transcript ( @{ $gene->{transcripts} } ) {
				if ( defined $transcript->{translations} ) {
					for my $translation ( @{ $transcript->{translations} } ) {
						if ( defined $translation->{families} ) {
							for my $family ( @{ $translation->{families} } ) {
								my $f = $families->{ $family->{stable_id} };
								if ( !defined $f ) {
									$f = { id          => $family->{stable_id},
										   description => $family->{description}
									};
									$families->{ $family->{stable_id} } = $f;
								}
								$f->{genes}->{ $gene->{id} }++;
								if ( defined $gene->{name} ) {
									$f->{gene_names}->{ $gene->{name} }++;
								}
								$f->{transcripts}->{ $transcript->{id} }++;
								$f->{translations}->{ $translation->{id} }++;
							}

						}
					}
				}
			}
			return;
		} );

	my $ds = [];
	for my $f ( values %{$families} ) {
		my $genes       = [ keys %{ $f->{genes} } ];
		my $gene_names  = [ keys %{ $f->{gene_names} } ];
		my $transcripts = [ keys %{ $f->{transcripts} } ];
		my $proteins    = [ keys %{ $f->{translations} } ];
		push @$ds, {
			%{ _base( $genome, $type, 'Family' ) },
			id                => $f->{id},
			name              => $f->{id},
			assoc_genes       => $genes,
			assoc_gene_names  => $gene_names,
			assoc_transcripts => $transcripts,
			assoc_proteins    => $proteins,
			description       => sprintf(
					"Ensembl protein family %s%s: %d gene / %d proteins in %s",
					$f->{id},
					defined $f->{description} ? ' [' . $f->{description} . ']' :
					  '',
					scalar @$genes,
					scalar @$proteins,
					$genome->{organism}->{display_name} ),
			domain_url => sprintf( "%s/Location/Gene?ftype=Family=%s;g=%s",
								   $genome->{organism}->{url_name}, $f->{id},
								   $genes->[0] ) };
	} ## end for my $f ( values %{$families...})
	open my $fh, ">", $outfile or die "Could not open $outfile for writing";
	print $fh encode_json($ds);
	close $fh;

	return;
} ## end sub reformat_gene_families

sub reformat_gene_trees {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'compara';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($gene) = @_;
			my $id_str = $gene->{id};
			if ( defined $gene->{name} ) {
				$id_str = $gene->{name} . " ($id_str}";
			}
			my $docs = {};
			for my $homolog ( @{ $gene->{homologues} } ) {
				next unless defined $homolog->{gene_tree_id}; # ncrna gene trees have no stable IDs
				my $doc = $docs->{ $homolog->{gene_tree_id} };
				if ( !defined $doc ) {

					my $gt = { %{ _base( $genome, $type, 'GeneTree' ) },
							   id         => $homolog->{gene_tree_id},
							   assoc_gene => $gene->{id},
							   description =>
								 sprintf( "Gene %s is a member of GeneTree %s",
										  $id_str, $homolog->{gene_tree_id} ),
							   domain_url =>
								 sprintf( "%s/Gene/Compara_Tree?g=%s",
										  $genome->{organism}->{url_name},
										  $gene->{id} ) };
					$gt->{assoc_gene_name} = $gene->{name}
					  if defined $gene->{name};
					$docs->{ $homolog->{gene_tree_id} } = $gt;
				}
			}
			return [ values %$docs ];
		} );

	return;
} ## end sub reformat_gene_trees

sub _hr {
	my ( $self, $obj, $type, $xref ) = @_;
# <field name="_hr">R-HSA-1643685 (Reactome record; description: Disease&#44;) is an external reference matched to Translation ENSP00000360644</field>
	my $d = $xref->{display_id};
	if ( defined $xref->{description} ) {
		$d .= ' record; description: ' . $xref->{description};
	}
	my $s = sprintf( '%s (%s) is an external reference matched to %s %s',
					 $xref->{display_id}, $d, $type, $obj->{id} );
	if ( defined $xref->{synonyms} && scalar( @{ $xref->{synonyms} } ) > 0 ) {
		$s .= ", with synonym(s) of " . join( ', ', @{ $xref->{synonyms} } );
	}
	return $s;
}

sub _add_xrefs {
# xrefs is a hash to support listing all unique identifiers for a record that can then be emitted as a string
	my ( $self, $obj, $type, $xrefs, $hr ) = @_;
	for my $xref ( @{ $obj->{xrefs} } ) {
		# skip xrefs where the ID is the same as the stable ID or display xref
		next if ( $xref->{primary_id} eq $obj->{id} );
		next if ( defined $obj->{name} && $xref->{display_id} eq $obj->{name} );
		$xrefs->{ $xref->{primary_id} }++;
		$xrefs->{ $xref->{display_id} }++;
		$xrefs->{ $xref->{description} }++ if defined $xref->{description};
		if ( defined $xref->{synonyms} ) {
			for my $syn ( @{ $xref->{synonyms} } ) {
				$xrefs->{$syn}++;
			}
		}
		push @$hr, $self->_hr( $obj, $type, $xref );
	}
	return;
}

1;
