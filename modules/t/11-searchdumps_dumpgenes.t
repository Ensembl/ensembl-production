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

use Test::More;

BEGIN {
	use_ok('Bio::EnsEMBL::Production::Search::GeneFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

use Bio::EnsEMBL::Production::Search::GeneFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;

my $test        = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens_dump');
my $core_dba    = $test->get_DBAdaptor('core');
my $funcgen_dba = $test->get_DBAdaptor('funcgen');
my $fetcher     = Bio::EnsEMBL::Production::Search::GeneFetcher->new();

my $genes = $fetcher->fetch_genes_for_dba( $core_dba, undef, $funcgen_dba );
is( scalar(@$genes), 88, "Correct number of genes" );

is( scalar( grep { lc $_->{biotype} eq 'lrg' } @$genes ),
	0, "Checking for LRGs" );

is( scalar(
		  grep { defined $_->{is_haplotype} && $_->{is_haplotype} == 1 } @$genes
	),
	1,
	"Haplotype genes" );
is( scalar(
		 grep { !defined $_->{is_haplotype} || $_->{is_haplotype} == 0 } @$genes
	),
	87,
	"Non-haplotype genes" );

subtest "Checking ncRNA gene", sub {
	my ($gene) = grep { $_->{id} eq 'ENSG00000261370' } @$genes;
	ok( $gene, "Test gene found" );
	my $expected_gene = $VAR1 = {
		'id'           => 'ENSG00000261370',
		'analysis'     => 'Havana',
		'coord_system' => { 'name' => 'chromosome', 'version' => 'GRCh38' },
		'transcripts'  => [ {
			   'analysis'            => 'Havana',
			   'strand'              => '-1',
			   'biotype'             => 'processed_pseudogene',
			   'version'             => '1',
			   'description'         => undef,
			   'gene_id'             => 'ENSG00000261370',
			   'name'                => 'RPL14P5-001',
			   'seq_region_synonyms' => undef,
			   'xrefs'               => [ {
						 'db_display'  => 'Vega transcript',
						 'dbname'      => 'Vega_transcript',
						 'primary_id'  => 'OTTHUMT00000427110',
						 'description' => undef,
						 'info_text'   => '',
						 'display_id'  => 'RP11-309M23.2-001',
						 'info_type'   => 'NONE' }, {
						 'info_type'  => 'NONE',
						 'info_text'  => 'Added during ensembl-vega production',
						 'display_id' => 'OTTHUMT00000427110',
						 'primary_id' => 'OTTHUMT00000427110',
						 'description' => undef,
						 'dbname'      => 'Vega_transcript',
						 'db_display'  => 'Vega transcript' }, {
						 'info_type'   => 'NONE',
						 'display_id'  => 'OTTHUMT00000427110',
						 'info_text'   => '',
						 'primary_id'  => 'OTTHUMT00000427110',
						 'description' => undef,
						 'dbname'      => 'OTTT',
						 'db_display'  => 'Havana transcript' }, {
						 'display_id'  => 'RP11-309M23.2-001',
						 'info_text'   => '',
						 'info_type'   => 'DIRECT',
						 'db_display'  => 'Clone-based (Vega)',
						 'dbname'      => 'Clone_based_vega_transcript',
						 'description' => '',
						 'primary_id'  => 'RP11-309M23.2-001' }, {
						 'info_text'   => 'Generated via ensembl_manual',
						 'display_id'  => 'RPL14P5',
						 'info_type'   => 'DIRECT',
						 'db_display'  => 'HGNC Symbol',
						 'dbname'      => 'HGNC',
						 'description' => 'ribosomal protein L14 pseudogene 5',
						 'primary_id'  => '37720' }, {
						 'info_type'   => 'MISC',
						 'display_id'  => 'RPL14P5-001',
						 'info_text'   => '',
						 'description' => 'ribosomal protein L14 pseudogene 5',
						 'primary_id'  => 'RPL14P5-001',
						 'db_display'  => 'HGNC transcript name',
						 'dbname'      => 'HGNC_trans_name' } ],
			   'coord_system' =>
				 { 'version' => 'GRCh38', 'name' => 'chromosome' },
			   'id'              => 'ENST00000569325',
			   'start'           => '969238',
			   'seq_region_name' => 'HG480_HG481_PATCH',
			   'end'             => '970836',
			   'translations'    => undef,
			   'exons'           => [ {
					  'version'         => '1',
					  'start'           => '970445',
					  'seq_region_name' => 'HG480_HG481_PATCH',
					  'strand'          => '-1',
					  'end'             => '970836',
					  'id'              => 'ENSE00002580842',
					  'rank'            => '1',
					  'coord_system' =>
						{ 'name' => 'chromosome', 'version' => 'GRCh38' },

					  'ensembl_object_type' => 'exon',
					  'trans_id'            => 'ENST00000569325' }, {
					  'trans_id'            => 'ENST00000569325',
					  'ensembl_object_type' => 'exon',
					  'coord_system' =>
						{ 'name' => 'chromosome', 'version' => 'GRCh38' },

					  'rank'            => '2',
					  'id'              => 'ENSE00002621881',
					  'strand'          => '-1',
					  'end'             => '970115',
					  'start'           => '969827',
					  'seq_region_name' => 'HG480_HG481_PATCH',
					  'version'         => '1' }, {
					  'trans_id'            => 'ENST00000569325',
					  'ensembl_object_type' => 'exon',
					  'rank'                => '3',
					  'coord_system' =>
						{ 'name' => 'chromosome', 'version' => 'GRCh38' },
					  'id'              => 'ENSE00002622269',
					  'start'           => '969238',
					  'seq_region_name' => 'HG480_HG481_PATCH',
					  'end'             => '969286',
					  'strand'          => '-1',
					  'version'         => '1' } ],
			   'ensembl_object_type' => 'transcript' } ],
		'version'         => '1',
		'biotype'         => 'pseudogene',
		'strand'          => '-1',
		'end'             => '970836',
		'seq_region_name' => 'HG480_HG481_PATCH',
		'start'           => '969238',
		'description' =>
		  'ribosomal protein L14 pseudogene 5 [Source:HGNC Symbol;Acc:37720]',
		'xrefs' => [ { 'description' => undef,
					   'primary_id'  => 'OTTHUMG00000174633',
					   'dbname'      => 'OTTG',
					   'db_display'  => 'Havana gene',
					   'info_type'   => 'NONE',
					   'info_text'   => '',
					   'display_id'  => 'OTTHUMG00000174633' }, {
					   'db_display'  => 'ArrayExpress',
					   'dbname'      => 'ArrayExpress',
					   'primary_id'  => 'ENSG00000261370',
					   'description' => '',
					   'display_id'  => 'ENSG00000261370',
					   'info_text'   => '',
					   'info_type'   => 'DIRECT' }, {
					   'primary_id'  => '37720',
					   'description' => 'ribosomal protein L14 pseudogene 5',
					   'db_display'  => 'HGNC Symbol',
					   'dbname'      => 'HGNC',
					   'info_type'   => 'DIRECT',
					   'info_text'   => 'Generated via ensembl_manual',
					   'display_id'  => 'RPL14P5' } ],
		'ensembl_object_type' => 'gene',
		'name'                => 'RPL14P5' };

	use Data::Dumper;
	print Dumper($gene);

	is_deeply( $gene, $expected_gene, "Testing gene structure" );
};

done_testing;
