#!perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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
# limitations under the License

use Test::More;
use File::Slurp;
use FindBin qw( $Bin );
use JSON;
use XML::Simple;
use Log::Log4perl qw/:easy/;
Log::Log4perl->easy_init($DEBUG);

BEGIN {
	use_ok('Bio::EnsEMBL::Production::Search::EBeyeFormatter');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

my $genome_in_file = File::Spec->catfile( $Bin, "genome_test.json" );
my $formatter = Bio::EnsEMBL::Production::Search::EBeyeFormatter->new();
subtest "EBEye genome", sub {
	my $out_file = File::Spec->catfile( $Bin, "ebeye_genome_test.xml" );
	$formatter->reformat_genome( $genome_in_file, $out_file );
	my $genome = XMLin( $out_file, ForceArray => 1 );
	my $genome_expected = XMLin( $out_file . '.expected', ForceArray => 1 );
	is_deeply( $genome, $genome_expected, "Testing structure" );
	unlink $out_file;
};

subtest "EBEye genes", sub {
	my $in_file  = File::Spec->catfile( $Bin, "genes_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "ebeye_genes_test.xml" );
	$formatter->reformat_genes( $genome_in_file, 'homo_sapiens_core_97_38', $in_file, $out_file );
	my $genes = XMLin( $out_file, ForceArray => 1 );
	for my $entry (@{$genes->{entries}}) {
		$entry->{entry}[0]{cross_references}[0]{ref} = [sort {$a->{dbkey} cmp $b->{dbkey}} @{$entry->{entry}[0]{cross_references}[0]{ref}}];
	}
	my $genes_expected = XMLin( $out_file . '.expected', ForceArray => 1 );
		for my $entry (@{$genes_expected->{entries}}) {
		$entry->{entry}[0]{cross_references}[0]{ref} = [sort {$a->{dbkey} cmp $b->{dbkey}} @{$entry->{entry}[0]{cross_references}[0]{ref}}];
	}
	is_deeply( $genes, $genes_expected, "Testing structure" );
	unlink $out_file;
};
subtest "EBEye sequences", sub {
	my $in_file  = File::Spec->catfile( $Bin, "sequences_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "ebeye_sequences_test.xml" );
	$formatter->reformat_sequences( $genome_in_file, 'homo_sapiens_core_97_38', $in_file, $out_file );
	my $seqs = XMLin( $out_file, ForceArray => 1 );
	my $seqs_expected = XMLin( $out_file . '.expected', ForceArray => 1 );
	is_deeply( $seqs, $seqs_expected, "Testing structure" );
	unlink $out_file;
};
subtest "EBEye variants", sub {
	my $in_file  = File::Spec->catfile( $Bin, "variants_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "ebeye_variants_test.xml" );
	$formatter->reformat_variants( $genome_in_file, 'homo_sapiens_variation_97_38', $in_file, $out_file );
	my $vars = XMLin( $out_file, ForceArray => 1 );
	my $vars_expected = XMLin( $out_file . '.expected', ForceArray => 1 );
	is_deeply( $vars, $vars_expected, "Testing structure" );
	unlink $out_file;
};
done_testing;
