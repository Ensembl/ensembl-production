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

sub sort_gene {
	my ($gene) = @_;
	$gene->{xrefs}       = sort_xrefs( $gene->{xrefs} );
	$gene->{transcripts} = sort_transcripts( $gene->{transcripts} );
	return $gene;
}

sub sort_xrefs {
	my ($xrefs) = @_;
	if ( defined $xrefs ) {
		$xrefs = [
			sort {
				$a->{primary_id} cmp $b->{primary_id} ||
				$a->{display_id} cmp $b->{display_id} ||
				  $a->{db_name} cmp $b->{db_name}
			} @$xrefs ];
		for my $xref (@$xrefs) {
			if ( defined $xref->{linkage_types} ) {
				$xref->{linkage_types} =
				  [ sort { $a->{evidence} cmp $b->{evidence} }
					@{ $xref->{linkage_types} } ];
			}
		}
	}
	return $xrefs;
}

sub sort_transcripts {
	my ($transcripts) = @_;
	for my $transcript ( @{$transcripts} ) {
		$transcript->{xrefs} = sort_xrefs( $transcript->{xrefs} );
		if ( defined $transcript->{translations} ) {
			$transcript->{translations} =
			  sort_translations( $transcript->{translations} );
		}
	}
	return [ sort {$a->{id} <=> $b->{id}} @{$transcripts} ];
}

sub sort_translations {
	my ($translations) = @_;
	for my $translation ( @{$translations} ) {
		$translation->{xrefs} = sort_xrefs( $translation->{xrefs} );
		if ( defined $translation->{protein_features} ) {
			$translation->{protein_features} = [
				sort {
					$a->{start} <=> $b->{start} ||
					  $a->{name} cmp $b->{name}
				} @{ $translation->{protein_features} } ];
		}
	}
	return [ sort @{$translations} ];
}

my $test        = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens_dump');
my $core_dba    = $test->get_DBAdaptor('core');
my $funcgen_dba = $test->get_DBAdaptor('funcgen');
my $fetcher     = Bio::EnsEMBL::Production::Search::GeneFetcher->new();
diag "Fetching genes...";
my $genes = $fetcher->fetch_genes_for_dba( $core_dba, undef, $funcgen_dba );
diag "Checking genes...";
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
          'xrefs' => [
                       {
                         'db_display' => 'Havana gene',
                         'primary_id' => 'OTTHUMG00000031048',
                         'description' => undef,
                         'info_type' => 'NONE',
                         'display_id' => 'OTTHUMG00000031048',
                         'info_text' => '',
                         'dbname' => 'OTTG'
                       },
                       {
                         'display_id' => 'ENSG00000204704',
                         'info_text' => '',
                         'dbname' => 'ArrayExpress',
                         'primary_id' => 'ENSG00000204704',
                         'description' => '',
                         'db_display' => 'ArrayExpress',
                         'info_type' => 'DIRECT'
                       },
                       {
                         'display_id' => 'OR2W1',
                         'dbname' => 'EntrezGene',
                         'primary_id' => '26692',
                         'description' => 'olfactory receptor, family 2, subfamily W, member 1',
                         'synonyms' => [
                                         'hs6M1-15'
                                       ],
                         'info_type' => 'DEPENDENT',
                         'info_text' => '',
                         'db_display' => 'EntrezGene'
                       },
                       {
                         'primary_id' => '8281',
                         'description' => 'olfactory receptor, family 2, subfamily W, member 1',
                         'synonyms' => [
                                         'hs6M1-15'
                                       ],
                         'info_type' => 'DIRECT',
                         'display_id' => 'OR2W1',
                         'dbname' => 'HGNC',
                         'db_display' => 'HGNC Symbol',
                         'info_text' => 'Generated via ensembl_manual'
                       },
                       {
                         'display_id' => 'OR2W1',
                         'info_text' => '',
                         'dbname' => 'Uniprot_gn',
                         'db_display' => 'UniProtKB Gene Name',
                         'primary_id' => 'OR2W1',
                         'description' => '',
                         'info_type' => 'DEPENDENT'
                       },
                       {
                         'dbname' => 'WikiGene',
                         'info_text' => '',
                         'display_id' => 'OR2W1',
                         'info_type' => 'DEPENDENT',
                         'db_display' => 'WikiGene',
                         'description' => 'olfactory receptor, family 2, subfamily W, member 1',
                         'primary_id' => '26692'
                       }
                     ],
          'end' => '29013017',
          'start' => '29011990',
          'previous_ids' => [
                              'bananag'
                            ],
          'seq_region_name' => '6',
          'strand' => '-1',
          'id' => 'ENSG00000204704',
          'transcripts' => [
                             {
                               'previous_ids' => [
                                                   'bananat'
                                                 ],
                               'start' => '29011990',
                               'end' => '29013017',
                               'translations' => [
                                                   {
                                                     'transcript_id' => 'ENST00000377175',
                                                     'protein_features' => [
                                                                             {
                                                                               'interpro_ac' => 'IPR000276',
                                                                               'end' => '290',
                                                                               'start' => '41',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'interpro_description' => 'G protein-coupled receptor, rhodopsin-like',
                                                                               'dbname' => 'Pfam',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'PF00001'
                                                                             },
                                                                             {
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'interpro_description' => 'G protein-coupled receptor, rhodopsin-like',
                                                                               'dbname' => 'Pfam',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'PF00001',
                                                                               'interpro_ac' => 'IPR000276',
                                                                               'end' => '290',
                                                                               'start' => '41'
                                                                             },
                                                                             {
                                                                               'end' => '298',
                                                                               'start' => '26',
                                                                               'name' => 'PF10323',
                                                                               'dbname' => 'Pfam',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'interpro_ac' => 'IPR999999'
                                                                             },
                                                                             {
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'Prints',
                                                                               'name' => 'PR00237',
                                                                               'end' => '50',
                                                                               'start' => '26'
                                                                             },
                                                                             {
                                                                               'end' => '80',
                                                                               'start' => '59',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'Prints',
                                                                               'name' => 'PR00237',
                                                                               'translation_id' => 'ENSP00000366380'
                                                                             },
                                                                             {
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'dbname' => 'Prints',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'PR00237',
                                                                               'end' => '126',
                                                                               'start' => '104'
                                                                             },
                                                                             {
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'Prints',
                                                                               'name' => 'PR00237',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'end' => '222',
                                                                               'start' => '199'
                                                                             },
                                                                             {
                                                                               'start' => '272',
                                                                               'end' => '298',
                                                                               'name' => 'PR00237',
                                                                               'dbname' => 'Prints',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'translation_id' => 'ENSP00000366380'
                                                                             },
                                                                             {
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'name' => 'PR00245',
                                                                               'dbname' => 'Prints',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'end' => '103',
                                                                               'start' => '92'
                                                                             },
                                                                             {
                                                                               'start' => '129',
                                                                               'end' => '141',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'Prints',
                                                                               'name' => 'PR00245'
                                                                             },
                                                                             {
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'dbname' => 'Prints',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'PR00245',
                                                                               'end' => '192',
                                                                               'start' => '176'
                                                                             },
                                                                             {
                                                                               'end' => '245',
                                                                               'start' => '236',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'Prints',
                                                                               'name' => 'PR00245'
                                                                             },
                                                                             {
                                                                               'end' => '294',
                                                                               'start' => '283',
                                                                               'name' => 'PR00245',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'Prints',
                                                                               'translation_id' => 'ENSP00000366380'
                                                                             },
                                                                             {
                                                                               'dbname' => 'Prosite_profiles',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'PS50262',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'start' => '41',
                                                                               'end' => '290'
                                                                             },
                                                                             {
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'name' => 'Seg',
                                                                               'dbname' => 'low_complexity',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'start' => '202',
                                                                               'end' => '216'
                                                                             },
                                                                             {
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'dbname' => 'Superfamily',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'SSF81321',
                                                                               'end' => '313',
                                                                               'start' => '1'
                                                                             },
                                                                             {
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'dbname' => 'transmembrane',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'Tmhmm',
                                                                               'end' => '48',
                                                                               'start' => '26'
                                                                             },
                                                                             {
                                                                               'dbname' => 'transmembrane',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'name' => 'Tmhmm',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'start' => '61',
                                                                               'end' => '83'
                                                                             },
                                                                             {
                                                                               'name' => 'Tmhmm',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'transmembrane',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'start' => '98',
                                                                               'end' => '120'
                                                                             },
                                                                             {
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'name' => 'Tmhmm',
                                                                               'dbname' => 'transmembrane',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'end' => '162',
                                                                               'start' => '140'
                                                                             },
                                                                             {
                                                                               'name' => 'Tmhmm',
                                                                               'dbname' => 'transmembrane',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'translation_id' => 'ENSP00000366380',
                                                                               'end' => '221',
                                                                               'start' => '199'
                                                                             },
                                                                             {
                                                                               'start' => '241',
                                                                               'end' => '263',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'transmembrane',
                                                                               'name' => 'Tmhmm',
                                                                               'translation_id' => 'ENSP00000366380'
                                                                             },
                                                                             {
                                                                               'start' => '273',
                                                                               'end' => '292',
                                                                               'name' => 'Tmhmm',
                                                                               'ensembl_object_type' => 'protein_feature',
                                                                               'dbname' => 'transmembrane',
                                                                               'translation_id' => 'ENSP00000366380'
                                                                             }
                                                                           ],
                                                     'version' => '1',
                                                     'id' => 'ENSP00000366380',
                                                     'xrefs' => [
                                                                  {
                                                                    'info_type' => 'NONE',
                                                                    'db_display' => 'Vega translation',
                                                                    'primary_id' => 'OTTHUMP00000029054',
                                                                    'description' => undef,
                                                                    'dbname' => 'Vega_translation',
                                                                    'display_id' => 'OTTHUMP00000029054',
                                                                    'info_text' => 'Added during ensembl-vega production'
                                                                  },
                                                                  {
                                                                    'info_type' => 'NONE',
                                                                    'db_display' => 'Vega translation',
                                                                    'description' => undef,
                                                                    'primary_id' => '191160',
                                                                    'dbname' => 'Vega_translation',
                                                                    'info_text' => '',
                                                                    'display_id' => '191160'
                                                                  },
                                                                  {
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'CH471081',
                                                                    'description' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CH471081',
                                                                    'dbname' => 'EMBL'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'description' => '',
                                                                    'primary_id' => 'BX927167',
                                                                    'dbname' => 'EMBL',
                                                                    'info_text' => '',
                                                                    'display_id' => 'BX927167'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'primary_id' => 'AL662865',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'dbname' => 'EMBL',
                                                                    'info_text' => '',
                                                                    'display_id' => 'AL662865'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'AL662791',
                                                                    'description' => '',
                                                                    'dbname' => 'EMBL',
                                                                    'info_text' => '',
                                                                    'display_id' => 'AL662791'
                                                                  },
                                                                  {
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'AL929561',
                                                                    'description' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'display_id' => 'AL929561',
                                                                    'info_text' => '',
                                                                    'dbname' => 'EMBL'
                                                                  },
                                                                  {
                                                                    'display_id' => 'AJ302594',
                                                                    'info_text' => '',
                                                                    'dbname' => 'EMBL',
                                                                    'description' => '',
                                                                    'primary_id' => 'AJ302594',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'display_id' => 'AJ302595',
                                                                    'info_text' => '',
                                                                    'dbname' => 'EMBL',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'description' => '',
                                                                    'primary_id' => 'AJ302595',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'AJ302596',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'primary_id' => 'AJ302596',
                                                                    'db_display' => 'European Nucleotide Archive'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'primary_id' => 'AJ302597',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'AJ302597',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'info_text' => '',
                                                                    'display_id' => 'AJ302598',
                                                                    'dbname' => 'EMBL',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'AJ302598',
                                                                    'description' => '',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'description' => '',
                                                                    'primary_id' => 'AJ302599',
                                                                    'dbname' => 'EMBL',
                                                                    'info_text' => '',
                                                                    'display_id' => 'AJ302599'
                                                                  },
                                                                  {
                                                                    'primary_id' => 'AJ302600',
                                                                    'description' => '',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => '',
                                                                    'display_id' => 'AJ302600',
                                                                    'dbname' => 'EMBL'
                                                                  },
                                                                  {
                                                                    'description' => '',
                                                                    'primary_id' => 'AJ302601',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => '',
                                                                    'display_id' => 'AJ302601',
                                                                    'dbname' => 'EMBL'
                                                                  },
                                                                  {
                                                                    'dbname' => 'EMBL',
                                                                    'info_text' => '',
                                                                    'display_id' => 'AJ302602',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'primary_id' => 'AJ302602',
                                                                    'db_display' => 'European Nucleotide Archive'
                                                                  },
                                                                  {
                                                                    'description' => '',
                                                                    'primary_id' => 'AJ302603',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'display_id' => 'AJ302603',
                                                                    'info_text' => '',
                                                                    'dbname' => 'EMBL'
                                                                  },
                                                                  {
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'AL035402',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'primary_id' => 'AL035402',
                                                                    'db_display' => 'European Nucleotide Archive'
                                                                  },
                                                                  {
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'BX248413',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'description' => '',
                                                                    'primary_id' => 'BX248413'
                                                                  },
                                                                  {
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'CR759957',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'description' => '',
                                                                    'primary_id' => 'CR759957'
                                                                  },
                                                                  {
                                                                    'dbname' => 'EMBL',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CR936923',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'description' => '',
                                                                    'primary_id' => 'CR936923'
                                                                  },
                                                                  {
                                                                    'display_id' => 'CR759835',
                                                                    'info_text' => '',
                                                                    'dbname' => 'EMBL',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'description' => '',
                                                                    'primary_id' => 'CR759835',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'description' => '',
                                                                    'primary_id' => 'BC103870',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => '',
                                                                    'display_id' => 'BC103870',
                                                                    'dbname' => 'EMBL'
                                                                  },
                                                                  {
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'BC103871',
                                                                    'description' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'display_id' => 'BC103871',
                                                                    'info_text' => '',
                                                                    'dbname' => 'EMBL'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'BC103872',
                                                                    'description' => '',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'dbname' => 'EMBL',
                                                                    'info_text' => '',
                                                                    'display_id' => 'BC103872'
                                                                  },
                                                                  {
                                                                    'display_id' => 'AF399628',
                                                                    'info_text' => '',
                                                                    'dbname' => 'EMBL',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'AF399628',
                                                                    'description' => '',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'dbname' => 'EMBL',
                                                                    'display_id' => 'BK004522',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'European Nucleotide Archive',
                                                                    'primary_id' => 'BK004522',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'description' => 'biological_process',
                                                                    'primary_id' => 'GO:0008150',
                                                                    'dbname' => 'goslim_goa',
                                                                    'display_id' => 'GO:0008150',
                                                                    'info_text' => 'Generated via main'
                                                                  },
                                                                  {
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'description' => 'molecular_function',
                                                                    'primary_id' => 'GO:0003674',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'display_id' => 'GO:0003674',
                                                                    'info_text' => 'Generated via main',
                                                                    'dbname' => 'goslim_goa'
                                                                  },
                                                                  {
                                                                    'display_id' => 'GO:0005575',
                                                                    'info_text' => 'Generated via main',
                                                                    'dbname' => 'goslim_goa',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'primary_id' => 'GO:0005575',
                                                                    'description' => 'cellular_component',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => 'cell',
                                                                    'primary_id' => 'GO:0005623',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'dbname' => 'goslim_goa',
                                                                    'info_text' => 'Generated via main',
                                                                    'display_id' => 'GO:0005623'
                                                                  },
                                                                  {
                                                                    'info_text' => 'Generated via main',
                                                                    'display_id' => 'GO:0005886',
                                                                    'dbname' => 'goslim_goa',
                                                                    'primary_id' => 'GO:0005886',
                                                                    'description' => 'plasma membrane',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'primary_id' => 'GO:0004871',
                                                                    'description' => 'signal transducer activity',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'display_id' => 'GO:0004871',
                                                                    'info_text' => 'Generated via main',
                                                                    'dbname' => 'goslim_goa'
                                                                  },
                                                                  {
                                                                    'description' => 'signal transduction',
                                                                    'primary_id' => 'GO:0007165',
                                                                    'db_display' => 'GOSlim GOA',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => 'Generated via main',
                                                                    'display_id' => 'GO:0007165',
                                                                    'dbname' => 'goslim_goa'
                                                                  },
                                                                  {
                                                                    'info_text' => '',
                                                                    'display_id' => 'CAC20514.1',
                                                                    'dbname' => 'protein_id',
                                                                    'primary_id' => 'CAC20514',
                                                                    'description' => '',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAC20515',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'dbname' => 'protein_id',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CAC20515.1'
                                                                  },
                                                                  {
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAC20516',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CAC20516.1',
                                                                    'dbname' => 'protein_id'
                                                                  },
                                                                  {
                                                                    'dbname' => 'protein_id',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CAC20517.1',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAC20517',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAC20518.1',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAC20518',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAC20519',
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAC20519.1',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAC20520',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'CAC20520.1',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'display_id' => 'CAC20521.1',
                                                                    'info_text' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAC20521',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'display_id' => 'CAC20522.1',
                                                                    'info_text' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAC20522',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'primary_id' => 'CAC20523',
                                                                    'description' => '',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'dbname' => 'protein_id',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CAC20523.1'
                                                                  },
                                                                  {
                                                                    'dbname' => 'protein_id',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CAB42853.1',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAB42853',
                                                                    'db_display' => 'INSDC protein ID'
                                                                  },
                                                                  {
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'CAI18243',
                                                                    'description' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CAI18243.1',
                                                                    'dbname' => 'protein_id'
                                                                  },
                                                                  {
                                                                    'info_text' => '',
                                                                    'display_id' => 'CAI41643.1',
                                                                    'dbname' => 'protein_id',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAI41643',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAI41768',
                                                                    'dbname' => 'protein_id',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CAI41768.2'
                                                                  },
                                                                  {
                                                                    'display_id' => 'CAM26052.1',
                                                                    'info_text' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAM26052',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'description' => '',
                                                                    'primary_id' => 'CAQ07349',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'display_id' => 'CAQ07349.1',
                                                                    'info_text' => '',
                                                                    'dbname' => 'protein_id'
                                                                  },
                                                                  {
                                                                    'display_id' => 'CAQ07643.1',
                                                                    'info_text' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAQ07643',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'display_id' => 'CAQ07834.1',
                                                                    'info_text' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAQ07834',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'dbname' => 'protein_id',
                                                                    'info_text' => '',
                                                                    'display_id' => 'CAQ08425.1',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'description' => '',
                                                                    'primary_id' => 'CAQ08425'
                                                                  },
                                                                  {
                                                                    'display_id' => 'EAX03181.1',
                                                                    'info_text' => '',
                                                                    'dbname' => 'protein_id',
                                                                    'description' => '',
                                                                    'primary_id' => 'EAX03181',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'info_type' => 'DEPENDENT'
                                                                  },
                                                                  {
                                                                    'dbname' => 'protein_id',
                                                                    'info_text' => '',
                                                                    'display_id' => 'AAI03871.1',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'description' => '',
                                                                    'primary_id' => 'AAI03871',
                                                                    'db_display' => 'INSDC protein ID'
                                                                  },
                                                                  {
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'AAI03872.1',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'AAI03872',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'dbname' => 'protein_id',
                                                                    'info_text' => '',
                                                                    'display_id' => 'AAI03873.1',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'AAI03873',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'dbname' => 'protein_id',
                                                                    'display_id' => 'AAK95113.1',
                                                                    'info_text' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'AAK95113',
                                                                    'description' => ''
                                                                  },
                                                                  {
                                                                    'db_display' => 'INSDC protein ID',
                                                                    'primary_id' => 'DAA04920',
                                                                    'description' => '',
                                                                    'info_type' => 'DEPENDENT',
                                                                    'display_id' => 'DAA04920.1',
                                                                    'info_text' => '',
                                                                    'dbname' => 'protein_id'
                                                                  },
                                                                  {
                                                                    'display_id' => 'NP_112165.1',
                                                                    'info_text' => '',
                                                                    'dbname' => 'RefSeq_peptide',
                                                                    'db_display' => 'RefSeq peptide',
                                                                    'description' => 'olfactory receptor 2W1 ',
                                                                    'primary_id' => 'NP_112165',
                                                                    'info_type' => 'SEQUENCE_MATCH'
                                                                  },
                                                                  {
                                                                    'info_type' => 'CHECKSUM',
                                                                    'description' => undef,
                                                                    'primary_id' => 'UPI000003FF8A',
                                                                    'db_display' => 'UniParc',
                                                                    'dbname' => 'UniParc',
                                                                    'display_id' => 'UPI000003FF8A',
                                                                    'info_text' => ''
                                                                  },
                                                                  {
                                                                    'description' => 'Olfactory receptor 2W1 ',
                                                                    'primary_id' => 'Q9Y3N9',
                                                                    'info_type' => 'DIRECT',
                                                                    'synonyms' => [
                                                                                    'B0S7Y5',
                                                                                    'Q5JNZ1',
                                                                                    'Q6IEU0',
                                                                                    'Q96R17',
                                                                                    'Q9GZL0',
                                                                                    'Q9GZL1'
                                                                                  ],
                                                                    'display_id' => 'OR2W1_HUMAN',
                                                                    'dbname' => 'Uniprot/SWISSPROT',
                                                                    'db_display' => 'UniProtKB/Swiss-Prot',
                                                                    'info_text' => 'Generated via uniprot_mapped'
                                                                  },
                                                                  {
                                                                    'description' => 'GO',
                                                                    'primary_id' => 'GO:0007186',
                                                                    'linkage_types' => [
                                                                                         {
                                                                                           'source' => {
                                                                                                         'dbname' => 'G protein-coupled receptor, rhodopsin-like',
                                                                                                         'display_id' => 'IPR000276',
                                                                                                         'db_display_name' => 'Interpro',
                                                                                                         'description' => 'GPCR_Rhodpsn',
                                                                                                         'primary_id' => 'IEA'
                                                                                                       },
                                                                                           'evidence' => 'G-protein coupled receptor signaling pathway'
                                                                                         }
                                                                                       ],
                                                                    'associated_xrefs' => [],
                                                                    'display_id' => 'GO:0007186',
                                                                    'dbname' => 'GO'
                                                                  },
                                                                  {
                                                                    'display_id' => 'GO:0004930',
                                                                    'dbname' => 'GO',
                                                                    'description' => 'GO',
                                                                    'primary_id' => 'GO:0004930',
                                                                    'linkage_types' => [
                                                                                         {
                                                                                           'source' => {
                                                                                                         'db_display_name' => undef,
                                                                                                         'description' => undef,
                                                                                                         'primary_id' => 'IEA',
                                                                                                         'dbname' => undef,
                                                                                                         'display_id' => undef
                                                                                                       },
                                                                                           'evidence' => 'G-protein coupled receptor activity'
                                                                                         }
                                                                                       ],
                                                                    'associated_xrefs' => []
                                                                  },
                                                                  {
                                                                    'display_id' => 'GO:0004984',
                                                                    'dbname' => 'GO',
                                                                    'description' => 'GO',
                                                                    'primary_id' => 'GO:0004984',
                                                                    'linkage_types' => [
                                                                                         {
                                                                                           'source' => {
                                                                                                         'dbname' => undef,
                                                                                                         'display_id' => undef,
                                                                                                         'db_display_name' => undef,
                                                                                                         'primary_id' => 'IEA',
                                                                                                         'description' => undef
                                                                                                       },
                                                                                           'evidence' => 'olfactory receptor activity'
                                                                                         }
                                                                                       ],
                                                                    'associated_xrefs' => []
                                                                  },
                                                                  {
                                                                    'display_id' => 'GO:0016021',
                                                                    'dbname' => 'GO',
                                                                    'description' => 'GO',
                                                                    'primary_id' => 'GO:0016021',
                                                                    'linkage_types' => [
                                                                                         {
                                                                                           'evidence' => 'integral to membrane',
                                                                                           'source' => {
                                                                                                         'db_display_name' => undef,
                                                                                                         'primary_id' => 'IEA',
                                                                                                         'description' => undef,
                                                                                                         'dbname' => undef,
                                                                                                         'display_id' => undef
                                                                                                       }
                                                                                         }
                                                                                       ],
                                                                    'associated_xrefs' => []
                                                                  },
                                                                  {
                                                                    'dbname' => 'GO',
                                                                    'display_id' => 'GO:0005886',
                                                                    'associated_xrefs' => [],
                                                                    'linkage_types' => [
                                                                                         {
                                                                                           'source' => {
                                                                                                         'dbname' => undef,
                                                                                                         'display_id' => undef,
                                                                                                         'db_display_name' => undef,
                                                                                                         'primary_id' => 'TAS',
                                                                                                         'description' => undef
                                                                                                       },
                                                                                           'evidence' => 'plasma membrane'
                                                                                         }
                                                                                       ],
                                                                    'description' => 'GO',
                                                                    'primary_id' => 'GO:0005886'
                                                                  }
                                                                ],
                                                     'ensembl_object_type' => 'translation',
                                                     'previous_ids' => [
                                                                         'bananap'
                                                                       ]
                                                   }
                                                 ],
                               'xrefs' => [
                                            {
                                              'info_type' => 'NONE',
                                              'description' => undef,
                                              'primary_id' => 'OTTHUMT00000076053',
                                              'db_display' => 'Vega transcript',
                                              'dbname' => 'Vega_transcript',
                                              'info_text' => 'Added during ensembl-vega production',
                                              'display_id' => 'OTTHUMT00000076053'
                                            },
                                            {
                                              'dbname' => 'Vega_transcript',
                                              'info_text' => '',
                                              'display_id' => 'OR2W1-001',
                                              'info_type' => 'NONE',
                                              'primary_id' => 'OTTHUMT00000076053',
                                              'description' => undef,
                                              'db_display' => 'Vega transcript'
                                            },
                                            {
                                              'display_id' => 'OTTHUMT00000076053',
                                              'info_text' => '',
                                              'dbname' => 'shares_CDS_and_UTR_with_OTTT',
                                              'description' => undef,
                                              'primary_id' => 'OTTHUMT00000076053',
                                              'db_display' => 'Transcript having exact match between ENSEMBL and HAVANA',
                                              'info_type' => 'NONE'
                                            },
                                            {
                                              'dbname' => 'UCSC',
                                              'display_id' => 'uc003nlw.2',
                                              'info_text' => '',
                                              'info_type' => 'COORDINATE_OVERLAP',
                                              'description' => undef,
                                              'primary_id' => 'uc003nlw.2',
                                              'db_display' => 'UCSC Stable ID'
                                            },
                                            {
                                              'info_type' => 'DIRECT',
                                              'db_display' => 'CCDS',
                                              'description' => '',
                                              'primary_id' => 'CCDS4656',
                                              'dbname' => 'CCDS',
                                              'display_id' => 'CCDS4656.1',
                                              'info_text' => ''
                                            },
                                            {
                                              'info_text' => 'Generated via ensembl_manual',
                                              'db_display' => 'HGNC Symbol',
                                              'dbname' => 'HGNC',
                                              'display_id' => 'OR2W1',
                                              'synonyms' => [
                                                              'hs6M1-15'
                                                            ],
                                              'info_type' => 'DIRECT',
                                              'description' => 'olfactory receptor, family 2, subfamily W, member 1',
                                              'primary_id' => '8281'
                                            },
                                            {
                                              'display_id' => 'OR2W1-001',
                                              'info_text' => '',
                                              'dbname' => 'HGNC_trans_name',
                                              'db_display' => 'HGNC transcript name',
                                              'primary_id' => 'OR2W1-001',
                                              'description' => 'olfactory receptor, family 2, subfamily W, member 1',
                                              'info_type' => 'MISC'
                                            },
                                            {
                                              'db_display' => 'RefSeq mRNA',
                                              'description' => '',
                                              'primary_id' => 'NM_030903',
                                              'info_type' => 'DIRECT',
                                              'display_id' => 'NM_030903.3',
                                              'info_text' => 'Generated via otherfeatures',
                                              'dbname' => 'RefSeq_mRNA'
                                            }
                                          ],
                               'strand' => '-1',
                               'gene_id' => 'ENSG00000204704',
                               'seq_region_name' => '6',
                               'supporting_features' => [
                                                          {
                                                            'db_name' => 'RefSeq_dna',
                                                            'end' => '963',
                                                            'start' => '1',
                                                            'db_display' => 'RefSeq DNA',
                                                            'evalue' => undef,
                                                            'id' => 'NM_030903.3',
                                                            'trans_id' => 'ENST00000377175',
                                                            'analysis' => 'human_cdna2genome'
                                                          },
                                                          {
                                                            'evalue' => undef,
                                                            'db_display' => 'CCDS',
                                                            'start' => '1',
                                                            'end' => '963',
                                                            'db_name' => 'CCDS',
                                                            'trans_id' => 'ENST00000377175',
                                                            'analysis' => 'ccds',
                                                            'id' => 'CCDS4656.1'
                                                          }
                                                        ],
                               'id' => 'ENST00000377175',
                               'seq_region_synonyms' => undef,
                               'version' => '1',
                               'description' => undef,
                               'biotype' => 'protein_coding',
                               'ensembl_object_type' => 'transcript',
                               'name' => 'OR2W1-001',
                               'exons' => [
                                            {
                                              'seq_region_name' => '6',
                                              'strand' => '-1',
                                              'end' => '29013017',
                                              'start' => '29011990',
                                              'coord_system' => {
                                                                  'version' => 'GRCh38',
                                                                  'name' => 'chromosome'
                                                                },
                                              'trans_id' => 'ENST00000377175',
                                              'version' => '1',
                                              'id' => 'ENSE00001691220',
                                              'ensembl_object_type' => 'exon',
                                              'rank' => '1'
                                            }
                                          ],
                               'analysis' => 'Ensembl/Havana merge',
                               'coord_system' => {
                              'version' => 'GRCh38',
                              'name' => 'chromosome'
                            }
                             }
                           ],
          'description' => 'olfactory receptor, family 2, subfamily W, member 1 [Source:HGNC Symbol;Acc:8281]',
          'version' => '2',
          'biotype' => 'protein_coding',
          'name' => 'OR2W1',
          'ensembl_object_type' => 'gene',
          'coord_system' => {
                              'version' => 'GRCh38',
                              'name' => 'chromosome'
                            },
          'analysis' => 'Ensembl/Havana merge',
          'synonyms' => [
                          'hs6M1-15'
                        ]
        };
   
	is_deeply( sort_gene($gene),
			   sort_gene($expected_gene),
			   "Testing gene structure" );
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

	is_deeply( sort_gene($gene),
			   sort_gene($expected_gene),
			   "Testing gene structure" );
};

done_testing;

