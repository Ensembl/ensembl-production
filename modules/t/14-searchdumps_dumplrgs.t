#!perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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
	use_ok('Bio::EnsEMBL::Production::Search::LRGFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X");

use Bio::EnsEMBL::Production::Search::LRGFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;

my $test     = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens_dump');
my $core_dba = $test->get_DBAdaptor('core');

my $fetcher = Bio::EnsEMBL::Production::Search::LRGFetcher->new();

my $lrgs = $fetcher->fetch_lrgs_for_dba($core_dba);
is(scalar @$lrgs, 1, "Expected number of LRGs");
my $lrg = $lrgs->[0];
is(scalar @{$lrg->{transcripts}}, 1, "Expected number of LRG transcripts");

done_testing;
