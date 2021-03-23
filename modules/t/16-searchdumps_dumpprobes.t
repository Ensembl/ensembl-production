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
	use_ok('Bio::EnsEMBL::Production::Search::ProbeFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

use Bio::EnsEMBL::Production::Search::ProbeFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;
use Log::Log4perl qw/:easy/;
use List::Util qw(first);

Log::Log4perl->easy_init($DEBUG);

use Data::Dumper;

my $test     = Bio::EnsEMBL::Test::MultiTestDB->new('hp_dump');
my $dba      = $test->get_DBAdaptor('funcgen');
my $core_dba = $test->get_DBAdaptor('core');
my $fetcher  = Bio::EnsEMBL::Production::Search::ProbeFetcher->new();
my $out = $fetcher->fetch_probes_for_dba( $dba, $core_dba, 0, 21000000);
is( scalar( @{ $out->{probes} } ), 25 ,'Expected number of probes');
my ($probe) = first { $_->{id} eq '55599' } @{ $out->{probes} };
my $expected_probe = { 'transcripts' => [ {
										 'description' => 'Matches 3\' flank. Matches 3 other transcripts.',
										 'gene_name'   => 'OR12D2',
										 'gene_id'     => 'ENSG00000168787',
										 'id'          => 'ENST00000383555' } ],
					   'id'           => '55599',
					   'name'         => 'A_23_P99452',
						 'sequence' => 'TATGTTGCACAATGAGAAAAGAAATTAGTTTCAAATTTACCTCAGCGTTTGTGTATCGGG',
						 'length' => 60,
						 'class'  => 'EXPERIMENTAL',
					   'locations'    => [ {
										  'start'           => '32972996',
										  'end'             => '32973055',
										  'seq_region_name' => '13',
										  'strand'          => '1' }],
						 'arrays'  => [
							 {      'array' => 'SurePrint_G3_GE_8x60k_v2',
											'array_chip' => 'SurePrint_G3_GE_8x60k_v2',
											'array_class' => 'AGILENT',
											'array_format' => 'EXPRESSION',
											'array_type' => 'OLIGO',
											'array_vendor' => 'AGILENT',
											'design_id' => 'SurePrint_G3_GE_8x60k_v2'}] };
is_deeply( $probe, $expected_probe , 'Testing Probe structure' );
is( scalar( @{ $out->{probe_sets} } ), 118 ,'Expected number of Probe Sets');
my ($probe_set) =
  first { $_->{id} eq 'hp_dump_probeset_10367' }
  @{ $out->{probe_sets} };
is( $probe_set->{name},                  '214727_at', 'Expected probe Set name' );
is( $probe_set->{size},                  '12' , 'Expected Probe Set size' );
is( scalar( @{ $probe_set->{probes} } ), 12 , 'Expected number of probes for this probe set');
is( scalar( @{ $probe_set->{arrays} } ), 1 , 'Expected number of arrays for this probe set');
my $expected_probeset = {     'arrays' => [{'array' => 'U133_X3P',
															'array_chip' => 'U133_X3P',
															'array_vendor' => 'AFFY'}],
															'transcripts' => [ {
																		'description' => 'Matches 3\' flank. Matches 3 other transcripts.',
																		'gene_name'   => 'MOG',
																		'gene_id'     => 'ENSG00000204655',
																		'id'          => 'ENST00000376891' } ],
															'id' => 'hp_dump_probeset_15818',
															'name' => '215182_3p_x_at',
															'probes' => [{
																			   'arrays' => [ {  'array' => 'U133_X3P',
																												'array_chip' => 'U133_X3P',
																												'array_class' => 'AFFY_UTR',
																												'array_format' => 'EXPRESSION',
																												'array_type' => 'OLIGO',
																												'array_vendor' => 'AFFY',
																												'design_id' => 'U133_X3P'}],
																					'class' => 'EXPERIMENTAL',
																					'id' => 774125,
																					'length' => 25,
																					'locations' => [{
																						   'end' => 32926090,
																						   'seq_region_name' => 13,
																								'start' => 32926066,
																								'strand' => 1,
																					}
																					],
																					'name' => '580:725;',
																					'sequence' => 'GTAGGATGGGTTCAACTGCACAAAA'
															}
															],
															'size' => 1 };
my ($probe_set_2) =
  first { $_->{id} eq 'hp_dump_probeset_15818' }
  @{ $out->{probe_sets} };
is_deeply( $probe_set_2, $expected_probeset , 'Testing Probe Set structure' );
done_testing;
