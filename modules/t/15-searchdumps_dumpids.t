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
	use_ok('Bio::EnsEMBL::Production::Search::LRGFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

use Bio::EnsEMBL::Production::Search::IdFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;
use Data::Dumper;

my $test     = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens_dump');
my $core_dba = $test->get_DBAdaptor('core');

my $fetcher = Bio::EnsEMBL::Production::Search::IdFetcher->new();

my $ids = $fetcher->fetch_ids_for_dba($core_dba);
diag( Dumper($ids) );
use JSON;
print encode_json($ids);
is( scalar @$ids, 5, "Expected number of IDs" );
my ($current) = grep { $_->{id} eq 'bananag' } @$ids;
diag( Dumper($current) );
ok( !defined $current->{deprecated_mappings} || scalar( @{ $current->{deprecated_mappings} } ) == 0, "Checking deprecated for a live entry" );
ok( defined $current->{current_mappings} &&
	  scalar( @{ $current->{current_mappings} } ) == 1,
	"Checking current for an live entry" );
my ($old) = grep { $_->{id} eq 'lychee' } @$ids;
diag( Dumper($old) );
ok( defined $old->{deprecated_mappings} &&
	  scalar( @{ $old->{deprecated_mappings} } ) == 1,
	"Checking deprecated for an old entry" );
ok( !defined $old->{current_mappings} || scalar( @{ $current->{current_mappings} } ) == 0, "Checking current for an old entry" );
my ($gone) = grep { $_->{id} eq 'mango' } @$ids;
diag( Dumper($gone) );
ok( !defined $gone->{deprecated_mappings}|| scalar( @{ $current->{deprecated_mappings} } ) == 0, "Checking deprecated for a vanished entry" );
ok( !defined $gone->{current_mappings}|| scalar( @{ $current->{current_mappings} } ) == 0,    "Checking current for a vanished entry" );

done_testing;
