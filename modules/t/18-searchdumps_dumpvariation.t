#!perl
# Copyright [2009-2018] EMBL-European Bioinformatics Institute
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
use Test::More;

BEGIN {
	use_ok('Bio::EnsEMBL::Production::Search::VariationFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

use Bio::EnsEMBL::Production::Search::VariationFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;
use Log::Log4perl qw/:easy/;

Log::Log4perl->easy_init($DEBUG);

my $test_onto = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $onto_dba  = $test_onto->get_DBAdaptor('ontology');

my $test    = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens_dump');
my $dba     = $test->get_DBAdaptor('variation');
my $fetcher = Bio::EnsEMBL::Production::Search::VariationFetcher->new();

subtest "Testing variant fetching", sub {
	my $out = $fetcher->fetch_variations_for_dba( $dba, $onto_dba );
	is( scalar(@$out), 899, "Testing correct numbers of variants" );
	my @som = grep { $_->{somatic} eq 'false' } @{$out};
	is( scalar(@som), 898, "Testing correct numbers of non-somatic variants" );
	{
		my ($var) = grep { $_->{id} eq 'rs7569578' } @som;
		is_deeply(
			  $var, {
				'id'         => 'rs7569578',
				'hgvs'       => [ 'c.1881+3399G>A', 'n.99+25766C>T' ],
				'gene_names' => [ 'banana', 'mango' ],
				'source'     => { 'name' => 'dbSNP', 'version' => '138' },
				'locations'  => [ {
					   'seq_region_name' => '2',
					   'start'           => '45411130',
					   'strand'          => '1',
					   'end'             => '45411130',
					   'consequences'    => [ {
							  'consequence' =>
								'non_coding_transcript_variant,intron_variant',
							  'stable_id' => 'ENST00000427020' } ] } ],
				'synonyms' => [ { 'name'   => 'rs57302278',
								  'source' => { 'name'    => 'Archive dbSNP',
												'version' => '138' } }, {
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss11455892' }, {
								  'name' => 'ss86053513',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
								{ 'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss91145073' }, {
								  'name' => 'ss97034149',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
								{ 'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss109467753' }, {
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss110190545' }, {
								  'name' => 'ss138435502',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
								{ 'name' => 'ss144054833',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
								{ 'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss157002687' }, {
								  'name' => 'ss163387157',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
								{ 'name' => 'ss200374933',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
								{ 'name' => 'ss219215407',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
								{ 'name' => 'ss231145043',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
								{ 'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss238705051' }, {
								  'name' => 'ss253077410',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
								{ 'name' => 'ss276448458',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
								{ 'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss292259141' }, {
								  'name' => 'ss555526757',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
								{ 'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss649111058' } ],
				'somatic' => 'false' },
			  'Testing variation with consequences and gene names' );
	}
	{
		my ($var) = grep { $_->{id} eq 'rs2299222' } @som;
		is_deeply(
			$var, {
			   'id'        => 'rs2299222',
			   'source'    => { 'version' => '138', 'name' => 'dbSNP' },
			   'somatic'   => 'false',
			   'locations' => [ { 'start'           => '86442404',
								  'strand'          => '1',
								  'end'             => '86442404',
								  'seq_region_name' => '7' } ],
			   'synonyms' => [ {  'source' => { 'version' => '138',
												'name'    => 'Archive dbSNP' },
								  'name' => 'rs17765152' }, {
								  'name'   => 'rs60739517',
								  'source' => { 'name'    => 'Archive dbSNP',
												'version' => '138' } }, {
								  'name' => 'ss3244399',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
							   {  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss24191327' }, {
								  'name' => 'ss67244375',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
							   {  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss67641327' }, {
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss68201979' }, {
								  'name' => 'ss70722711',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
							   {  'name' => 'ss71291243',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
							   {  'name' => 'ss74904288',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
							   {  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss84028050' }, {
								  'name' => 'ss153901677',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
							   {  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss155149228' }, {
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss159379485' }, {
								  'name' => 'ss173271751',
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' } },
							   {  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss241000819' }, {
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss279424575' }, {
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss537073959' }, {
								  'source' =>
									{ 'name' => 'dbSNP', 'version' => '138' },
								  'name' => 'ss654530936' } ],
			   'gwas'       => ['NHGRI-EBI GWAS catalog'],
			   'phenotypes' => [ {
					  'study' => {
						  'name' =>
'Redon 2006 "Global variation in copy number in the human genome." PMID:17122850 [remapped from build NCBI35]',
						  'description'        => 'Control Set',
						  'type'               => undef,
						  'associated_studies' => [ {
								  'type' => undef,
								  'name' =>
									'Test study for the associate_study table',
								  'description' => undef } ] },
					  'ontology_accession' => 'OMIM:100800',
					  'ontology_term'      => 'Achondroplasia',
					  'ontology_name'      => 'OMIM',
					  'description'        => 'ACHONDROPLASIA',
					  'id'                 => 1,
					  'name'               => 'ACH',
					  'source' => { 'name' => 'dbSNP', 'version' => '138' } } ]
			},
			"Testing variation with phenotypes" );
	}
};
subtest "Testing SV fetching", sub {
	my $out = $fetcher->fetch_structural_variations_for_dba($dba);
	is( @{$out}, 7, "Expected number of SVs" );
	{
		my ($v) = grep { $_->{id} eq 'esv93078' } @{$out};
		is_deeply(
			   $v, {
				 'source'              => 'DGVa',
				 'seq_region_name'     => '8',
				 'start'               => '7823440',
				 'id'                  => 'esv93078',
				 'end'                 => '8819373',
				 'supporting_evidence' => [ 'essv194300','essv194301' ],
				 'study'               => 'estd59',
				 'source_description'  => 'Database of Genomic Variants Archive'
			   },
			   "Expected evidenced SV" )
	}
	{
		my ($v) = grep { $_->{id} eq 'CN_674347' } @{$out};
		is_deeply( $v, {
					  'source_description' => 'http://www.affymetrix.com/',
					  'end'                => '27793771',
					  'id'                 => 'CN_674347',
					  'start'              => '27793747',
					  'seq_region_name'    => '18',
					  'source'             => 'Affy GenomeWideSNP_6 CNV' },
				   "Expected evidence-less SV" )
	}
};

subtest "Testing phenotype fetching", sub {
	my $out = $fetcher->fetch_phenotypes_for_dba( $dba, $onto_dba );
	is( scalar( @{$out} ), 3, "Correct number of phenotypes" );
	my ($ph) = grep { defined $_->{name} && $_->{name} eq 'ACH' } @{$out};
	is_deeply( $ph, {
				  'id'                 => 1,
				  'name'               => 'ACH',
				  'ontology_term'      => 'Achondroplasia',
				  'ontology_name'      => 'OMIM',
				  'ontology_accession' => 'OMIM:100800',
				  'description'        => 'ACHONDROPLASIA' } );
};

done_testing;
