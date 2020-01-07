#!perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
  use_ok('Bio::EnsEMBL::Production::Search::VariationFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

use Bio::EnsEMBL::Production::Search::VariationFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;
use Log::Log4perl qw/:easy/;

Log::Log4perl->easy_init($DEBUG);

my $test_onto = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $onto_dba = $test_onto->get_DBAdaptor('ontology');

my $test = Bio::EnsEMBL::Test::MultiTestDB->new('hp_dump');
my $dba = $test->get_DBAdaptor('variation');
my $fetcher = Bio::EnsEMBL::Production::Search::VariationFetcher->new();

subtest "Testing variant fetching", sub {
  my $out = $fetcher->fetch_variations_for_dba($dba, $onto_dba);
  is(scalar(@$out), 932, "Testing correct numbers of variants");
  my @som = grep {$_->{somatic} eq 'false'} @{$out};
  is(scalar(@som), 931, "Testing correct numbers of non-somatic variants");
  {
    my ($var) = grep {$_->{id} eq 'rs7569578'} @som;
    is_deeply(
        $var, {
        'clinical_significance' => [
            'benign',
            'likely benign',
            'likely pathogenic',
            'drug response',
            'histocompatibility'
        ],
        'id'                    => 'rs7569578',
        'class'                 => 'SNV',
        'synonyms'              => [
            {
                'source' => {
                    'version' => 138,
                    'name'    => 'Archive dbSNP'
                },
                'name'   => 'rs57302278'
            }
        ],
        'somatic'               => 'false',
        'minor_allele'          => 'A',
        'minor_allele_freq'     => '0.164371',
        'source'                => {
            'name'    => 'dbSNP',
            'version' => 138
        },
        'ancestral_allele'      => 'A',
        'hgvs'                  => [
            'c.1881+3399G>A',
            'n.99+25766C>T'
        ],
        'gene_names'            => [
            'banana',
            'mango'
        ],
        'sets'                  => [
            'ENSEMBL:Venter',
            'ENSEMBL:Watson',
            '1000 Genomes - All - common',
            '1000 Genomes - AFR - common',
            '1000 Genomes - AMR - common',
            '1000 Genomes - ASN - common',
            '1000 Genomes - EUR - common',
            '1000 Genomes - High coverage - Trios',
            'HapMap - CEU',
            'HapMap - HCB',
            'HapMap - JPT',
            'HapMap - YRI',
            'Anonymous Korean',
            'Anonymous Irish Male'
        ],
        'minor_allele_count'    => 358,
        'locations'             => [
            {
                'start'           => 45411130,
                'strand'          => 1,
                'allele_string'   => 'T/A',
                'end'             => 45411130,
                'annotations'     => [
                    {
                        'hgvs_transcript' => 'ENST00000427020.4:n.255+5130A>T',
                        'stable_id'       => 'ENST00000427020',
                        'consequences'    => [
                            {
                                'so_accession' => 'SO:0001619',
                                'name'         => 'non_coding_transcript_variant'
                            },
                            {
                                'name'         => 'intron_variant',
                                'so_accession' => 'SO:0001627'
                            }
                        ],
                        'hgvs_genomic'    => '2:g.45183991T>A'
                    }
                ],
                'seq_region_name' => '2'
            }
        ],
        'evidence'              => [
            'Multiple_observations',
            'Frequency',
            'HapMap',
            '1000Genomes'
        ]
    },
        'Testing variation with consequences and gene names');
  }
  {
    my ($var) = grep {$_->{id} eq 'rs2299222'} @som;

    is_deeply(
        $var, {
        'class'              => 'SNV',
        'gwas'               => [
            'NHGRI-EBI GWAS catalog'
        ],
        'minor_allele_freq'  => '0.0399449',
        'locations'          => [
            {
                'end'             => 86442404,
                'seq_region_name' => '7',
                'start'           => 86442404,
                'allele_string'   => 'T/C',
                'strand'          => 1
            }
        ],
        'minor_allele'       => 'C',
        'source'             => {
            'version' => 138,
            'name'    => 'dbSNP'
        },
        'id'                 => 'rs2299222',
        'phenotypes'         => [
            {
                'description'   => 'ACHONDROPLASIA',
                'id'            => 1,
                'source'        => {
                    'version' => 138,
                    'name'    => 'dbSNP'
                },
                'study'         => {
                    'name'               => 'Redon 2006 "Global variation in copy number in the human genome." PMID:17122850 [remapped from build NCBI35]',
                    'description'        => 'Control Set',
                    'associated_studies' => [
                        {
                            'name' => 'Test study for the associate_study table'
                        }
                    ]
                },
                'name'          => 'ACH',
                'accession'     => 'OMIM:100800',
                'ontology_term' => 'Achondroplasia',
                'ontology_name' => 'OMIM'
            },
            {
                'study'         => {
                    'name'               => 'Redon 2006 "Global variation in copy number in the human genome." PMID:17122850 [remapped from build NCBI35]',
                    'description'        => 'Control Set',
                    'associated_studies' => [
                        {
                            'name' => 'Test study for the associate_study table'
                        }
                    ]
                },
                'source'        => {
                    'name'    => 'NHGRI-EBI GWAS catalog',
                    'version' => 20170304
                },
                'id'            => 17889,
                'accession'     => 'EFO:0005193',
                'description'   => 'IgG glycosylation'
            }
        ],
        'sets'               => [
            'Illumina_Human660W-quad',
            'Illumina_1M-duo',
            'ENSEMBL:Venter',
            'ENSEMBL:Watson',
            '1000 Genomes - All - common',
            '1000 Genomes - AFR - common',
            '1000 Genomes - AMR - common',
            '1000 Genomes - ASN - common',
            '1000 Genomes - EUR - common',
            'Illumina_HumanHap650Y',
            'Illumina_Human610_Quad',
            'Illumina_HumanHap550',
            'Illumina_HumanOmni5',
            'HapMap - CEU',
            'HapMap - HCB',
            'HapMap - JPT',
            'HapMap - YRI',
            'Anonymous Korean'
        ],
        'minor_allele_count' => 87,
        'synonyms'           => [
            {
                'source' => {
                    'name'    => 'Archive dbSNP',
                    'version' => 138
                },
                'name'   => 'rs17765152'
            },
            {
                'source' => {
                    'name'    => 'Archive dbSNP',
                    'version' => 138
                },
                'name'   => 'rs60739517'
            }
        ],
        'somatic'            => 'false'
    },
        "Testing variation with phenotypes");
  }
};
subtest "Testing SV fetching", sub {
  my $out = $fetcher->fetch_structural_variations_for_dba($dba);
  is(@{$out}, 7, "Expected number of SVs");
  {
    my ($v) = grep {$_->{id} eq 'esv93078'} @{$out};
    is_deeply(
        $v, {
        'source'              => 'DGVa',
        'seq_region_name'     => '8',
        'start'               => '7823440',
        'id'                  => 'esv93078',
        'end'                 => '8819373',
        'supporting_evidence' => [ 'essv194300', 'essv194301' ],
        'study'               => 'estd59',
        'source_description'  => 'Database of Genomic Variants Archive'
    },
        "Expected evidenced SV")
  }
  {
    my ($v) = grep {$_->{id} eq 'CN_674347'} @{$out};
    is_deeply($v, {
        'source_description' => 'http://www.affymetrix.com/',
        'end'                => '27793771',
        'id'                 => 'CN_674347',
        'start'              => '27793747',
        'seq_region_name'    => '18',
        'source'             => 'Affy GenomeWideSNP_6 CNV' },
        "Expected evidence-less SV")
  }
};

subtest "Testing phenotype fetching", sub {
  my $out = $fetcher->fetch_phenotypes_for_dba($dba, $onto_dba);
  is(scalar(@{$out}), 3, "Correct number of phenotypes");
  my ($ph) = grep {defined $_->{name} && $_->{name} eq 'ACH'} @{$out};
  is_deeply($ph, {
      'id'            => 1,
      'name'          => 'ACH',
      'ontology_term' => 'Achondroplasia',
      'ontology_name' => 'OMIM',
      'accession'     => 'OMIM:100800',
      'description'   => 'ACHONDROPLASIA' });
};

done_testing;
