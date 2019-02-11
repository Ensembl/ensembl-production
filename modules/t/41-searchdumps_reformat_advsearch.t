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
use File::Slurp;
use JSON;

BEGIN {
  use_ok('Bio::EnsEMBL::Production::Search::GeneFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

use Bio::EnsEMBL::Production::Search::GeneFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Production::Search::AdvancedSearchFormatter;

my $test = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens_dump');
my $core_dba = $test->get_DBAdaptor('core');
my $funcgen_dba = $test->get_DBAdaptor('funcgen');
my $fetcher = Bio::EnsEMBL::Production::Search::GeneFetcher->new();

my $genes = $fetcher->fetch_genes_for_dba($core_dba, undef, $funcgen_dba);
is(scalar(@$genes), 88, "Correct number of genes");

my $genes_file_in = "41-searchdumps_reformat_advsearch_genes_in.json";
open my $genes_file, ">", $genes_file_in;
print $genes_file encode_json($genes);
close $genes_file;
my $genome_file_in = "41-searchdumps_reformat_advsearch_genome_in.json";
open my $genome_file, ">", $genome_file_in;
print $genome_file
    q/{"species_id":"1","organism":{"taxonomy_id":"559292","display_name":"Saccharomyces cerevisiae S288c","scientific_name":"Saccharomyces cerevisiae S288c","species_taxonomy_id":"4932","serotype":null,"aliases":["S_cerevisiae","Saccharomyces cerevisiae","Saccharomyces cerevisiae (Baker's yeast)","Saccharomyces cerevisiae S288c"],"strain":"S288C","name":"saccharomyces_cerevisiae"},"is_reference":"false","genebuild":"2011-09-SGD","id":"saccharomyces_cerevisiae","dbname":"saccharomyces_cerevisiae_core_88_4","assembly":{"accession":"GCA_000146045.2","name":"R64-1-1","level":"chromosome"},"division":"Ensembl"}/;
close $genome_file;
my $remodeller = Bio::EnsEMBL::Production::Search::AdvancedSearchFormatter->new();

my $genes_file_out = "41-searchdumps_reformat_advsearch_genes_out.json";
my $genome_file_out = "41-searchdumps_reformat_advsearch_genome_out.json";

$remodeller->remodel_genome($genes_file_in, $genome_file_in,
    $genes_file_out, $genome_file_out);

my $r_genome = decode_json(read_file($genome_file_out));
is($r_genome->{name}, 'saccharomyces_cerevisiae', "Correct genome found");
my $r_genes = decode_json(read_file($genes_file_out));
is(scalar(@$r_genes), 88, "Correct number of genes");

unlink $genome_file_out;
unlink $genome_file_in;
unlink $genes_file_out;
unlink $genes_file_in;

done_testing;
