=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Search::VariationSolrFormatter;

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
	my ( $class, @args ) = @_;
	my $self = $class->SUPER::new(@args);
	return $self;
}

sub reformat_variants {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$self->_reformat_variants( $infile, $outfile, $genome, $type, 0 );
	return;
}

sub reformat_somatic_variants {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$self->_reformat_variants( $infile, $outfile, $genome, $type, 1 );
	return;
}

sub reformat_phenotypes {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'variation';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($p) = @_;
			my $p2 = { %{ _base( $genome, $type, 'Phenotype' ) },
					   %{$p},
					   domain_url =>
						 sprintf( '%s/Phenotypes/Locations?ph=%s',
								  $genome->{organism}->{url_name},
								  $p->{id} ) };
			return $p2;
		} );
	return;
}

sub _reformat_variants {
	my ( $self, $infile, $outfile, $genome, $type, $somatic ) = @_;
	$type ||= 'variation';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($v) = @_;
			if ($somatic) {
				return undef if ( $v->{somatic} eq 'false' );
			}
			else {
				return undef if ( $v->{somatic} eq 'true' );
			}
			my $v2 = { %{ _base( $genome, $type, 'Variant' ) },
					   id => $v->{id},
					   domain_url =>
						 sprintf( '%s/Variation/Summary?v=%s',
								  $genome->{organism}->{url_name},
								  $v->{id} ) };
			$v2->{description} = sprintf( "A %s %s.",
				$v->{source}{name}, $somatic ? 'Somatic Mutation' : 'Variant' );

			if ( _array_nonempty( $v->{synonyms} ) ) {
				for my $syn ( @{ $v->{synonyms} } ) {
					push @{ $v2->{synonyms} }, $syn->{name};
				}
			}
			if ( _array_nonempty( $v->{gene_names} ) ) {
				$v2->{description} .=
				  sprintf( " Gene Association(s): %s.",
						   join( ", ", @{ $v->{gene_names} } ) );
			}
			if ( _array_nonempty( $v->{hgvs} ) ) {
				$v2->{hgvs_names} = $v->{hgvs};
				$v2->{description} .=
				  sprintf( " HGVS Name(s): %s.",
						   join( ", ", @{ $v2->{hgvs_names} } ) );
			}
			if ( _array_nonempty( $v->{gwas} ) ) {
				$v2->{hgvs_names} = $v->{hgvs};
				$v2->{description} .=
				  sprintf( " GWAS studies: %s.",
						   join( ", ", @{ $v->{gwas} } ) );
			}
			if ( _array_nonempty( $v->{phenotypes} ) ) {
				my $onto  = [];
				my $pdesc = [];
				for my $phenotype ( @{ $v->{phenotypes} } ) {
					push @$onto, $phenotype->{ontology_term}
					  if defined $phenotype->{ontology_term};
					my $nom = $phenotype->{description} || $phenotype->{name};
					push @$pdesc, $nom;
					$v2->{ont_acc} = $phenotype->{ontology_accession}
					  if defined $phenotype->{ontology_accession};
					$v2->{ont_term} = $phenotype->{ontology_term}
					  if defined $phenotype->{ontology_accession};
					$v2->{ont_syn} = $phenotype->{ontology_synonyms}
					  if _array_nonempty( $phenotype->{ontology_synonyms} );
				}
				$v2->{description} .=
				  sprintf( " Phenotype(s): %s.", join( ', ', @$pdesc ) );
				$v2->{description} .=
				  sprintf( " Phenotype ontologies: %s.", join( ', ', @$onto ) )
				  if @$onto;
			}
			if ( _array_nonempty( $v->{failures} ) ) {
				$v2->{description} .= ' ' . join( '. ', @{ $v->{failures} } );
			}
			return $v2;
		} );
	return;
} ## end sub _reformat_variants

sub reformat_structural_variants {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'variation';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($v) = @_;
			$type ||= 'variation';
			my $v2 = {
				%{ _base( $genome, $type, 'StructuralVariant' ) },
				id => $v->{id},
				description =>
				  sprintf("A structural variation from %s, identified by %s%s.",
						  $v->{source},
						  $v->{source_description},
						  defined $v->{study} ? " ($v->{study})" : '' ),
				domain_url => sprintf( '%s/StructuralVariation/Explore?sv=%s',
									   $genome->{organism}->{url_name},
									   $v->{id} ) };
									   
			$v2->{supporting_evidence} = $v->{supporting_evidence}
			  if _array_nonempty( $v->{supporting_evidence} );

			return $v2;
		} );
	return;
} ## end sub reformat_structural_variants

1;
