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

Log::Log4perl->easy_init($DEBUG);

use Data::Dumper;

my $test     = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens_dump');
my $core_dba = $test->get_DBAdaptor('core');
my $dba = $test->get_DBAdaptor('funcgen');
my $fetcher = Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher->new();

my $out = $fetcher->fetch_regulatory_elements_for_dba( $dba, $core_dba );
is( scalar(@$out), 33 );
{
	my ($e) = grep { $_->{id} eq 'hsa-miR-128-3p' } @$out;
	is_deeply( $e, {
				 'type'      => 'TarBase miRNA',
				 'accession' => 'MIMAT0000424',
				 'locations' => [ {
								 'seq_region_name'        => '13',
								 'end'                    => '32914844',
								 'start'                  => '32914823',
								 'supporting_information' => 'MRE1; spliced_no'
							   } ],
				 'description'  => 'miRNA target site',
				 'evidence'     => 'Computational',
				 'feature_name' => 'hsa-miR-128-3p',
				 'set_name'     => 'TarBase miRNA',
				 'class'        => 'RNA',
				 'method'       => 'Microarray',
				 'name'         => 'hsa-miR-128-3p',
				 'id'           => 'hsa-miR-128-3p' } );
}
{
	my ($e) = grep { $_->{id} eq 'p10@BRCA2,0.1628' } @$out;
	is_deeply( $e, {
				  'description' => 'FANTOM TSS, relaxed',
				  'locations'   => [ {
									 'end'             => '32890178',
									 'seq_region_name' => '13',
									 'start'           => '32890174' } ],
				  'feature_type' => 'FANTOM TSS relaxed',
				  'type'         => 'RegulatoryFactor',
				  'name'         => 'p10@BRCA2,0.1628',
				  'id'           => 'p10@BRCA2,0.1628',
				  'class'        => 'Transcription Start Site',
				  'set_name'     => 'FANTOM',
				  'synonyms'     => [ 'FANTOM' ] } );
}
{
	my ($e) = grep { $_->{id} eq '1639599' } @$out;
	is_deeply(
		$e, {
		  'start'           => '32965384',
		  'id'              => '1639599',
		  'seq_region_name' => '13',
		  'end'             => '32965701',
		  'feature_name'    => 'TF binding site',
		  'type'            => 'RegulatoryFeature' } );
}
done_testing();
