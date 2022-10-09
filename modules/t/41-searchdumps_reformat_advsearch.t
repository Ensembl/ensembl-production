#!perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
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
use Bio::EnsEMBL::Production::Search::ProbeFetcher;
use Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Production::Search::AdvancedSearchFormatter;
use Bio::EnsEMBL::Production::Search::RegulationAdvancedSearchFormatter;

my $test = Bio::EnsEMBL::Test::MultiTestDB->new('hp_dump');
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
#print $genome_file
#    q/{"species_id":"1","organism":{"taxonomy_id":"559292","display_name":"Saccharomyces cerevisiae S288c","scientific_name":"Saccharomyces cerevisiae S288c","species_taxonomy_id":"4932","serotype":null,"aliases":["S_cerevisiae","Saccharomyces cerevisiae","Saccharomyces cerevisiae (Baker's yeast)","Saccharomyces cerevisiae S288c"],"strain":"S288C","name":"saccharomyces_cerevisiae"},"reference":null,"genebuild":"2011-09-SGD","id":"saccharomyces_cerevisiae","dbname":"saccharomyces_cerevisiae_core_88_4","assembly":{"accession":"GCA_000146045.2","name":"R64-1-1","level":"chromosome"},"division":"Ensembl"}/;

print $genome_file
    q/{"species_id":"1","organism":{"taxonomy_id":"559292","display_name":"Saccharomyces cerevisiae S288c","scientific_name":"Saccharomyces cerevisiae S288c","species_taxonomy_id":"4932","name":"saccharomyces_cerevisiae"}}/;

    close $genome_file;
my $remodeller = Bio::EnsEMBL::Production::Search::AdvancedSearchFormatter->new();

my $genes_file_out = "41-searchdumps_reformat_advsearch_genes_out.json";
my $genome_file_out = "41-searchdumps_reformat_advsearch_genome_out.json";

$remodeller->remodel_genome($genes_file_in, $genome_file_in,
    $genes_file_out, $genome_file_out);





#testing 12332



=head


my $r_genome = decode_json(read_file($genome_file_out));
is($r_genome->{name}, 'saccharomyces_cerevisiae', "Correct genome found");
my $r_genes = decode_json(read_file($genes_file_out));
is(scalar(@$r_genes), 88, "Correct number of genes");

unlink $genome_file_out;
unlink $genes_file_out;
unlink $genes_file_in;
my $probe_fetcher  = Bio::EnsEMBL::Production::Search::ProbeFetcher->new();
my $out = $probe_fetcher->fetch_probes_for_dba( $funcgen_dba, $core_dba, 0, 21000000);
my $probes_file_in = "41-searchdumps_reformat_advsearch_probes_in.json";
open my $probes_file, ">", $probes_file_in;
print $probes_file encode_json($out->{probes});
close $probes_file;
my $probe_sets_file_in = "41-searchdumps_reformat_advsearch_probe_sets_in.json";
open my $probe_sets_file, ">", $probe_sets_file_in;
print $probe_sets_file encode_json($out->{probe_sets});
close $probe_sets_file;

my $regulation_remodeller = Bio::EnsEMBL::Production::Search::RegulationAdvancedSearchFormatter->new();
my $probes_file_out = "41-searchdumps_reformat_advsearch_probes_out.json";
my $probe_sets_file_out = "41-searchdumps_reformat_advsearch_probe_sets_out.json";

$regulation_remodeller->remodel_probes($probes_file_in, $genome_file_in,
    $probes_file_out);

$regulation_remodeller->remodel_probesets($probe_sets_file_in, $genome_file_in,
    $probe_sets_file_out);

my $r_probes = decode_json(read_file($probes_file_out));
is(scalar(@$r_probes), 25, "Correct number of probes");
my $r_probe_sets = decode_json(read_file($probe_sets_file_out));
is(scalar(@$r_probe_sets), 118, "Correct number of probe sets");

unlink $probes_file_out;
unlink $probes_file_in;
unlink $probe_sets_file_out;
unlink $probe_sets_file_in;

my $regulation_fetcher  = Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher->new();
$out = $regulation_fetcher->fetch_regulatory_elements_for_dba( $funcgen_dba, $core_dba);
my $motifs_file_in = "41-searchdumps_reformat_advsearch_motifs_in.json";
open my $motifs_file, ">", $motifs_file_in;
print $motifs_file encode_json($out->{motifs});
close $motifs_file;
my $regulatory_features_file_in = "41-searchdumps_reformat_advsearch_regulatory_features_in.json";
open my $regulatory_features_file, ">", $regulatory_features_file_in;
print $regulatory_features_file encode_json($out->{regulatory_features});
close $regulatory_features_file;
my $mirna_file_in = "41-searchdumps_reformat_advsearch_mirna_in.json";
open my $mirna_file, ">", $mirna_file_in;
print $mirna_file encode_json($out->{mirna});
close $mirna_file;
my $external_features_file_in = "41-searchdumps_reformat_advsearch_external_features_in.json";
open my $external_features_file, ">", $external_features_file_in;
print $external_features_file encode_json($out->{external_features});
close $external_features_file;
my $peaks_file_in = "41-searchdumps_reformat_advsearch_peaks_in.json";
open my $peaks_file, ">", $peaks_file_in;
print $peaks_file encode_json($out->{peaks});
close $peaks_file;
my $transcription_factors_file_in = "41-searchdumps_reformat_advsearch_transcription_factors_in.json";
open my $transcription_factors_file, ">", $transcription_factors_file_in;
print $transcription_factors_file encode_json($out->{transcription_factors});
close $transcription_factors_file;

my $motifs_file_out = "41-searchdumps_reformat_advsearch_motifs_out.json";
my $regulatory_features_file_out = "41-searchdumps_reformat_advsearch_regulatory_features_out.json";
my $mirna_file_out = "41-searchdumps_reformat_advsearch_mirna_out.json";
my $external_features_file_out = "41-searchdumps_reformat_advsearch_external_features_out.json";
my $peaks_file_out = "41-searchdumps_reformat_advsearch_peaks_out.json";
my $transcription_factors_file_out = "41-searchdumps_reformat_advsearch_transcription_factors_out.json";

$regulation_remodeller->remodel_regulation($motifs_file_in, $genome_file_in,
    $motifs_file_out);
$regulation_remodeller->remodel_regulation($regulatory_features_file_in, $genome_file_in,
    $regulatory_features_file_out);
$regulation_remodeller->remodel_regulation($mirna_file_in, $genome_file_in,
    $mirna_file_out);
$regulation_remodeller->remodel_regulation($external_features_file_in, $genome_file_in,
    $external_features_file_out);
$regulation_remodeller->remodel_regulation($peaks_file_in, $genome_file_in,
    $peaks_file_out);
$regulation_remodeller->remodel_regulation($transcription_factors_file_in, $genome_file_in,
    $transcription_factors_file_out);

my $r_motifs = decode_json(read_file($motifs_file_out));
is(scalar(@$r_motifs), 28, "Correct number of motifs");
my $r_regulatory_features = decode_json(read_file($regulatory_features_file_out));
is(scalar(@$r_regulatory_features), 170, "Correct number of regulatory features");
my $r_mirna = decode_json(read_file($mirna_file_out));
is(scalar(@$r_mirna), 4, "Correct number of mirnas");
my $r_external_features = decode_json(read_file($external_features_file_out));
is(scalar(@$r_external_features), 19, "Correct number of external features");
my $r_peaks = decode_json(read_file($peaks_file_out));
is(scalar(@$r_peaks), 37, "Correct number of peaks");
my $r_transcription_factors = decode_json(read_file($transcription_factors_file_out));
is(scalar(@$r_transcription_factors), 6, "Correct number of Transcription factors");

unlink $motifs_file_out;
unlink $motifs_file_in;
unlink $regulatory_features_file_out;
unlink $regulatory_features_file_in;
unlink $mirna_file_out;
unlink $mirna_file_in;
unlink $external_features_file_out;
unlink $external_features_file_in;
unlink $peaks_file_out;
unlink $peaks_file_in;
unlink $transcription_factors_file_out;
unlink $transcription_factors_file_in;
unlink $genome_file_in;
=cut

done_testing;
