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

use warnings;
use strict;
use Test::More;

BEGIN {
	use_ok('Bio::EnsEMBL::Production::Search::SequenceFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X");

use Bio::EnsEMBL::Production::Search::SequenceFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;

my $test     = Bio::EnsEMBL::Test::MultiTestDB->new('hp_dump');
my $core_dba = $test->get_DBAdaptor('core');
my $fetcher = Bio::EnsEMBL::Production::Search::SequenceFetcher->new();
my $seqs = $fetcher->_fetch_seq_regions($core_dba);

is(scalar @$seqs, 29, "Expected number of sequences");
is(scalar(grep {$_->{type} eq 'contig'} @{$seqs}), 23, "Expected number of contig sequences");
is(scalar(grep {$_->{type} eq 'supercontig'} @{$seqs}),3, "Expected number of supercontig sequences");
is(scalar(grep {$_->{type} eq 'chromosome'} @{$seqs}), 3, "Expected number of chromosome sequences");

my $features = $fetcher->_fetch_misc_features($core_dba);

is(scalar @$features, 54, "Expected number of features");
done_testing();
