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
	use_ok('Bio::EnsEMBL::Production::Search::VariationSolrFormatter');
}

my $genome_in_file = File::Spec->catfile( $Bin, "genome_test.json" );
my $genome = decode_json( read_file($genome_in_file) );
my $formatter = Bio::EnsEMBL::Production::Search::VariationSolrFormatter->new();

subtest "Variation reformat", sub {
	my $in_file  = File::Spec->catfile( $Bin, "variants_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_variants_test.json" );
	$formatter->reformat_variants( $in_file, $out_file, $genome, 'variation' );
	my $new_variations = decode_json( read_file($out_file) );
	{
		my ($var) = grep { $_->{id} eq 'rs7569578' } @$new_variations;
		is_deeply(
			$var, {
			   'species'          => 'homo_sapiens',
			   'species_name'     => 'Homo sapiens',
			   'reference_strain' => 0,
			   'hgvs_names'       => [ 'c.1881+3399G>A', 'n.99+25766C>T' ],
			   'domain_url'    => 'Homo_sapiens/Variation/Summary?v=rs7569578',
			   'id'            => 'rs7569578',
			   'ref_boost'     => 10,
			   'database_type' => 'variation',
			   'description' =>
'A dbSNP Variant. Gene Association(s): banana, mango. HGVS Name(s): c.1881+3399G>A, n.99+25766C>T.',
			   'db_boost' => 1,
			   'website'  => 'http://www.ensembl.org/',
			   'synonyms' => [ 'rs57302278',  'ss11455892',
							   'ss86053513',  'ss91145073',
							   'ss97034149',  'ss109467753',
							   'ss110190545', 'ss138435502',
							   'ss144054833', 'ss157002687',
							   'ss163387157', 'ss200374933',
							   'ss219215407', 'ss231145043',
							   'ss238705051', 'ss253077410',
							   'ss276448458', 'ss292259141',
							   'ss555526757', 'ss649111058' ],
			   'feature_type' => 'Variant' },
			"Gene-associated variant" );
	}
	{
		my ($var) = grep { $_->{id} eq 'rs2299222' } @$new_variations;
		is_deeply(
			$var, {
			   'species_name'     => 'Homo sapiens',
			   'ont_term'         => 'Achondroplasia',
			   'db_boost'         => 1,
			   'hgvs_names'       => undef,
			   'reference_strain' => 0,
			   'database_type'    => 'variation',
			   'synonyms'         => [
							   'rs17765152',  'rs60739517',
							   'ss3244399',   'ss24191327',
							   'ss67244375',  'ss67641327',
							   'ss68201979',  'ss70722711',
							   'ss71291243',  'ss74904288',
							   'ss84028050',  'ss153901677',
							   'ss155149228', 'ss159379485',
							   'ss173271751', 'ss241000819',
							   'ss279424575', 'ss537073959',
							   'ss654530936' ],
			   'website'    => 'http://www.ensembl.org/',
			   'species'    => 'homo_sapiens',
			   'domain_url' => 'Homo_sapiens/Variation/Summary?v=rs2299222',
			   'description' =>
'A dbSNP Variant. GWAS studies: NHGRI-EBI GWAS catalog. Phenotype(s): ACHONDROPLASIA. Phenotype ontologies: Achondroplasia.',
			   'ont_acc'      => 'OMIM:100800',
			   'id'           => 'rs2299222',
			   'feature_type' => 'Variant',
			   'ref_boost'    => 10 },
			"Variant with GWAS & phenotype" );
	}
	{
		my ($var) = grep { $_->{id} eq 'rs111067473' } @$new_variations;
		is_deeply(
			  $var, {
				'domain_url' => 'Homo_sapiens/Variation/Summary?v=rs111067473',
				'species_name'     => 'Homo sapiens',
				'database_type'    => 'variation',
				'db_boost'         => 1,
				'reference_strain' => 0,
				'ref_boost'        => 10,
				'feature_type'     => 'Variant',
				'species'          => 'homo_sapiens',
				'website'          => 'http://www.ensembl.org/',
				'description' =>
				  'A dbSNP Variant. Variant does not map to the genome',
				'id'       => 'rs111067473',
				'synonyms' => ['ss117978004'] },
			  "Failed variant" );

	}
	unlink $out_file;
};

subtest "Somatic Mutation test", sub {
	my $in_file  = File::Spec->catfile( $Bin, "variants_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_variants_test.json" );
	$formatter->reformat_somatic_variants( $in_file, $out_file, $genome,
										   'variation' );
	my $new_variations = decode_json( read_file($out_file) );
	is( scalar @{$new_variations}, 1, "1 somatic" );
	my ($var) = grep { $_->{id} eq 'COSM946275' } @$new_variations;
	is_deeply( $var, {
				 'reference_strain' => 0,
				 'ref_boost'        => 10,
				 'domain_url'  => 'Homo_sapiens/Variation/Summary?v=COSM946275',
				 'description' => 'A COSMIC Somatic Mutation.',
				 'species_name'  => 'Homo sapiens',
				 'id'            => 'COSM946275',
				 'feature_type'  => 'Variant',
				 'website'       => 'http://www.ensembl.org/',
				 'synonyms'      => ['ss0'],
				 'db_boost'      => 1,
				 'species'       => 'homo_sapiens',
				 'database_type' => 'variation' } );
	unlink $out_file;
};

subtest "Structural variants test", sub {
	my $in_file = File::Spec->catfile( $Bin, "structuralvariants_test.json" );
	my $out_file =
	  File::Spec->catfile( $Bin, "solr_structuralvariants_test.json" );
	$formatter->reformat_structural_variants( $in_file, $out_file, $genome,
											  'variation' );
	my $new_variations = decode_json( read_file($out_file) );
	is( scalar @{$new_variations}, 7, "7 SVs" );
	{
		my ($v) = grep { $_->{id} eq 'esv93078' } @$new_variations;
		is_deeply(
			$v, {
			   'database_type'       => 'variation',
			   'ref_boost'           => 10,
			   'reference_strain'    => 0,
			   'species'             => 'homo_sapiens',
			   'id'                  => 'esv93078',
			   'website'             => 'http://www.ensembl.org/',
			   'species_name'        => 'Homo sapiens',
			   'supporting_evidence' => [ 'essv194300', 'essv194301' ],
			   'db_boost'            => 1,
			   'description' =>
'A structural variation from DGVa, identified by Database of Genomic Variants Archive (estd59).',
			   'feature_type' => 'StructuralVariant',
			   'domain_url' =>
				 'Homo_sapiens/StructuralVariation/Explore?sv=esv93078' } );
	}
	{
		my ($v) = grep { $_->{id} eq 'CN_674347' } @$new_variations;
		is_deeply(
			$v, {
			   'species'          => 'homo_sapiens',
			   'reference_strain' => 0,
			   'id'               => 'CN_674347',
			   'ref_boost'        => 10,
			   'database_type'    => 'variation',
			   'domain_url' =>
				 'Homo_sapiens/StructuralVariation/Explore?sv=CN_674347',
			   'description' =>
'A structural variation from Affy GenomeWideSNP_6 CNV, identified by http://www.affymetrix.com/.',
			   'feature_type' => 'StructuralVariant',
			   'db_boost'     => 1,
			   'website'      => 'http://www.ensembl.org/',
			   'species_name' => 'Homo sapiens' } );
	}
	unlink $out_file;
};

subtest "Phenotype test", sub {
	my $in_file  = File::Spec->catfile( $Bin, "phenotypes_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_phenotypes_test.json" );
	$formatter->reformat_phenotypes( $in_file, $out_file, $genome,
									 'variation' );
	my $new_phenotypes = decode_json( read_file($out_file) );
	{
		my ($p) = grep { $_->{id} eq 2 } @$new_phenotypes;
		is_deeply( $p, {
					 'ref_boost'        => 10,
					 'website'          => 'http://www.ensembl.org/',
					 'database_type'    => 'variation',
					 'id'               => '2',
					 'description'      => 'COSMIC:tumour_site:skin',
					 'species_name'     => 'Homo sapiens',
					 'reference_strain' => 0,
					 'feature_type'     => 'Phenotype',
					 'domain_url' => 'Homo_sapiens/Phenotypes/Locations?ph=2',
					 'species'    => 'homo_sapiens',
					 'db_boost'   => 1 } );
	}
	{
		my ($p) = grep { $_->{id} eq 1 } @$new_phenotypes;
		is_deeply( $p, {
					 'name'               => 'ACH',
					 'description'        => 'ACHONDROPLASIA',
					 'id'                 => '1',
					 'database_type'      => 'variation',
					 'ontology_term'      => 'Achondroplasia',
					 'website'            => 'http://www.ensembl.org/',
					 'ontology_accession' => 'OMIM:100800',
					 'ref_boost'          => 10,
					 'db_boost'           => 1,
					 'ontology_name'      => 'OMIM',
					 'species'            => 'homo_sapiens',
					 'feature_type'       => 'Phenotype',
					 'reference_strain'   => 0,
					 'domain_url'   => 'Homo_sapiens/Phenotypes/Locations?ph=1',
					 'species_name' => 'Homo sapiens' } );
	}
	{
		my ($p) = grep { $_->{id} eq 17889 } @$new_phenotypes;
		is_deeply(
			$p,

			{  'species_name'     => 'Homo sapiens',
			   'reference_strain' => 0,
			   'feature_type'     => 'Phenotype',
			   'domain_url' => 'Homo_sapiens/Phenotypes/Locations?ph=17889',
			   'species'    => 'homo_sapiens',
			   'db_boost'   => 1,
			   'ref_boost'  => 10,
			   'ontology_accession' => 'EFO:0005193',
			   'id'                 => '17889',
			   'description'        => 'IgG glycosylation',
			   'website'            => 'http://www.ensembl.org/',
			   'database_type'      => 'variation' } );
	}
	unlink $out_file;
};
done_testing;
