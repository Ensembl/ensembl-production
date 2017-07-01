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
	use_ok('Bio::EnsEMBL::Production::Search::ProbeFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

use Bio::EnsEMBL::Production::Search::ProbeFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;
use Log::Log4perl qw/:easy/;

Log::Log4perl->easy_init($DEBUG);

use Data::Dumper;

my $test     = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens_dump');
my $dba      = $test->get_DBAdaptor('funcgen');
my $core_dba = $test->get_DBAdaptor('core');
my $fetcher  = Bio::EnsEMBL::Production::Search::ProbeFetcher->new();

my $out = $fetcher->fetch_probes_for_dba( $dba, $core_dba );
is( scalar( @{ $out->{probes} } ), 851 );
my ($probe) = grep { $_->{id} eq '23633' } @{ $out->{probes} };

my $expected_probe = { 'transcripts' => [ {
										 'description' => 'Test probe mapping',
										 'gene_name'   => 'RPL14P5',
										 'gene_id'     => 'ENSG00000261370',
										 'id'          => 'ENST00000569325' } ],
					   'id'           => '23633',
					   'array_vendor' => 'AGILENT',
					   'name'         => 'A_14_P100214',
					   'array'        => 'CGH_44b',
					   'locations'    => [ {
										  'start'           => '32890549',
										  'end'             => '32890608',
										  'seq_region_name' => '13',
										  'strand'          => '1' } ],
					   'array_chip' => 'CGH_44b' };
is_deeply( $probe, $expected_probe );

is( scalar( @{ $out->{probe_sets} } ), 1 );
my ($probe_set) =
  grep { $_->{id} eq 'homo_sapiens_dump_probeset_10367' }
  @{ $out->{probe_sets} };
is( $probe_set->{array},                 'HumanWG_6_V2' );
is( $probe_set->{array_vendor},          'ILLUMINA' );
is( $probe_set->{name},                  '214727_at' );
is( scalar( @{ $probe_set->{probes} } ), 12 );
done_testing;
