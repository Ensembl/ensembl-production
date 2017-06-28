#!perl
# Copyright [2009-2017] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
use warnings;
use strict;

use Test::More;
use File::Slurp;
use JSON;
use FindBin qw( $Bin );
use File::Spec;
use Data::Dumper;

BEGIN {
	use_ok('Bio::EnsEMBL::Production::Search::SolrFormatter');
}

my $in_file        = File::Spec->catfile( $Bin, "genes_test.json" );
my $genome_in_file = File::Spec->catfile( $Bin, "genome_test.json" );
my $out_file       = File::Spec->catfile( $Bin, "solr_genes_test.json" );

my $genome = decode_json( read_file($genome_in_file) );

my $formatter = Bio::EnsEMBL::Production::Search::SolrFormatter->new();

subtest "Gene reformat", sub {
	$formatter->reformat_genes( $in_file, $out_file, $genome, 'core' );
	my $new_genes = decode_json( read_file($out_file) );

	is( 1, scalar(@$new_genes), "Checking correct number of genes" );
	my $new_gene = $new_genes->[0];
	is( 2,
		scalar( @{ $new_gene->{transcript} } ),
		"Checking correct number of transcripts" );
	is( 2,
		scalar( @{ $new_gene->{transcript_ver} } ),
		"Checking correct number of versioned transcripts" );
	is( 2, $new_gene->{transcript_count}, "Checking correct transcript count" );
	is( 1,
		scalar( @{ $new_gene->{peptide} } ),
		"Checking correct number of peptides" );
	is( 1,
		scalar( @{ $new_gene->{peptide_ver} } ),
		"Checking correct number of versioned peptides" );
	is( 4,
		scalar( @{ $new_gene->{exon} } ),
		"Checking correct number of exons" );
	is( 4, $new_gene->{exon_count}, "Checking correct exon count" );
	unlink $out_file;
};

subtest "Transcript reformat", sub {
	$formatter->reformat_transcripts( $in_file, $out_file, $genome, 'core' );
	my $new_transcripts = decode_json( read_file($out_file) );
	is( 2, scalar(@$new_transcripts),
		"Checking correct number of transcripts" );
	my $new_transcript = $new_transcripts->[0];
	is( 1,
		scalar( @{ $new_transcript->{peptide} } ),
		"Checking correct number of peptides" );
	is( 1,
		scalar( @{ $new_transcript->{peptide_ver} } ),
		"Checking correct number of versioned peptides" );
	is( 2,
		scalar( @{ $new_transcript->{exon} } ),
		"Checking correct number of exons" );
	is( 2, $new_transcript->{exon_count}, "Checking correct exon count" );
	is( 4,
		scalar( @{ $new_transcript->{prot_domain} } ),
		"Checking correct number of protein domains" );
	is( 2,
		scalar( grep { m/Interpro/ } @{ $new_transcript->{_hr} } ),
		"Checking number of Interpro HRs" );
	is( 2,
		scalar( grep { m/supporting evidence/ } @{ $new_transcript->{_hr} } ),
		"Checking number of supporting evidence HRs" );
};

subtest "ID reformat", sub {
	$formatter->reformat_ids( File::Spec->catfile( $Bin, "ids_test.json" ),
							  $out_file, $genome, 'core' );
	my $new_ids = decode_json( read_file($out_file) );
	is( 6, scalar(@$new_ids), "Checking correct number of IDs" );
	my ($curr_only) = grep { $_->{id} eq 'bananag' } @$new_ids;
	diag( Dumper($curr_only) );
	is( $curr_only->{description},
"Ensembl Gene bananag is no longer in the database and has been mapped to 1 current identifier (e.g. ENSG00000204704)"
	);
	my ($dep_only) = grep { $_->{id} eq 'lychee' } @$new_ids;
	diag( Dumper($dep_only) );
	is( $dep_only->{description},
"Ensembl Gene lychee is no longer in the database and has been mapped to 1 deprecated identifier"
	);
	my ($both) = grep { $_->{id} eq 'loganberry' } @$new_ids;
	diag( Dumper($both) );
	is( $both->{description},
"Ensembl Transcript loganberry is no longer in the database and has been mapped to 1 current identifier (e.g. raspberry) and 1 deprecated identifier"
	);
};

subtest "Sequence reformat", sub {
	$formatter->reformat_sequences( File::Spec->catfile(
													 $Bin, "sequences_test.json"
									),
									$out_file,
									$genome, 'core' );
	my $new_seqs = decode_json( read_file($out_file) );
	is( 3, scalar(@$new_seqs), "Checking correct number of seqs" );
	{
		my ($e) = grep { $_->{id} eq '7270026' } @$new_seqs;
		diag( Dumper($e) );
		is( $e->{feature_type}, 'Sequence' );
		is( $e->{description},
"Tilepath 7270026 (length 181259 bp) is mapped to chromosome 12. It has synonyms of AC079953.28, FinishAc, tilepath."
		);
		is( $e->{domain_url},
			"Homo_sapiens/Location/View?r=7270026:1-181259&amp;db=core" );
	}

	{
		my ($e) = grep { $_->{id} eq 'X' } @$new_seqs;
		diag( Dumper($e) );
		is( $e->{feature_type}, 'Sequence' );
		is( $e->{description},
"Chromosome X (length 156040895 bp). It has synonyms of CM000685.2, chrX, NC_000023.11."
		);
		is( $e->{domain_url},
			"Homo_sapiens/Location/View?r=X:1-156040895&amp;db=core" );
	}

	{
		my ($e) = grep { $_->{id} eq 'DAAF01080952.1' } @$new_seqs;
		diag( Dumper($e) );
		is( $e->{feature_type}, 'Sequence' );
		is( $e->{description},  "Contig DAAF01080952.1 (length 171 bp)" );
		is( $e->{domain_url},
			"Homo_sapiens/Location/View?r=DAAF01080952.1:1-171&amp;db=core" );
	}
};
subtest "LRGs reformat", sub {
	$formatter->reformat_lrgs( File::Spec->catfile( $Bin, "lrgs_test.json" ),
							   $out_file, $genome, 'core' );
	my $new_lrgs = decode_json( read_file($out_file) );
	is( scalar(@$new_lrgs), 4, "Checking correct number of lrgs" );
	my ($e) = grep { $_->{id} eq 'LRG_22' } @$new_lrgs;
	diag( Dumper($e) );
	is( $e->{feature_type}, 'Sequence' );
	is( $e->{description},
"LRG_22 is a fixed reference sequence of length 10058 with a fixed transcript(s) for reporting purposes. It was created for HGNC gene C1QA."
	);
	is( $e->{domain_url}, "Homo_sapiens/LRG/Summary?lrg=LRG_22&amp;db=core" );

};
subtest "Markers reformat", sub {
	$formatter->reformat_markers( File::Spec->catfile( $Bin, "markers_test.json"
								  ),
								  $out_file,
								  $genome, 'core' );
	my $new_markers = decode_json( read_file($out_file) );
	is( scalar(@$new_markers), 3, "Checking correct number of markers" );
	{
		my ($e) = grep { $_->{id} eq '58017' } @$new_markers;
		diag( Dumper($e) );
		is( $e->{feature_type},            'Marker' );
		is( scalar( @{ $e->{synonyms} } ), 2 );
		is( $e->{domain_url}, "Homo_sapiens/Marker/Details?m=58017" );
	}
	{
		my ($e) = grep { $_->{id} eq '44919' } @$new_markers;
		diag( Dumper($e) );
		is( $e->{feature_type},            'Marker' );
		is( scalar( @{ $e->{synonyms} } ), 1 );
		is( $e->{domain_url}, "Homo_sapiens/Marker/Details?m=44919" );
	}
	{
		my ($e) = grep { $_->{id} eq '127219' } @$new_markers;
		diag( Dumper($e) );
		is( $e->{feature_type},            'Marker' );
		ok(!defined $e->{synonyms});
		is( $e->{domain_url}, "Homo_sapiens/Marker/Details?m=127219" );
	}
};

done_testing;
