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

my $test     = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');
my $core_dba = $test->get_DBAdaptor('core');

my $fetcher = Bio::EnsEMBL::Production::Search::GeneFetcher->new();

my $genes = $fetcher->fetch_genes_for_dba($core_dba);
is( scalar(@$genes), 87, "Correct number of genes" );
my ($gene) = grep { $_->{id} eq 'ENSG00000261370' } @$genes;
ok( $gene, "Test gene found" );
my $expected_gene = {
	 'xrefs' => [ { 'primary_id'  => 'OTTHUMG00000174633',
					'info_type'   => 'NONE',
					'dbname'      => 'OTTG',
					'description' => undef,
					'info_text'   => '',
					'display_id'  => 'OTTHUMG00000174633' }, {
					'primary_id'  => 'ENSG00000261370',
					'info_type'   => 'DIRECT',
					'dbname'      => 'ArrayExpress',
					'description' => '',
					'info_text'   => '',
					'display_id'  => 'ENSG00000261370' }, {
					'info_text'   => 'Generated via ensembl_manual',
					'description' => 'ribosomal protein L14 pseudogene 5',
					'dbname'      => 'HGNC',
					'display_id'  => 'RPL14P5',
					'primary_id'  => '37720',
					'info_type'   => 'DIRECT' } ],
	 'end'          => '970836',
	 'start'        => '969238',
	 'version'      => '1',
	 'coord_system' => { 'version' => 'GRCh38', 'name' => 'chromosome' },
	 'description' =>
	   'ribosomal protein L14 pseudogene 5 [Source:HGNC Symbol;Acc:37720]',
	 'seq_region_name' => 'HG480_HG481_PATCH',
	 'id'              => 'ENSG00000261370',
	 'transcripts'     => [ {
		   'seq_region_synonyms' => undef,
		   'start'               => '969238',
		   'xrefs'               => [ {
						 'display_id'  => 'RP11-309M23.2-001',
						 'info_text'   => '',
						 'description' => undef,
						 'dbname'      => 'Vega_transcript',
						 'info_type'   => 'NONE',
						 'primary_id'  => 'OTTHUMT00000427110' }, {
						 'info_type'   => 'NONE',
						 'primary_id'  => 'OTTHUMT00000427110',
						 'display_id'  => 'OTTHUMT00000427110',
						 'description' => undef,
						 'dbname'      => 'Vega_transcript',
						 'info_text'   => 'Added during ensembl-vega production'
					   }, {
						 'info_type'   => 'NONE',
						 'primary_id'  => 'OTTHUMT00000427110',
						 'display_id'  => 'OTTHUMT00000427110',
						 'info_text'   => '',
						 'description' => undef,
						 'dbname'      => 'OTTT' }, {
						 'info_type'   => 'DIRECT',
						 'primary_id'  => 'RP11-309M23.2-001',
						 'display_id'  => 'RP11-309M23.2-001',
						 'dbname'      => 'Clone_based_vega_transcript',
						 'description' => '',
						 'info_text'   => '' }, {
						 'display_id'  => 'RPL14P5',
						 'dbname'      => 'HGNC',
						 'description' => 'ribosomal protein L14 pseudogene 5',
						 'info_text'   => 'Generated via ensembl_manual',
						 'info_type'   => 'DIRECT',
						 'primary_id'  => '37720' }, {
						 'primary_id'  => 'RPL14P5-001',
						 'info_type'   => 'MISC',
						 'description' => 'ribosomal protein L14 pseudogene 5',
						 'dbname'      => 'HGNC_trans_name',
						 'info_text'   => '',
						 'display_id'  => 'RPL14P5-001' } ],
		   'end'          => '970836',
		   'coord_system' => { 'name' => 'chromosome', 'version' => 'GRCh38' },
		   'version'      => '1',
		   'translations' => undef,
		   'seq_region_name' => 'HG480_HG481_PATCH',
		   'description'     => undef,
		   'name'            => 'RPL14P5-001',
		   'strand'          => '-1',
		   'id'              => 'ENST00000569325',
		   'biotype'         => 'processed_pseudogene',
		   'gene_id'         => 'ENSG00000261370',
		   'exons'           => [ {
						   'id'       => 'ENSE00002580842',
						   'strand'   => '-1',
						   'end'      => '970836',
						   'start'    => '970445',
						   'trans_id' => 'ENST00000569325',
						   'rank'     => '1',
						   'coord_system' =>
							 { 'name' => 'chromosome', 'version' => 'GRCh38' },
						   'version'         => '1',
						   'seq_region_name' => 'HG480_HG481_PATCH' }, {
						   'seq_region_name' => 'HG480_HG481_PATCH',
						   'coord_system' =>
							 { 'name' => 'chromosome', 'version' => 'GRCh38' },
						   'version'  => '1',
						   'trans_id' => 'ENST00000569325',
						   'rank'     => '2',
						   'end'      => '970115',
						   'start'    => '969827',
						   'strand'   => '-1',
						   'id'       => 'ENSE00002621881' }, {
						   'strand'          => '-1',
						   'id'              => 'ENSE00002622269',
						   'start'           => '969238',
						   'end'             => '969286',
						   'seq_region_name' => 'HG480_HG481_PATCH',
						   'coord_system' =>
							 { 'name' => 'chromosome', 'version' => 'GRCh38' },
						   'version'  => '1',
						   'rank'     => '3',
						   'trans_id' => 'ENST00000569325' } ] } ],
	 'strand'  => '-1',
	 'name'    => 'RPL14P5',
	 'biotype' => 'pseudogene' };

is_deeply( $gene, $expected_gene, "Testing gene structure" );

done_testing;
