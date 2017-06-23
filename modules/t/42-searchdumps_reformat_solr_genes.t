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
		scalar( grep { m/Interpro/ } @{$new_transcript->{_hr}} ),
		"Checking number of Interpro HRs" );
	is( 2,
		scalar( grep { m/supporting evidence/ } @{$new_transcript->{_hr}} ),
		"Checking number of supporting evidence HRs" );
};

done_testing;
