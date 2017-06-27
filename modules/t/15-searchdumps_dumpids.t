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

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X");

use Bio::EnsEMBL::Production::Search::IdFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;

my $test     = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens_dump');
my $core_dba = $test->get_DBAdaptor('core');

my $fetcher = Bio::EnsEMBL::Production::Search::IdFetcher->new();

my $ids = $fetcher->fetch_ids_for_dba($core_dba);
is(scalar @$ids, 5, "Expected number of IDs");
my ($current) = grep {$_->{id} eq 'bananag'} @$ids;
is(0, scalar(@{$current->{deprecated_mappings}}), "Checking deprecated");
is(1, scalar(@{$current->{current_mappings}}), "Checking current");
my ($old) = grep {$_->{id} eq 'lychee'} @$ids;
is(1, scalar(@{$old->{deprecated_mappings}}), "Checking deprecated");
is(0, scalar(@{$old->{current_mappings}}), "Checking current");
my ($gone) = grep {$_->{id} eq 'mango'} @$ids;
is(0, scalar(@{$gone->{deprecated_mappings}}), "Checking deprecated");
is(0, scalar(@{$gone->{current_mappings}}), "Checking current");

done_testing;
