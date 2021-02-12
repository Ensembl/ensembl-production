#!perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
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
use strict;
use warnings;
use Test::More;

BEGIN {
	use_ok('Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X");

use Bio::EnsEMBL::Production::Search::ProbeFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;
use Log::Log4perl qw/:easy/;
use List::Util qw(first);

Log::Log4perl->easy_init($DEBUG);

use Data::Dumper;

my $test     = Bio::EnsEMBL::Test::MultiTestDB->new('hp_dump');
my $core_dba = $test->get_DBAdaptor('core');
my $dba = $test->get_DBAdaptor('funcgen');
my $fetcher = Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher->new();
my $out = $fetcher->fetch_regulatory_elements_for_dba( $dba, $core_dba );
is( scalar( @{ $out->{external_features} } ), 19 ,'Expected number of External features');
is( scalar( @{ $out->{mirna} } ), 4 ,'Expected number of miRNA');
is( scalar( @{ $out->{motifs} } ), 28 ,'Expected number of motifs');
is( scalar( @{ $out->{peaks} } ), 37 ,'Expected number of peaks');
is( scalar( @{ $out->{regulatory_features} } ), 170 ,'Expected number of regulatory features');
is( scalar( @{ $out->{transcription_factors} } ), 6 ,'Expected number of Transcription factors');
{
	my ($e) = first { $_->{id} eq 'p1@BRCA2,0.4349' } @{ $out->{external_features} };
	is_deeply( $e, {   'class' => 'Transcription Start Site',
											'description' => 'FANTOM TSS, strict',
											'feature_type' => 'FANTOM TSS strict',
											'id' => 'p1@BRCA2,0.4349',
											'locations' => [{
																			'end' => 32889653,
																			'seq_region_name' => 13,
																			'start' => 32889606,
																			'strand' => 1
											}],
											'name' => 'p1@BRCA2,0.4349',
											'set_name' => 'FANTOM',
											'type' => 'Other Regulatory Regions'}, "Testing External features structure"  );
}
{
	my ($e) = first { $_->{id} eq 'hsa-miR-192-5p' } @{ $out->{mirna} };
	is_deeply( $e, {
				     'accession' => 'MIMAT0000222',
							'class' => 'RNA',
							'description' => 'miRNA target site',
							'display_label' => 'hsa-miR-192-5p',
							'evidence' => 'Computational',
							'feature_name' => 'hsa-miR-192-5p',
							'id' => 'hsa-miR-192-5p',
							'locations' => [{   'end' => 32911398,
																	'gene_stable_id' => 'ENSG00000139618',
																	'seq_region_name' => 13,
																	'start' => 32911390,
																	'strand' => 1,
																	'supporting_information' => 'MRE1; spliced_no'}],
							'method' => 'Microarray',
							'name' => 'hsa-miR-192-5p',
							'set_name' => 'TarBase miRNA',
							'type' => 'TarBase miRNA' }, "Testing miRNAs structure" );
}
{
	my ($e) = first { $_->{id} eq 'ENSM00207137665' }  @{ $out->{motifs} };
	is_deeply(
		$e, {
					'id' => 'ENSM00207137665',
					'score' => 8.184,
					'seq_region_end' => 32889603,
					'seq_region_name' => 13,
					'seq_region_start' => 32889596,
					'seq_region_strand' => '-1',
					'stable_id' => 'ENSPFM0159',
					'type' => 'Binding Motifs' }, "Testing motifs structure" );
}
{
	my ($e) = first { $_->{id} eq 'ELF1' }  @{ $out->{peaks} };
	is_deeply(
		$e, {
				'class' => 'Transcription Factor',
				'description' => 'ELF1 Transcription Factor Binding',
				'epigenome_description' => 'Human myelogenous leukaemia cell line',
				'epigenome_name' => 'K562',
				'feature_name' => 'ELF1',
				'id' => 'ELF1',
				'locations' => [{   'end' => 32890140,
														'seq_region_name' => 13,
														'start' => 32889338},
												{   'end' => 32889790,
												'seq_region_name' => 13,
												'start' => 32889383}],
				'so_accession' => 'SO:0000235',
				'so_name' => 'TF_binding_site',
				'type' => 'Regulatory Evidence' }, "Testing peaks structure" );
}
{
	my ($e) = first { $_->{id} eq 'ENSR00001036347' }  @{ $out->{regulatory_features} };
	is_deeply(
		$e, {
			   'description' => 'Predicted promoter',
					'end' => 32892606,
					'epigenome_description' => 'Epithelial Lung Carcinoma',
					'epigenome_name' => 'A549',
					'feature_name' => 'Promoter',
					'id' => 'ENSR00001036347',
					'seq_region_name' => 13,
					'so_accession' => 'SO:0000167',
					'so_name' => 'promoter',
					'start' => 32888409,
					'type' => 'Regulatory Features'
				 }, "Testing Regulatory features structure" );
}
{
	my ($e) = first { $_->{id} eq 'ELK1' }  @{ $out->{transcription_factors} };
	is_deeply(
		$e, {
				   'binding_matrix' => ['ENSPFM0150','ENSPFM0172','ENSPFM0205','ENSPFM0206'],
					'description' => 'ELK1 TF binding',
					'feature_name' => 'ELK1',
					'gene_stable_id' => 'ENSG00000126767',
					'name' => 'ELK1',
					'id'   => 'ELK1',
					'type' => 'Transcription Factor' }, "Testing Transcription factors" );
}
done_testing();
