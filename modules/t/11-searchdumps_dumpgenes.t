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
  use_ok('Bio::EnsEMBL::Production::Search::GeneFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

use Bio::EnsEMBL::Production::Search::GeneFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;

sub sort_gene {
  my ($gene) = @_;
  $gene->{xrefs} = sort_xrefs($gene->{xrefs});
  $gene->{transcripts} = sort_transcripts($gene->{transcripts});
  return $gene;
}

sub sort_xrefs {
  my ($xrefs) = @_;
  if (defined $xrefs) {
    $xrefs = [
        sort {
          $a->{primary_id} cmp $b->{primary_id} ||
              $a->{display_id} cmp $b->{display_id} ||
              $a->{dbname} cmp $b->{dbname}
        } @$xrefs ];
    for my $xref (@$xrefs) {
      if (defined $xref->{linkage_types}) {
        $xref->{linkage_types} =
            [ sort {$a->{evidence} cmp $b->{evidence}}
                @{$xref->{linkage_types}} ];
      }
    }
  }
  return $xrefs;
}

sub sort_transcripts {
  my ($transcripts) = @_;
  for my $transcript (@{$transcripts}) {
    $transcript->{xrefs} = sort_xrefs($transcript->{xrefs});
    if (defined $transcript->{translations}) {
      $transcript->{translations} =
          sort_translations($transcript->{translations});
    }
  }
  return [ sort {$a->{id} <=> $b->{id}} @{$transcripts} ];
}

sub sort_translations {
  my ($translations) = @_;
  for my $translation (@{$translations}) {
    $translation->{xrefs} = sort_xrefs($translation->{xrefs});
    if (defined $translation->{protein_features}) {
      $translation->{protein_features} = [
          sort {
            $a->{start} <=> $b->{start} ||
                $a->{name} cmp $b->{name}
          } @{$translation->{protein_features}} ];
    }
  }
  return [ sort @{$translations} ];
}

my $test = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens_dump');
my $core_dba = $test->get_DBAdaptor('core');
my $funcgen_dba = $test->get_DBAdaptor('funcgen');
my $fetcher = Bio::EnsEMBL::Production::Search::GeneFetcher->new();
diag "Fetching genes...";
my $genes = $fetcher->fetch_genes_for_dba($core_dba, undef, $funcgen_dba);
diag "Checking genes...";
is(scalar(@$genes), 88, "Correct number of genes");
is(scalar(grep {lc $_->{biotype} eq 'lrg'} @$genes), 0, "Checking for LRGs");
is(scalar(grep {defined $_->{is_haplotype} && $_->{is_haplotype} == 1} @$genes), 1, "Haplotype genes");
is(scalar(grep {!defined $_->{is_haplotype} || $_->{is_haplotype} == 0} @$genes), 87, "Non-haplotype genes");

subtest "Checking protein_coding gene", sub {
  my ($gene) = grep {$_->{id} eq 'ENSG00000204704'} @$genes;
  use Data::Dumper;
  my $expected_gene = {
      'biotype'             => 'protein_coding',
      'seq_region_name'     => '6',
      'analysis'            => 'ensembl_havana_gene',
      'start'               => 29011990,
      'strand'              => -1,
      'coord_system'        => {
          'version' => 'GRCh38',
          'name'    => 'chromosome'
      },
      'name'                => 'OR2W1',
      'version'             => 2,
      'end'                 => 29013017,
      'ensembl_object_type' => 'gene',
      'id'                  => 'ENSG00000204704',
      'synonyms'            => [
          'hs6M1-15'
      ],
      'description'         => 'olfactory receptor, family 2, subfamily W, member 1 [Source:HGNC Symbol;Acc:8281]',
      'analysis_display'    => 'Ensembl/Havana merge',
      'source'              => 'ensembl',
      'xrefs'               => [
          {
              'info_type'   => 'DEPENDENT',
              'info_text'   => '',
              'db_display'  => 'EntrezGene',
              'synonyms'    => [
                  'hs6M1-15'
              ],
              'description' => 'olfactory receptor, family 2, subfamily W, member 1',
              'dbname'      => 'EntrezGene',
              'primary_id'  => '26692',
              'display_id'  => 'OR2W1'
          },
          {
              'description' => 'olfactory receptor, family 2, subfamily W, member 1',
              'display_id'  => 'OR2W1',
              'db_display'  => 'WikiGene',
              'primary_id'  => '26692',
              'dbname'      => 'WikiGene',
              'info_text'   => '',
              'info_type'   => 'DEPENDENT'
          },
          {
              'description' => 'olfactory receptor, family 2, subfamily W, member 1',
              'synonyms'    => [
                  'hs6M1-15'
              ],
              'db_display'  => 'HGNC Symbol',
              'info_text'   => 'Generated via ensembl_manual',
              'info_type'   => 'DIRECT',
              'display_id'  => 'OR2W1',
              'primary_id'  => '8281',
              'dbname'      => 'HGNC'
          },
          {
              'info_type'   => 'DIRECT',
              'info_text'   => '',
              'db_display'  => 'ArrayExpress',
              'dbname'      => 'ArrayExpress',
              'primary_id'  => 'ENSG00000204704',
              'description' => '',
              'display_id'  => 'ENSG00000204704'
          },
          {
              'primary_id'  => 'OR2W1',
              'db_display'  => 'UniProtKB Gene Name',
              'dbname'      => 'Uniprot_gn',
              'description' => '',
              'display_id'  => 'OR2W1',
              'info_type'   => 'DEPENDENT',
              'info_text'   => ''
          },
          {
              'dbname'      => 'OTTG',
              'db_display'  => 'Havana gene',
              'primary_id'  => 'OTTHUMG00000031048',
              'display_id'  => 'OTTHUMG00000031048',
              'description' => undef,
              'info_type'   => 'NONE',
              'info_text'   => ''
          }
      ],
      'transcripts'         => [
          {
              'analysis'            => 'ensembl_havana_transcript',
              'start'               => 29011990,
              'coord_system'        => {
                  'version' => 'GRCh38',
                  'name'    => 'chromosome'
              },
              'name'                => 'OR2W1-001',
              'strand'              => -1,
              'biotype'             => 'protein_coding',
              'seq_region_name'     => '6',
              'translations'        => [
                  {
                      'ensembl_object_type' => 'translation',
                      'id'                  => 'ENSP00000366380',
                      'transcript_id'       => 'ENST00000377175',
                      'xrefs'               => [
                          {
                              'display_id'  => '191160',
                              'description' => undef,
                              'primary_id'  => '191160',
                              'db_display'  => 'Vega translation',
                              'dbname'      => 'Vega_translation',
                              'info_text'   => '',
                              'info_type'   => 'NONE'
                          },
                          {
                              'db_display'  => 'INSDC protein ID',
                              'dbname'      => 'protein_id',
                              'primary_id'  => 'AAI03871',
                              'description' => '',
                              'display_id'  => 'AAI03871.1',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => '',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'AAI03872',
                              'dbname'      => 'protein_id',
                              'description' => '',
                              'display_id'  => 'AAI03872.1'
                          },
                          {
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'AAI03873',
                              'dbname'      => 'protein_id',
                              'display_id'  => 'AAI03873.1',
                              'description' => '',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'AAK95113',
                              'dbname'      => 'protein_id',
                              'description' => '',
                              'display_id'  => 'AAK95113.1',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'description' => '',
                              'display_id'  => 'AF399628',
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'AF399628',
                              'dbname'      => 'EMBL',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => '',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'primary_id'  => 'AJ302594',
                              'display_id'  => 'AJ302594',
                              'description' => ''
                          },
                          {
                              'display_id'  => 'AJ302595',
                              'description' => '',
                              'dbname'      => 'EMBL',
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'AJ302595',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'primary_id'  => 'AJ302596',
                              'description' => '',
                              'display_id'  => 'AJ302596',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT',
                              'display_id'  => 'AJ302597',
                              'description' => '',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'primary_id'  => 'AJ302597'
                          },
                          {
                              'description' => '',
                              'display_id'  => 'AJ302598',
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'AJ302598',
                              'dbname'      => 'EMBL',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => '',
                              'dbname'      => 'EMBL',
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'AJ302599',
                              'description' => '',
                              'display_id'  => 'AJ302599'
                          },
                          {
                              'description' => '',
                              'display_id'  => 'AJ302600',
                              'dbname'      => 'EMBL',
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'AJ302600',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'description' => '',
                              'display_id'  => 'AJ302601',
                              'primary_id'  => 'AJ302601',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'description' => '',
                              'display_id'  => 'AJ302602',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'primary_id'  => 'AJ302602',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT',
                              'description' => '',
                              'display_id'  => 'AJ302603',
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'AJ302603',
                              'dbname'      => 'EMBL'
                          },
                          {
                              'primary_id'  => 'AL035402',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'display_id'  => 'AL035402',
                              'description' => '',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT',
                              'display_id'  => 'AL662791',
                              'description' => '',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'primary_id'  => 'AL662791'
                          },
                          {
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT',
                              'display_id'  => 'AL662865',
                              'description' => '',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'primary_id'  => 'AL662865'
                          },
                          {
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT',
                              'display_id'  => 'AL929561',
                              'description' => '',
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'AL929561',
                              'dbname'      => 'EMBL'
                          },
                          {
                              'dbname'      => 'EMBL',
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'BC103870',
                              'display_id'  => 'BC103870',
                              'description' => '',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'description' => '',
                              'display_id'  => 'BC103871',
                              'primary_id'  => 'BC103871',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'display_id'  => 'BC103872',
                              'description' => '',
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'BC103872',
                              'dbname'      => 'EMBL',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT',
                              'description' => '',
                              'display_id'  => 'BK004522',
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'BK004522',
                              'dbname'      => 'EMBL'
                          },
                          {
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT',
                              'description' => '',
                              'display_id'  => 'BX248413',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'primary_id'  => 'BX248413'
                          },
                          {
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => '',
                              'dbname'      => 'EMBL',
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'BX927167',
                              'display_id'  => 'BX927167',
                              'description' => ''
                          },
                          {
                              'primary_id'  => 'CAB42853',
                              'db_display'  => 'INSDC protein ID',
                              'dbname'      => 'protein_id',
                              'display_id'  => 'CAB42853.1',
                              'description' => '',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT',
                              'display_id'  => 'CAC20514.1',
                              'description' => '',
                              'db_display'  => 'INSDC protein ID',
                              'dbname'      => 'protein_id',
                              'primary_id'  => 'CAC20514'
                          },
                          {
                              'display_id'  => 'CAC20515.1',
                              'description' => '',
                              'dbname'      => 'protein_id',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'CAC20515',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT',
                              'description' => '',
                              'display_id'  => 'CAC20516.1',
                              'db_display'  => 'INSDC protein ID',
                              'dbname'      => 'protein_id',
                              'primary_id'  => 'CAC20516'
                          },
                          {
                              'description' => '',
                              'display_id'  => 'CAC20517.1',
                              'dbname'      => 'protein_id',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'CAC20517',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'dbname'      => 'protein_id',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'CAC20518',
                              'display_id'  => 'CAC20518.1',
                              'description' => '',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'CAC20519',
                              'dbname'      => 'protein_id',
                              'description' => '',
                              'display_id'  => 'CAC20519.1',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => '',
                              'dbname'      => 'protein_id',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'CAC20520',
                              'display_id'  => 'CAC20520.1',
                              'description' => ''
                          },
                          {
                              'db_display'  => 'INSDC protein ID',
                              'dbname'      => 'protein_id',
                              'primary_id'  => 'CAC20521',
                              'description' => '',
                              'display_id'  => 'CAC20521.1',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'primary_id'  => 'CAC20522',
                              'db_display'  => 'INSDC protein ID',
                              'dbname'      => 'protein_id',
                              'display_id'  => 'CAC20522.1',
                              'description' => '',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'display_id'  => 'CAC20523.1',
                              'description' => '',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'CAC20523',
                              'dbname'      => 'protein_id',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'dbname'      => 'protein_id',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'CAI18243',
                              'description' => '',
                              'display_id'  => 'CAI18243.1',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'description' => '',
                              'display_id'  => 'CAI41643.1',
                              'primary_id'  => 'CAI41643',
                              'db_display'  => 'INSDC protein ID',
                              'dbname'      => 'protein_id',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'description' => '',
                              'display_id'  => 'CAI41768.2',
                              'dbname'      => 'protein_id',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'CAI41768',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => '',
                              'dbname'      => 'protein_id',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'CAM26052',
                              'display_id'  => 'CAM26052.1',
                              'description' => ''
                          },
                          {
                              'dbname'      => 'protein_id',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'CAQ07349',
                              'description' => '',
                              'display_id'  => 'CAQ07349.1',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT',
                              'description' => '',
                              'display_id'  => 'CAQ07643.1',
                              'dbname'      => 'protein_id',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'CAQ07643'
                          },
                          {
                              'description' => '',
                              'display_id'  => 'CAQ07834.1',
                              'primary_id'  => 'CAQ07834',
                              'db_display'  => 'INSDC protein ID',
                              'dbname'      => 'protein_id',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'description' => '',
                              'display_id'  => 'CAQ08425.1',
                              'db_display'  => 'INSDC protein ID',
                              'dbname'      => 'protein_id',
                              'primary_id'  => 'CAQ08425',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'db_display'  => 'European Nucleotide Archive',
                              'primary_id'  => 'CH471081',
                              'dbname'      => 'EMBL',
                              'display_id'  => 'CH471081',
                              'description' => '',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => ''
                          },
                          {
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => '',
                              'primary_id'  => 'CR759835',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'display_id'  => 'CR759835',
                              'description' => ''
                          },
                          {
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => '',
                              'primary_id'  => 'CR759957',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'description' => '',
                              'display_id'  => 'CR759957'
                          },
                          {
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => '',
                              'db_display'  => 'European Nucleotide Archive',
                              'dbname'      => 'EMBL',
                              'primary_id'  => 'CR936923',
                              'display_id'  => 'CR936923',
                              'description' => ''
                          },
                          {
                              'display_id'  => 'DAA04920.1',
                              'description' => '',
                              'db_display'  => 'INSDC protein ID',
                              'dbname'      => 'protein_id',
                              'primary_id'  => 'DAA04920',
                              'info_text'   => '',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => '',
                              'dbname'      => 'protein_id',
                              'db_display'  => 'INSDC protein ID',
                              'primary_id'  => 'EAX03181',
                              'display_id'  => 'EAX03181.1',
                              'description' => ''
                          },
                          {
                              'info_text'   => 'Generated via main',
                              'info_type'   => 'DEPENDENT',
                              'description' => 'molecular_function',
                              'display_id'  => 'GO:0003674',
                              'db_display'  => 'GOSlim GOA',
                              'primary_id'  => 'GO:0003674',
                              'dbname'      => 'goslim_goa'
                          },
                          {
                              'description' => 'signal transducer activity',
                              'display_id'  => 'GO:0004871',
                              'primary_id'  => 'GO:0004871',
                              'db_display'  => 'GOSlim GOA',
                              'dbname'      => 'goslim_goa',
                              'info_text'   => 'Generated via main',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'display_id'       => 'GO:0004930',
                              'associated_xrefs' => [],
                              'description'      => 'GO',
                              'dbname'           => 'GO',
                              'primary_id'       => 'GO:0004930',
                              'linkage_types'    => [
                                  {
                                      'evidence' => 'G-protein coupled receptor activity',
                                      'source'   => {
                                          'display_id'      => undef,
                                          'description'     => undef,
                                          'primary_id'      => 'IEA',
                                          'db_display_name' => undef,
                                          'dbname'          => undef
                                      }
                                  }
                              ]
                          },
                          {
                              'dbname'           => 'GO',
                              'primary_id'       => 'GO:0004984',
                              'description'      => 'GO',
                              'associated_xrefs' => [],
                              'display_id'       => 'GO:0004984',
                              'linkage_types'    => [
                                  {
                                      'evidence' => 'olfactory receptor activity',
                                      'source'   => {
                                          'description'     => undef,
                                          'display_id'      => undef,
                                          'db_display_name' => undef,
                                          'primary_id'      => 'IEA',
                                          'dbname'          => undef
                                      }
                                  }
                              ]
                          },
                          {
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => 'Generated via main',
                              'db_display'  => 'GOSlim GOA',
                              'primary_id'  => 'GO:0005575',
                              'dbname'      => 'goslim_goa',
                              'display_id'  => 'GO:0005575',
                              'description' => 'cellular_component'
                          },
                          {
                              'info_text'   => 'Generated via main',
                              'info_type'   => 'DEPENDENT',
                              'description' => 'cell',
                              'display_id'  => 'GO:0005623',
                              'db_display'  => 'GOSlim GOA',
                              'primary_id'  => 'GO:0005623',
                              'dbname'      => 'goslim_goa'
                          },
                          {
                              'db_display'  => 'GOSlim GOA',
                              'dbname'      => 'goslim_goa',
                              'primary_id'  => 'GO:0005886',
                              'description' => 'plasma membrane',
                              'display_id'  => 'GO:0005886',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => 'Generated via main'
                          },
                          {
                              'description'      => 'GO',
                              'associated_xrefs' => [],
                              'display_id'       => 'GO:0005886',
                              'dbname'           => 'GO',
                              'primary_id'       => 'GO:0005886',
                              'linkage_types'    => [
                                  {
                                      'source'   => {
                                          'description'     => undef,
                                          'display_id'      => undef,
                                          'db_display_name' => undef,
                                          'dbname'          => undef,
                                          'primary_id'      => 'TAS'
                                      },
                                      'evidence' => 'plasma membrane'
                                  }
                              ]
                          },
                          {
                              'display_id'  => 'GO:0007165',
                              'description' => 'signal transduction',
                              'db_display'  => 'GOSlim GOA',
                              'dbname'      => 'goslim_goa',
                              'primary_id'  => 'GO:0007165',
                              'info_text'   => 'Generated via main',
                              'info_type'   => 'DEPENDENT'
                          },
                          {
                              'linkage_types'    => [
                                  {
                                      'source'   => {
                                          'db_display_name' => 'Interpro',
                                          'primary_id'      => 'IEA',
                                          'dbname'          => 'G protein-coupled receptor, rhodopsin-like',
                                          'display_id'      => 'IPR000276',
                                          'description'     => 'GPCR_Rhodpsn'
                                      },
                                      'evidence' => 'G-protein coupled receptor signaling pathway'
                                  }
                              ],
                              'associated_xrefs' => [],
                              'description'      => 'GO',
                              'display_id'       => 'GO:0007186',
                              'primary_id'       => 'GO:0007186',
                              'dbname'           => 'GO'
                          },
                          {
                              'primary_id'  => 'GO:0008150',
                              'db_display'  => 'GOSlim GOA',
                              'dbname'      => 'goslim_goa',
                              'description' => 'biological_process',
                              'display_id'  => 'GO:0008150',
                              'info_type'   => 'DEPENDENT',
                              'info_text'   => 'Generated via main'
                          },
                          {
                              'associated_xrefs' => [],
                              'description'      => 'GO',
                              'display_id'       => 'GO:0016021',
                              'primary_id'       => 'GO:0016021',
                              'dbname'           => 'GO',
                              'linkage_types'    => [
                                  {
                                      'source'   => {
                                          'db_display_name' => undef,
                                          'primary_id'      => 'IEA',
                                          'dbname'          => undef,
                                          'display_id'      => undef,
                                          'description'     => undef
                                      },
                                      'evidence' => 'integral to membrane'
                                  }
                              ]
                          },
                          {
                              'display_id'  => 'NP_112165.1',
                              'description' => 'olfactory receptor 2W1 ',
                              'db_display'  => 'RefSeq peptide',
                              'dbname'      => 'RefSeq_peptide',
                              'primary_id'  => 'NP_112165',
                              'info_text'   => '',
                              'info_type'   => 'SEQUENCE_MATCH'
                          },
                          {
                              'primary_id'  => 'OTTHUMP00000029054',
                              'db_display'  => 'Vega translation',
                              'dbname'      => 'Vega_translation',
                              'description' => undef,
                              'display_id'  => 'OTTHUMP00000029054',
                              'info_type'   => 'NONE',
                              'info_text'   => 'Added during ensembl-vega production'
                          },
                          {
                              'display_id'  => 'OR2W1_HUMAN',
                              'primary_id'  => 'Q9Y3N9',
                              'dbname'      => 'Uniprot/SWISSPROT',
                              'info_text'   => 'Generated via uniprot_mapped',
                              'info_type'   => 'DIRECT',
                              'description' => 'Olfactory receptor 2W1 ',
                              'synonyms'    => [
                                  'B0S7Y5',
                                  'Q5JNZ1',
                                  'Q6IEU0',
                                  'Q96R17',
                                  'Q9GZL0',
                                  'Q9GZL1'
                              ],
                              'db_display'  => 'UniProtKB/Swiss-Prot'
                          },
                          {
                              'description' => undef,
                              'display_id'  => 'UPI000003FF8A',
                              'primary_id'  => 'UPI000003FF8A',
                              'db_display'  => 'UniParc',
                              'dbname'      => 'UniParc',
                              'info_text'   => '',
                              'info_type'   => 'CHECKSUM'
                          }
                      ],
                      'version'             => 1,
                      'previous_ids'        => [
                          'bananap'
                      ],
                      'protein_features'    => [
                          {
                              'start'               => 1,
                              'ensembl_object_type' => 'protein_feature',
                              'name'                => 'SSF81321',
                              'translation_id'      => 'ENSP00000366380',
                              'dbname'              => 'Superfamily',
                              'end'                 => 313
                          },
                          {
                              'start'               => 26,
                              'ensembl_object_type' => 'protein_feature',
                              'name'                => 'PF10323',
                              'translation_id'      => 'ENSP00000366380',
                              'interpro_ac'         => 'IPR999999',
                              'dbname'              => 'Pfam',
                              'end'                 => 298
                          },
                          {
                              'name'                => 'PR00237',
                              'translation_id'      => 'ENSP00000366380',
                              'start'               => 26,
                              'ensembl_object_type' => 'protein_feature',
                              'end'                 => 50,
                              'dbname'              => 'Prints'
                          },
                          {
                              'end'                 => 48,
                              'dbname'              => 'transmembrane',
                              'name'                => 'Tmhmm',
                              'translation_id'      => 'ENSP00000366380',
                              'start'               => 26,
                              'ensembl_object_type' => 'protein_feature'
                          },
                          {
                              'end'                  => 290,
                              'interpro_description' => 'G protein-coupled receptor, rhodopsin-like',
                              'interpro_ac'          => 'IPR000276',
                              'dbname'               => 'Pfam',
                              'name'                 => 'PF00001',
                              'translation_id'       => 'ENSP00000366380',
                              'start'                => 41,
                              'ensembl_object_type'  => 'protein_feature'
                          },
                          {
                              'end'                  => 290,
                              'interpro_description' => 'G protein-coupled receptor, rhodopsin-like',
                              'interpro_ac'          => 'IPR000276',
                              'dbname'               => 'Pfam',
                              'name'                 => 'PF00001',
                              'translation_id'       => 'ENSP00000366380',
                              'start'                => 41,
                              'interpro_name'        => 'GPCR_Rhodpsn',
                              'ensembl_object_type'  => 'protein_feature'
                          },
                          {
                              'start'               => 41,
                              'ensembl_object_type' => 'protein_feature',
                              'name'                => 'PS50262',
                              'translation_id'      => 'ENSP00000366380',
                              'dbname'              => 'Prosite_profiles',
                              'end'                 => 290
                          },
                          {
                              'name'                => 'PR00237',
                              'translation_id'      => 'ENSP00000366380',
                              'start'               => 59,
                              'ensembl_object_type' => 'protein_feature',
                              'end'                 => 80,
                              'dbname'              => 'Prints'
                          },
                          {
                              'ensembl_object_type' => 'protein_feature',
                              'start'               => 61,
                              'translation_id'      => 'ENSP00000366380',
                              'name'                => 'Tmhmm',
                              'dbname'              => 'transmembrane',
                              'end'                 => 83
                          },
                          {
                              'end'                 => 103,
                              'dbname'              => 'Prints',
                              'translation_id'      => 'ENSP00000366380',
                              'name'                => 'PR00245',
                              'ensembl_object_type' => 'protein_feature',
                              'start'               => 92
                          },
                          {
                              'name'                => 'Tmhmm',
                              'translation_id'      => 'ENSP00000366380',
                              'start'               => 98,
                              'ensembl_object_type' => 'protein_feature',
                              'end'                 => 120,
                              'dbname'              => 'transmembrane'
                          },
                          {
                              'ensembl_object_type' => 'protein_feature',
                              'start'               => 104,
                              'translation_id'      => 'ENSP00000366380',
                              'name'                => 'PR00237',
                              'dbname'              => 'Prints',
                              'end'                 => 126
                          },
                          {
                              'end'                 => 141,
                              'dbname'              => 'Prints',
                              'translation_id'      => 'ENSP00000366380',
                              'name'                => 'PR00245',
                              'ensembl_object_type' => 'protein_feature',
                              'start'               => 129
                          },
                          {
                              'translation_id'      => 'ENSP00000366380',
                              'name'                => 'Tmhmm',
                              'ensembl_object_type' => 'protein_feature',
                              'start'               => 140,
                              'end'                 => 162,
                              'dbname'              => 'transmembrane'
                          },
                          {
                              'end'                 => 192,
                              'dbname'              => 'Prints',
                              'translation_id'      => 'ENSP00000366380',
                              'name'                => 'PR00245',
                              'ensembl_object_type' => 'protein_feature',
                              'start'               => 176
                          },
                          {
                              'start'               => 199,
                              'ensembl_object_type' => 'protein_feature',
                              'name'                => 'PR00237',
                              'translation_id'      => 'ENSP00000366380',
                              'dbname'              => 'Prints',
                              'end'                 => 222
                          },
                          {
                              'end'                 => 221,
                              'dbname'              => 'transmembrane',
                              'name'                => 'Tmhmm',
                              'translation_id'      => 'ENSP00000366380',
                              'start'               => 199,
                              'ensembl_object_type' => 'protein_feature'
                          },
                          {
                              'ensembl_object_type' => 'protein_feature',
                              'start'               => 202,
                              'translation_id'      => 'ENSP00000366380',
                              'name'                => 'Seg',
                              'dbname'              => 'low_complexity',
                              'end'                 => 216
                          },
                          {
                              'ensembl_object_type' => 'protein_feature',
                              'start'               => 236,
                              'translation_id'      => 'ENSP00000366380',
                              'name'                => 'PR00245',
                              'dbname'              => 'Prints',
                              'end'                 => 245
                          },
                          {
                              'end'                 => 263,
                              'dbname'              => 'transmembrane',
                              'translation_id'      => 'ENSP00000366380',
                              'name'                => 'Tmhmm',
                              'ensembl_object_type' => 'protein_feature',
                              'start'               => 241
                          },
                          {
                              'name'                => 'PR00237',
                              'translation_id'      => 'ENSP00000366380',
                              'start'               => 272,
                              'ensembl_object_type' => 'protein_feature',
                              'end'                 => 298,
                              'dbname'              => 'Prints'
                          },
                          {
                              'end'                 => 292,
                              'dbname'              => 'transmembrane',
                              'translation_id'      => 'ENSP00000366380',
                              'name'                => 'Tmhmm',
                              'ensembl_object_type' => 'protein_feature',
                              'start'               => 273
                          },
                          {
                              'translation_id'      => 'ENSP00000366380',
                              'name'                => 'PR00245',
                              'ensembl_object_type' => 'protein_feature',
                              'start'               => 283,
                              'end'                 => 294,
                              'dbname'              => 'Prints'
                          }
                      ]
                  }
              ],
              'exons'               => [
                  {
                      'version'             => 1,
                      'end'                 => 29013017,
                      'seq_region_name'     => '6',
                      'rank'                => 1,
                      'ensembl_object_type' => 'exon',
                      'id'                  => 'ENSE00001691220',
                      'start'               => 29011990,
                      'strand'              => -1,
                      'coord_system'        => {
                          'version' => 'GRCh38',
                          'name'    => 'chromosome'
                      }
                  }
              ],
              'ensembl_object_type' => 'transcript',
              'id'                  => 'ENST00000377175',
              'description'         => undef,
              'xrefs'               => [
                  {
                      'dbname'      => 'HGNC',
                      'primary_id'  => '8281',
                      'display_id'  => 'OR2W1',
                      'info_type'   => 'DIRECT',
                      'info_text'   => 'Generated via ensembl_manual',
                      'db_display'  => 'HGNC Symbol',
                      'synonyms'    => [
                          'hs6M1-15'
                      ],
                      'description' => 'olfactory receptor, family 2, subfamily W, member 1'
                  },
                  {
                      'dbname'      => 'CCDS',
                      'db_display'  => 'CCDS',
                      'primary_id'  => 'CCDS4656',
                      'description' => '',
                      'display_id'  => 'CCDS4656.1',
                      'info_type'   => 'DIRECT',
                      'info_text'   => ''
                  },
                  {
                      'info_type'   => 'DIRECT',
                      'info_text'   => 'Generated via otherfeatures',
                      'db_display'  => 'RefSeq mRNA',
                      'primary_id'  => 'NM_030903',
                      'dbname'      => 'RefSeq_mRNA',
                      'description' => '',
                      'display_id'  => 'NM_030903.3'
                  },
                  {
                      'description' => 'olfactory receptor, family 2, subfamily W, member 1',
                      'display_id'  => 'OR2W1-001',
                      'db_display'  => 'HGNC transcript name',
                      'dbname'      => 'HGNC_trans_name',
                      'primary_id'  => 'OR2W1-001',
                      'info_text'   => '',
                      'info_type'   => 'MISC'
                  },
                  {
                      'display_id'  => 'OR2W1-001',
                      'description' => undef,
                      'primary_id'  => 'OTTHUMT00000076053',
                      'db_display'  => 'Vega transcript',
                      'dbname'      => 'Vega_transcript',
                      'info_text'   => '',
                      'info_type'   => 'NONE'
                  },
                  {
                      'info_text'   => 'Added during ensembl-vega production',
                      'info_type'   => 'NONE',
                      'description' => undef,
                      'display_id'  => 'OTTHUMT00000076053',
                      'primary_id'  => 'OTTHUMT00000076053',
                      'db_display'  => 'Vega transcript',
                      'dbname'      => 'Vega_transcript'
                  },
                  {
                      'primary_id'  => 'OTTHUMT00000076053',
                      'db_display'  => 'Transcript having exact match between ENSEMBL and HAVANA',
                      'dbname'      => 'shares_CDS_and_UTR_with_OTTT',
                      'description' => undef,
                      'display_id'  => 'OTTHUMT00000076053',
                      'info_type'   => 'NONE',
                      'info_text'   => ''
                  },
                  {
                      'db_display'  => 'UCSC Stable ID',
                      'primary_id'  => 'uc003nlw.2',
                      'dbname'      => 'UCSC',
                      'display_id'  => 'uc003nlw.2',
                      'description' => undef,
                      'info_type'   => 'COORDINATE_OVERLAP',
                      'info_text'   => ''
                  }
              ],
              'gene_id'             => 'ENSG00000204704',
              'analysis_display'    => 'Ensembl/Havana merge',
              'previous_ids'        => [
                  'bananat'
              ],
              'supporting_features' => [
                  {
                      'analysis_display' => 'Human cDNAs (cdna2genome)',
                      'start'            => 1,
                      'analysis'         => 'human_cdna2genome',
                      'evalue'           => undef,
                      'id'               => 'NM_030903.3',
                      'db_display'       => 'RefSeq DNA',
                      'end'              => 963,
                      'db_name'          => 'RefSeq_dna'
                  },
                  {
                      'id'               => 'CCDS4656.1',
                      'db_display'       => 'CCDS',
                      'analysis'         => 'ccds',
                      'evalue'           => undef,
                      'start'            => 1,
                      'analysis_display' => 'CCDS set',
                      'db_name'          => 'CCDS',
                      'end'              => 963
                  }
              ],
              'end'                 => 29013017,
              'version'             => 1
          }
      ],
      'previous_ids'        => [
          'bananag'
      ]
  };
  # warn Dumper(sort_gene($gene));
  is_deeply(sort_gene($gene),
      sort_gene($expected_gene),
      "Testing gene structure");
};

subtest "Checking ncRNA gene", sub {
  my ($gene) = grep {$_->{id} eq 'ENSG00000261370'} @$genes;
  ok($gene, "Test gene found");
  my $expected_gene = {
      'id'                  => 'ENSG00000261370',
      'analysis'            => 'havana',
      'analysis_display'    => 'Havana',
      'coord_system'        => { 'name' => 'chromosome', 'version' => 'GRCh38' },
      'transcripts'         => [ {
          'analysis'            => 'havana',
          'analysis_display'    => 'Havana',
          'strand'              => '-1',
          'biotype'             => 'processed_pseudogene',
          'version'             => '1',
          'description'         => undef,
          'gene_id'             => 'ENSG00000261370',
          'name'                => 'RPL14P5-001',
          'xrefs'               => [ {
              'db_display'  => 'Vega transcript',
              'dbname'      => 'Vega_transcript',
              'primary_id'  => 'OTTHUMT00000427110',
              'description' => undef,
              'info_text'   => '',
              'display_id'  => 'RP11-309M23.2-001',
              'info_type'   => 'NONE' }, {
              'info_type'   => 'NONE',
              'info_text'   => 'Added during ensembl-vega production',
              'display_id'  => 'OTTHUMT00000427110',
              'primary_id'  => 'OTTHUMT00000427110',
              'description' => undef,
              'dbname'      => 'Vega_transcript',
              'db_display'  => 'Vega transcript' }, {
              'info_type'   => 'NONE',
              'display_id'  => 'OTTHUMT00000427110',
              'info_text'   => '',
              'primary_id'  => 'OTTHUMT00000427110',
              'description' => undef,
              'dbname'      => 'OTTT',
              'db_display'  => 'Havana transcript' }, {
              'display_id'  => 'RP11-309M23.2-001',
              'info_text'   => '',
              'info_type'   => 'DIRECT',
              'db_display'  => 'Clone-based (Vega)',
              'dbname'      => 'Clone_based_vega_transcript',
              'description' => '',
              'primary_id'  => 'RP11-309M23.2-001' }, {
              'info_text'   => 'Generated via ensembl_manual',
              'display_id'  => 'RPL14P5',
              'info_type'   => 'DIRECT',
              'db_display'  => 'HGNC Symbol',
              'dbname'      => 'HGNC',
              'description' => 'ribosomal protein L14 pseudogene 5',
              'primary_id'  => '37720' }, {
              'info_type'   => 'MISC',
              'display_id'  => 'RPL14P5-001',
              'info_text'   => '',
              'description' => 'ribosomal protein L14 pseudogene 5',
              'primary_id'  => 'RPL14P5-001',
              'db_display'  => 'HGNC transcript name',
              'dbname'      => 'HGNC_trans_name' } ],
          'coord_system'        =>
              { 'version' => 'GRCh38', 'name' => 'chromosome' },
          'id'                  => 'ENST00000569325',
          'start'               => '969238',
          'seq_region_name'     => 'HG480_HG481_PATCH',
          'end'                 => '970836',
          'exons'               => [ {
              'version'             => '1',
              'start'               => '970445',
              'seq_region_name'     => 'HG480_HG481_PATCH',
              'strand'              => '-1',
              'end'                 => '970836',
              'id'                  => 'ENSE00002580842',
              'rank'                => '1',
              'coord_system'        =>
                  { 'name' => 'chromosome', 'version' => 'GRCh38' },

              'ensembl_object_type' => 'exon' }, {
              'ensembl_object_type' => 'exon',
              'coord_system'        =>
                  { 'name' => 'chromosome', 'version' => 'GRCh38' },

              'rank'                => '2',
              'id'                  => 'ENSE00002621881',
              'strand'              => '-1',
              'end'                 => '970115',
              'start'               => '969827',
              'seq_region_name'     => 'HG480_HG481_PATCH',
              'version'             => '1' }, {
              'ensembl_object_type' => 'exon',
              'rank'                => '3',
              'coord_system'        =>
                  { 'name' => 'chromosome', 'version' => 'GRCh38' },
              'id'                  => 'ENSE00002622269',
              'start'               => '969238',
              'seq_region_name'     => 'HG480_HG481_PATCH',
              'end'                 => '969286',
              'strand'              => '-1',
              'version'             => '1' } ],
          'probes'              => [
              {
                  'probe'  => '214727_at',
                  'array'  => 'HG-Focus',
                  'vendor' => 'AFFY_HG_Focus'
              },
              {
                  'array'  => 'HG-U133_Plus_2',
                  'probe'  => '214727_at',
                  'vendor' => 'AFFY_HG_U133_Plus_2'
              }
          ],

          'ensembl_object_type' => 'transcript' } ],
      'version'             => '1',
      'biotype'             => 'pseudogene',
      'source'              => 'havana',
      'strand'              => '-1',
      'end'                 => '970836',
      'seq_region_name'     => 'HG480_HG481_PATCH',
      'start'               => '969238',
      'description'         =>
          'ribosomal protein L14 pseudogene 5 [Source:HGNC Symbol;Acc:37720]',
      'xrefs'               => [ { 'description' => undef,
          'primary_id'                           => 'OTTHUMG00000174633',
          'dbname'                               => 'OTTG',
          'db_display'                           => 'Havana gene',
          'info_type'                            => 'NONE',
          'info_text'                            => '',
          'display_id'                           => 'OTTHUMG00000174633' }, {
          'db_display'  => 'ArrayExpress',
          'dbname'      => 'ArrayExpress',
          'primary_id'  => 'ENSG00000261370',
          'description' => '',
          'display_id'  => 'ENSG00000261370',
          'info_text'   => '',
          'info_type'   => 'DIRECT' }, {
          'primary_id'  => '37720',
          'description' => 'ribosomal protein L14 pseudogene 5',
          'db_display'  => 'HGNC Symbol',
          'dbname'      => 'HGNC',
          'info_type'   => 'DIRECT',
          'info_text'   => 'Generated via ensembl_manual',
          'display_id'  => 'RPL14P5' } ],
      'ensembl_object_type' => 'gene',
      'name'                => 'RPL14P5' };

  is_deeply(sort_gene($gene),
      sort_gene($expected_gene),
      "Testing gene structure");
};

done_testing;

