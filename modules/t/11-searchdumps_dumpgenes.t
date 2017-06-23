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
	use_ok('Bio::EnsEMBL::Production::Search::GeneFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

use Bio::EnsEMBL::Production::Search::GeneFetcher;
use Bio::EnsEMBL::Test::MultiTestDB;

my $test        = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens_dump');
my $core_dba    = $test->get_DBAdaptor('core');
my $funcgen_dba = $test->get_DBAdaptor('funcgen');
my $fetcher     = Bio::EnsEMBL::Production::Search::GeneFetcher->new();

my $genes = $fetcher->fetch_genes_for_dba( $core_dba, undef, $funcgen_dba );
is( scalar(@$genes), 88, "Correct number of genes" );
is( scalar( grep { lc $_->{biotype} eq 'lrg' } @$genes ),
	0, "Checking for LRGs" );

is( scalar(
		  grep { defined $_->{is_haplotype} && $_->{is_haplotype} == 1 } @$genes
	),
	1,
	"Haplotype genes" );
is( scalar(
		 grep { !defined $_->{is_haplotype} || $_->{is_haplotype} == 0 } @$genes
	),
	87,
	"Non-haplotype genes" );
	
	subtest "Checking protein_coding gene", sub {
	my ($gene) = grep { $_->{id} eq 'ENSG00000204704' } @$genes;
	my $expected_gene = {
          'strand' => '-1',
          'end' => '29013017',
          'transcripts' => [
                             {
                               'end' => '29013017',
                               'strand' => '-1',
                               'seq_region_name' => '6',
                               'xrefs' => [
                                            {
                                              'primary_id' => 'OTTHUMT00000076053',
                                              'db_display' => 'Vega transcript',
                                              'info_type' => 'NONE',
                                              'info_text' => 'Added during ensembl-vega production',
                                              'description' => undef,
                                              'display_id' => 'OTTHUMT00000076053',
                                              'dbname' => 'Vega_transcript'
                                            },
                                            {
                                              'primary_id' => 'OTTHUMT00000076053',
                                              'db_display' => 'Vega transcript',
                                              'info_type' => 'NONE',
                                              'description' => undef,
                                              'info_text' => '',
                                              'display_id' => 'OR2W1-001',
                                              'dbname' => 'Vega_transcript'
                                            },
                                            {
                                              'description' => undef,
                                              'info_text' => '',
                                              'display_id' => 'OTTHUMT00000076053',
                                              'dbname' => 'shares_CDS_and_UTR_with_OTTT',
                                              'primary_id' => 'OTTHUMT00000076053',
                                              'db_display' => 'Transcript having exact match between ENSEMBL and HAVANA',
                                              'info_type' => 'NONE'
                                            },
                                            {
                                              'db_display' => 'UCSC Stable ID',
                                              'primary_id' => 'uc003nlw.2',
                                              'info_type' => 'COORDINATE_OVERLAP',
                                              'description' => undef,
                                              'info_text' => '',
                                              'display_id' => 'uc003nlw.2',
                                              'dbname' => 'UCSC'
                                            },
                                            {
                                              'dbname' => 'CCDS',
                                              'display_id' => 'CCDS4656.1',
                                              'description' => '',
                                              'info_text' => '',
                                              'info_type' => 'DIRECT',
                                              'primary_id' => 'CCDS4656',
                                              'db_display' => 'CCDS'
                                            },
                                            {
                                              'db_display' => 'HGNC Symbol',
                                              'info_type' => 'DIRECT',
                                              'display_id' => 'OR2W1',
                                              'dbname' => 'HGNC',
                                              'synonyms' => [
                                                              'hs6M1-15'
                                                            ],
                                              'primary_id' => '8281',
                                              'info_text' => 'Generated via ensembl_manual',
                                              'description' => 'olfactory receptor, family 2, subfamily W, member 1'
                                            },
                                            {
                                              'dbname' => 'HGNC_trans_name',
                                              'display_id' => 'OR2W1-001',
                                              'description' => 'olfactory receptor, family 2, subfamily W, member 1',
                                              'info_text' => '',
                                              'info_type' => 'MISC',
                                              'primary_id' => 'OR2W1-001',
                                              'db_display' => 'HGNC transcript name'
                                            },
                                            {
                                              'info_type' => 'DIRECT',
                                              'db_display' => 'RefSeq mRNA',
                                              'primary_id' => 'NM_030903',
                                              'display_id' => 'NM_030903.3',
                                              'dbname' => 'RefSeq_mRNA',
                                              'info_text' => 'Generated via otherfeatures',
                                              'description' => ''
                                            }
                                          ],
                               'id' => 'ENST00000377175',
                               'translations' => [
                                                   {
                                                     'ensembl_object_type' => 'translation',
                                                     'transcript_id' => 'ENST00000377175',
                                                     'protein_features' => [
                                                                             {
                                                                               'name' => 'PF00001',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef,
                                                                               'start' => '41',
                                                                               'end' => '290',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'dbname' => 'Pfam'
                                                                             },
                                                                             {
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef,
                                                                               'name' => 'PF10323',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'Pfam',
                                                                               'start' => '26',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'end' => '298'
                                                                             },
                                                                             {
                                                                               'dbname' => 'Prints',
                                                                               'start' => '26',
                                                                               'end' => '50',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef,
                                                                               'name' => 'PR00237',
                                                                               'ensembl_object_type' => 'protein_feature'
                                                                             },
                                                                             {
                                                                               'name' => 'PR00237',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef,
                                                                               'start' => '59',
                                                                               'end' => '80',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'dbname' => 'Prints'
                                                                             },
                                                                             {
                                                                               'dbname' => 'Prints',
                                                                               'start' => '104',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'end' => '126',
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef,
                                                                               'name' => 'PR00237',
                                                                               'ensembl_object_type' => 'protein_feature'
                                                                             },
                                                                             {
                                                                               'interpro_ac' => undef,
                                                                               'description' => undef,
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'PR00237',
                                                                               'dbname' => 'Prints',
                                                                               'end' => '222',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'start' => '199'
                                                                             },
                                                                             {
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'end' => '298',
                                                                               'start' => '272',
                                                                               'dbname' => 'Prints',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'PR00237',
                                                                               'interpro_ac' => undef,
                                                                               'description' => undef
                                                                             },
                                                                             {
                                                                               'dbname' => 'Prints',
                                                                               'end' => '103',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'start' => '92',
                                                                               'interpro_ac' => undef,
                                                                               'description' => undef,
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'PR00245'
                                                                             },
                                                                             {
                                                                               'interpro_ac' => undef,
                                                                               'description' => undef,
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'PR00245',
                                                                               'dbname' => 'Prints',
                                                                               'end' => '141',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'start' => '129'
                                                                             },
                                                                             {
                                                                               'dbname' => 'Prints',
                                                                               'start' => '176',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'end' => '192',
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef,
                                                                               'name' => 'PR00245',
                                                                               'ensembl_object_type' => 'protein_feature'
                                                                             },
                                                                             {
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef,
                                                                               'name' => 'PR00245',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'Prints',
                                                                               'start' => '236',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'end' => '245'
                                                                             },
                                                                             {
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'PR00245',
                                                                               'interpro_ac' => undef,
                                                                               'description' => undef,
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'end' => '294',
                                                                               'start' => '283',
                                                                               'dbname' => 'Prints'
                                                                             },
                                                                             {
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef,
                                                                               'name' => 'PS50262',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'Prosite_profiles',
                                                                               'start' => '41',
                                                                               'end' => '290',
                                                                               'translation_id' => 'ENSP00000366380'
                                                                             },
                                                                             {
                                                                               'interpro_ac' => undef,
                                                                               'description' => undef,
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'Seg',
                                                                               'dbname' => 'low_complexity',
                                                                               'end' => '216',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'start' => '202'
                                                                             },
                                                                             {
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'SSF81321',
                                                                               'interpro_ac' => undef,
                                                                               'description' => undef,
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'end' => '313',
                                                                               'start' => '1',
                                                                               'dbname' => 'Superfamily'
                                                                             },
                                                                             {
                                                                               'dbname' => 'transmembrane',
                                                                               'start' => '26',
                                                                               'end' => '48',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef,
                                                                               'name' => 'Tmhmm',
                                                                               'ensembl_object_type' => 'protein_feature'
                                                                             },
                                                                             {
                                                                               'dbname' => 'transmembrane',
                                                                               'start' => '61',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'end' => '83',
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef,
                                                                               'name' => 'Tmhmm',
                                                                               'ensembl_object_type' => 'protein_feature'
                                                                             },
                                                                             {
                                                                               'interpro_ac' => undef,
                                                                               'description' => undef,
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'Tmhmm',
                                                                               'dbname' => 'transmembrane',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'end' => '120',
                                                                               'start' => '98'
                                                                             },
                                                                             {
                                                                               'start' => '140',
                                                                               'end' => '162',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'dbname' => 'transmembrane',
                                                                               'name' => 'Tmhmm',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef
                                                                             },
                                                                             {
                                                                               'dbname' => 'transmembrane',
                                                                               'end' => '221',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'start' => '199',
                                                                               'interpro_ac' => undef,
                                                                               'description' => undef,
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'Tmhmm'
                                                                             },
                                                                             {
                                                                               'dbname' => 'transmembrane',
                                                                               'end' => '263',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'start' => '241',
                                                                               'interpro_ac' => undef,
                                                                               'description' => undef,
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'Tmhmm'
                                                                             },
                                                                             {
                                                                               'start' => '273',
                                                                               'end' => '292',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'dbname' => 'transmembrane',
                                                                               'name' => 'Tmhmm',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'description' => undef,
                                                                               'interpro_ac' => undef
                                                                             }
                                                                           ],
                                                     'version' => '1',
                                                     'xrefs' => [
                                                                  {
                                                                    'info_type' => 'NONE',
                                                                    'db_display' => 'Vega translation',
                                                                    'primary_id' => 'OTTHUMP00000029054',
                                                                    'dbname' => 'Vega_translation',
                                                                    'display_id' => 'OTTHUMP00000029054',
                                                                    'info_text' => 'Added during ensembl-vega production',
                                                                    'description' => undef
                                                                  },
                                                                  {
                                                                    'dbname' => 'Vega_translation',
                                                                    'display_id' => '191160',
                                                                    'info_text' => '',
                                                                    'description' => undef,
                                                                    'info_type' => 'NONE',
                                                                    'db_display' => 'Vega translation',
                                                                    'primary_id' => '191160'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'CH471081',
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'CH471081',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'BX927167',
                                                                    'display_id' => 'BX927167',
                                                                    'dbname' => 'EMBL',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'AL662865',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'display_id' => 'AL662865',
                                                                    'dbname' => 'EMBL',
                                                                    'info_text' => '',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'display_id' => 'AL662791',
                                                                    'dbname' => 'EMBL',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'AL662791',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'AL929561',
                                                                    'primary_id' => 'AL929561',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'AJ302594',
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'AJ302594',
                                                                    'db_display' => 'European Nucleotide Archive'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'AJ302595',
                                                                    'display_id' => 'AJ302595',
                                                                    'dbname' => 'EMBL',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'primary_id' => 'AJ302596',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'AJ302596'
                                                                  },
                                                                  {
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'AJ302597',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'AJ302597'
                                                                  },
                                                                  {
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'display_id' => 'AJ302598',
                                                                    'dbname' => 'EMBL',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'AJ302598',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'display_id' => 'AJ302599',
                                                                    'dbname' => 'EMBL',
                                                                    'primary_id' => 'AJ302599',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'display_id' => 'AJ302600',
                                                                    'dbname' => 'EMBL',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'AJ302600',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'display_id' => 'AJ302601',
                                                                    'dbname' => 'EMBL',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'AJ302601'
                                                                  },
                                                                  {
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'AJ302602',
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'AJ302602',
                                                                    'db_display' => 'European Nucleotide Archive'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'AJ302603',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'AJ302603',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'AL035402',
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'AL035402',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'BX248413',
                                                                    'display_id' => 'BX248413',
                                                                    'dbname' => 'EMBL',
                                                                    'info_text' => '',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'display_id' => 'CR759957',
                                                                    'dbname' => 'EMBL',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'CR759957',
                                                                    'db_display' => 'European Nucleotide Archive'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'CR936923',
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'CR936923',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'primary_id' => 'CR759835',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CR759835',
                                                                    'dbname' => 'EMBL'
                                                                  },
                                                                  {
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'display_id' => 'BC103870',
                                                                    'dbname' => 'EMBL',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'BC103870',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'BC103871',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'display_id' => 'BC103871',
                                                                    'dbname' => 'EMBL',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'display_id' => 'BC103872',
                                                                    'dbname' => 'EMBL',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'BC103872'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'AF399628',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'display_id' => 'AF399628',
                                                                    'dbname' => 'EMBL',
                                                                    'info_text' => '',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'BK004522',
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'BK004522',
                                                                    'db_display' => 'European Nucleotide Archive'
                                                                  },
                                                                  {
                                                                    'description' => 'biological_process',
                                                                    'info_text' => 'Generated via main',
                                                                    'dbname' => 'goslim_goa',
                                                                    'display_id' => 'GO:0008150',
                                                                    'primary_id' => 'GO:0008150',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'primary_id' => 'GO:0003674',
                                                                    'dbname' => 'goslim_goa',
                                                                    'display_id' => 'GO:0003674',
                                                                    'description' => 'molecular_function',
                                                                    'info_text' => 'Generated via main'
                                                                  },
                                                                  {
                                                                    'primary_id' => 'GO:0005575',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => 'Generated via main',
                                                                    'description' => 'cellular_component',
                                                                    'display_id' => 'GO:0005575',
                                                                    'dbname' => 'goslim_goa'
                                                                  },
                                                                  {
                                                                    'description' => 'cell',
                                                                    'info_text' => 'Generated via main',
                                                                    'display_id' => 'GO:0005623',
                                                                    'dbname' => 'goslim_goa',
                                                                    'primary_id' => 'GO:0005623',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'primary_id' => 'GO:0005886',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => 'Generated via main',
                                                                    'description' => 'plasma membrane',
                                                                    'display_id' => 'GO:0005886',
                                                                    'dbname' => 'goslim_goa'
                                                                  },
                                                                  {
                                                                    'dbname' => 'goslim_goa',
                                                                    'display_id' => 'GO:0004871',
                                                                    'info_text' => 'Generated via main',
                                                                    'description' => 'signal transducer activity',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'GO:0004871',
                                                                    'db_display' => 'GOSlim GOA'
                                                                  },
                                                                  {
                                                                    'primary_id' => 'GO:0007165',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => 'Generated via main',
                                                                    'description' => 'signal transduction',
                                                                    'dbname' => 'goslim_goa',
                                                                    'display_id' => 'GO:0007165'
                                                                  },
                                                                  {
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAC20514.1',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'CAC20514',
                                                                    'db_display' => 'INSDC protein ID'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAC20515',
                                                                    'display_id' => 'CAC20515.1',
                                                                    'dbname' => 'protein_id',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'display_id' => 'CAC20516.1',
                                                                    'dbname' => 'protein_id',
                                                                    'primary_id' => 'CAC20516',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAC20517',
                                                                    'display_id' => 'CAC20517.1',
                                                                    'dbname' => 'protein_id',
                                                                    'info_text' => '',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAC20518',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAC20518.1'
                                                                  },
                                                                  {
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAC20519',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAC20519.1'
                                                                  },
                                                                  {
                                                                    'display_id' => 'CAC20520.1',
                                                                    'dbname' => 'protein_id',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'CAC20520',
                                                                    'db_display' => 'INSDC protein ID'
                                                                  },
                                                                  {
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAC20521.1',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'CAC20521',
                                                                    'db_display' => 'INSDC protein ID'
                                                                  },
                                                                  {
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAC20522',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAC20522.1'
                                                                  },
                                                                  {
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'display_id' => 'CAC20523.1',
                                                                    'dbname' => 'protein_id',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAC20523',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAB42853',
                                                                    'display_id' => 'CAB42853.1',
                                                                    'dbname' => 'protein_id',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'CAI18243',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'display_id' => 'CAI18243.1',
                                                                    'dbname' => 'protein_id',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CAI41643.1',
                                                                    'dbname' => 'protein_id',
                                                                    'primary_id' => 'CAI41643',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'primary_id' => 'CAI41768',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAI41768.2'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'CAM26052',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAM26052.1',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'primary_id' => 'CAQ07349',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAQ07349.1'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'CAQ07643',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'display_id' => 'CAQ07643.1',
                                                                    'dbname' => 'protein_id',
                                                                    'info_text' => '',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAQ07834',
                                                                    'display_id' => 'CAQ07834.1',
                                                                    'dbname' => 'protein_id',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAQ08425.1',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAQ08425'
                                                                  },
                                                                  {
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'display_id' => 'EAX03181.1',
                                                                    'dbname' => 'protein_id',
                                                                    'primary_id' => 'EAX03181',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'AAI03871',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'display_id' => 'AAI03871.1',
                                                                    'dbname' => 'protein_id',
                                                                    'info_text' => '',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'primary_id' => 'AAI03872',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'info_text' => '',
                                                                    'display_id' => 'AAI03872.1',
                                                                    'dbname' => 'protein_id'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'AAI03873',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'display_id' => 'AAI03873.1',
                                                                    'dbname' => 'protein_id',
                                                                    'description' => '',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'display_id' => 'AAK95113.1',
                                                                    'dbname' => 'protein_id',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'AAK95113',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_text' => '',
                                                                    'description' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'DAA04920.1',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'DAA04920',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'primary_id' => 'NP_112165',
                                                                    'db_display' => 'RefSeq peptide',
                                                                    'info_type' => 'SEQUENCE_MATCH',
                                                                    'description' => 'olfactory receptor 2W1 ',
                                                                    'info_text' => '',
                                                                    'dbname' => 'RefSeq_peptide',
                                                                    'display_id' => 'NP_112165.1'
                                                                  },
                                                                  {
                                                                    'description' => undef,
                                                                    'info_text' => '',
                                                                    'dbname' => 'UniParc',
                                                                    'display_id' => 'UPI000003FF8A',
                                                                    'db_display' => 'UniParc',
                                                                    'primary_id' => 'UPI000003FF8A',
                                                                    'info_type' => 'CHECKSUM'
                                                                  },
                                                                  {
                                                                    'primary_id' => 'Q9Y3N9',
                                                                    'info_text' => 'Generated via uniprot_mapped',
                                                                    'description' => 'Olfactory receptor 2W1 ',
                                                                    'info_type' => 'DIRECT',
                                                                    'db_display' => 'UniProtKB/Swiss-Prot',
                                                                    'display_id' => 'OR2W1_HUMAN',
                                                                    'dbname' => 'Uniprot/SWISSPROT',
                                                                    'synonyms' => [
                                                                                    'B0S7Y5',
                                                                                    'Q5JNZ1',
                                                                                    'Q6IEU0',
                                                                                    'Q96R17',
                                                                                    'Q9GZL0',
                                                                                    'Q9GZL1'
                                                                                  ]
                                                                  },
                                                                  {
                                                                    'associated_xrefs' => [],
                                                                    'description' => 'GO',
                                                                    'dbname' => 'GO',
                                                                    'display_id' => 'GO:0004930',
                                                                    'primary_id' => 'GO:0004930',
                                                                    'linkage_types' => [
                                                                                         {
                                                                                           'evidence' => 'G-protein coupled receptor activity',
                                                                                           'source' => {
                                                                                                         'primary_id' => 'IEA',
                                                                                                         'description' => undef,
                                                                                                         'db_display_name' => undef,
                                                                                                         'display_id' => undef,
                                                                                                         'dbname' => undef
                                                                                                       }
                                                                                         }
                                                                                       ]
                                                                  },
                                                                  {
                                                                    'description' => 'GO',
                                                                    'associated_xrefs' => [],
                                                                    'display_id' => 'GO:0007186',
                                                                    'dbname' => 'GO',
                                                                    'primary_id' => 'GO:0007186',
                                                                    'linkage_types' => [
                                                                                         {
                                                                                           'source' => {
                                                                                                         'primary_id' => 'IEA',
                                                                                                         'db_display_name' => 'Interpro',
                                                                                                         'dbname' => 'G protein-coupled receptor, rhodopsin-like',
                                                                                                         'display_id' => 'IPR000276',
                                                                                                         'description' => 'GPCR_Rhodpsn'
                                                                                                       },
                                                                                           'evidence' => 'G-protein coupled receptor signaling pathway'
                                                                                         }
                                                                                       ]
                                                                  },
                                                                  {
                                                                    'linkage_types' => [
                                                                                         {
                                                                                           'source' => {
                                                                                                         'primary_id' => 'IEA',
                                                                                                         'description' => undef,
                                                                                                         'db_display_name' => undef,
                                                                                                         'display_id' => undef,
                                                                                                         'dbname' => undef
                                                                                                       },
                                                                                           'evidence' => 'integral to membrane'
                                                                                         }
                                                                                       ],
                                                                    'primary_id' => 'GO:0016021',
                                                                    'display_id' => 'GO:0016021',
                                                                    'dbname' => 'GO',
                                                                    'description' => 'GO',
                                                                    'associated_xrefs' => []
                                                                  },
                                                                  {
                                                                    'display_id' => 'GO:0004984',
                                                                    'dbname' => 'GO',
                                                                    'associated_xrefs' => [],
                                                                    'description' => 'GO',
                                                                    'linkage_types' => [
                                                                                         {
                                                                                           'source' => {
                                                                                                         'dbname' => undef,
                                                                                                         'display_id' => undef,
                                                                                                         'db_display_name' => undef,
                                                                                                         'description' => undef,
                                                                                                         'primary_id' => 'IEA'
                                                                                                       },
                                                                                           'evidence' => 'olfactory receptor activity'
                                                                                         }
                                                                                       ],
                                                                    'primary_id' => 'GO:0004984'
                                                                  },
                                                                  {
                                                                    'dbname' => 'GO',
                                                                    'display_id' => 'GO:0005886',
                                                                    'description' => 'GO',
                                                                    'associated_xrefs' => [],
                                                                    'linkage_types' => [
                                                                                         {
                                                                                           'evidence' => 'plasma membrane',
                                                                                           'source' => {
                                                                                                         'db_display_name' => undef,
                                                                                                         'display_id' => undef,
                                                                                                         'dbname' => undef,
                                                                                                         'description' => undef,
                                                                                                         'primary_id' => 'TAS'
                                                                                                       }
                                                                                         }
                                                                                       ],
                                                                    'primary_id' => 'GO:0005886'
                                                                  }
                                                                ],
                                                     'id' => 'ENSP00000366380'
                                                   }
                                                 ],
                               'seq_region_synonyms' => undef,
                               'name' => 'OR2W1-001',
                               'exons' => [
                                            {
                                              'start' => '29011990',
                                              'seq_region_name' => '6',
                                              'end' => '29013017',
                                              'strand' => '-1',
                                              'id' => 'ENSE00001691220',
                                              'version' => '1',
                                              'trans_id' => 'ENST00000377175',
                                              'rank' => '1',
                                              'coord_system' => {
                                                                  'name' => 'chromosome',
                                                                  'version' => 'GRCh38'
                                                                },
                                              'ensembl_object_type' => 'exon'
                                            }
                                          ],
                               'description' => undef,
                               'gene_id' => 'ENSG00000204704',
                               'analysis' => 'Ensembl/Havana merge',
                               'start' => '29011990',
                               'version' => '1',
                               'supporting_features' => [
                                                          {
                                                            'trans_id' => 'ENST00000377175',
                                                            'id' => 'NM_030903.3',
                                                            'end' => '963',
                                                            'analysis' => 'human_cdna2genome',
                                                            'db_name' => 'RefSeq_dna',
                                                            'db_display' => 'RefSeq DNA',
                                                            'start' => '1',
                                                            'evalue' => undef
                                                          },
                                                          {
                                                            'evalue' => undef,
                                                            'analysis' => 'ccds',
                                                            'end' => '963',
                                                            'db_name' => 'CCDS',
                                                            'db_display' => 'CCDS',
                                                            'start' => '1',
                                                            'trans_id' => 'ENST00000377175',
                                                            'id' => 'CCDS4656.1'
                                                          }
                                                        ],
                               'ensembl_object_type' => 'transcript',
                               'coord_system' => {
                              'name' => 'chromosome',
                              'version' => 'GRCh38'
                            },
                               'biotype' => 'protein_coding'
                             }
                           ],
          'analysis' => 'Ensembl/Havana merge',
          'seq_region_name' => '6',
          'start' => '29011990',
          'synonyms' => [
                          'hs6M1-15'
                        ],
          'xrefs' => [
                       {
                         'db_display' => 'Havana gene',
                         'primary_id' => 'OTTHUMG00000031048',
                         'info_type' => 'NONE',
                         'info_text' => '',
                         'description' => undef,
                         'dbname' => 'OTTG',
                         'display_id' => 'OTTHUMG00000031048'
                       },
                       {
                         'info_text' => '',
                         'description' => '',
                         'display_id' => 'ENSG00000204704',
                         'dbname' => 'ArrayExpress',
                         'db_display' => 'ArrayExpress',
                         'primary_id' => 'ENSG00000204704',
                         'info_type' => 'DIRECT'
                       },
                       {
                         'info_type' => 'DEPENDENT',
                         'db_display' => 'EntrezGene',
                         'dbname' => 'EntrezGene',
                         'display_id' => 'OR2W1',
                         'synonyms' => [
                                         'hs6M1-15'
                                       ],
                         'primary_id' => '26692',
                         'description' => 'olfactory receptor, family 2, subfamily W, member 1',
                         'info_text' => ''
                       },
                       {
                         'info_text' => 'Generated via ensembl_manual',
                         'description' => 'olfactory receptor, family 2, subfamily W, member 1',
                         'primary_id' => '8281',
                         'display_id' => 'OR2W1',
                         'dbname' => 'HGNC',
                         'synonyms' => [
                                         'hs6M1-15'
                                       ],
                         'db_display' => 'HGNC Symbol',
                         'info_type' => 'DIRECT'
                       },
                       {
                         'db_display' => 'UniProtKB Gene Name',
                         'primary_id' => 'OR2W1',
                         'info_type' => 'DEPENDENT',
                         'description' => '',
                         'info_text' => '',
                         'display_id' => 'OR2W1',
                         'dbname' => 'Uniprot_gn'
                       },
                       {
                         'description' => 'olfactory receptor, family 2, subfamily W, member 1',
                         'info_text' => '',
                         'dbname' => 'WikiGene',
                         'display_id' => 'OR2W1',
                         'db_display' => 'WikiGene',
                         'primary_id' => '26692',
                         'info_type' => 'DEPENDENT'
                       }
                     ],
          'version' => '2',
          'id' => 'ENSG00000204704',
          'ensembl_object_type' => 'gene',
          'coord_system' => {
                              'name' => 'chromosome',
                              'version' => 'GRCh38'
                            },
          'name' => 'OR2W1',
          'biotype' => 'protein_coding',
          'description' => 'olfactory receptor, family 2, subfamily W, member 1 [Source:HGNC Symbol;Acc:8281]'
        };
	is_deeply( $gene, $expected_gene, "Testing gene structure" );
};
	

subtest "Checking ncRNA gene", sub {
	my ($gene) = grep { $_->{id} eq 'ENSG00000261370' } @$genes;
	ok( $gene, "Test gene found" );
	my $expected_gene = $VAR1 = {
		'id'           => 'ENSG00000261370',
		'analysis'     => 'Havana',
		'coord_system' => { 'name' => 'chromosome', 'version' => 'GRCh38' },
		'transcripts'  => [ {
			   'analysis'            => 'Havana',
			   'strand'              => '-1',
			   'biotype'             => 'processed_pseudogene',
			   'version'             => '1',
			   'description'         => undef,
			   'gene_id'             => 'ENSG00000261370',
			   'name'                => 'RPL14P5-001',
			   'seq_region_synonyms' => undef,
			   'xrefs'               => [ {
						 'db_display'  => 'Vega transcript',
						 'dbname'      => 'Vega_transcript',
						 'primary_id'  => 'OTTHUMT00000427110',
						 'description' => undef,
						 'info_text'   => '',
						 'display_id'  => 'RP11-309M23.2-001',
						 'info_type'   => 'NONE' }, {
						 'info_type'  => 'NONE',
						 'info_text'  => 'Added during ensembl-vega production',
						 'display_id' => 'OTTHUMT00000427110',
						 'primary_id' => 'OTTHUMT00000427110',
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
			   'coord_system' =>
				 { 'version' => 'GRCh38', 'name' => 'chromosome' },
			   'id'              => 'ENST00000569325',
			   'start'           => '969238',
			   'seq_region_name' => 'HG480_HG481_PATCH',
			   'end'             => '970836',
			   'translations'    => undef,
			   'exons'           => [ {
					  'version'         => '1',
					  'start'           => '970445',
					  'seq_region_name' => 'HG480_HG481_PATCH',
					  'strand'          => '-1',
					  'end'             => '970836',
					  'id'              => 'ENSE00002580842',
					  'rank'            => '1',
					  'coord_system' =>
						{ 'name' => 'chromosome', 'version' => 'GRCh38' },

					  'ensembl_object_type' => 'exon',
					  'trans_id'            => 'ENST00000569325' }, {
					  'trans_id'            => 'ENST00000569325',
					  'ensembl_object_type' => 'exon',
					  'coord_system' =>
						{ 'name' => 'chromosome', 'version' => 'GRCh38' },

					  'rank'            => '2',
					  'id'              => 'ENSE00002621881',
					  'strand'          => '-1',
					  'end'             => '970115',
					  'start'           => '969827',
					  'seq_region_name' => 'HG480_HG481_PATCH',
					  'version'         => '1' }, {
					  'trans_id'            => 'ENST00000569325',
					  'ensembl_object_type' => 'exon',
					  'rank'                => '3',
					  'coord_system' =>
						{ 'name' => 'chromosome', 'version' => 'GRCh38' },
					  'id'              => 'ENSE00002622269',
					  'start'           => '969238',
					  'seq_region_name' => 'HG480_HG481_PATCH',
					  'end'             => '969286',
					  'strand'          => '-1',
					  'version'         => '1' } ],
			   'ensembl_object_type' => 'transcript' } ],
		'version'         => '1',
		'biotype'         => 'pseudogene',
		'strand'          => '-1',
		'end'             => '970836',
		'seq_region_name' => 'HG480_HG481_PATCH',
		'start'           => '969238',
		'description' =>
		  'ribosomal protein L14 pseudogene 5 [Source:HGNC Symbol;Acc:37720]',
		'xrefs' => [ { 'description' => undef,
					   'primary_id'  => 'OTTHUMG00000174633',
					   'dbname'      => 'OTTG',
					   'db_display'  => 'Havana gene',
					   'info_type'   => 'NONE',
					   'info_text'   => '',
					   'display_id'  => 'OTTHUMG00000174633' }, {
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

	use Data::Dumper;
	print Dumper($gene);

	is_deeply( $gene, $expected_gene, "Testing gene structure" );
};

done_testing;
