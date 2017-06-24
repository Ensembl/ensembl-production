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
		'name'    => 'OR2W1',
		'version' => '2',
		'xrefs'   => [ {
					   'primary_id'  => 'OTTHUMG00000031048',
					   'info_type'   => 'NONE',
					   'info_text'   => '',
					   'display_id'  => 'OTTHUMG00000031048',
					   'db_display'  => 'Havana gene',
					   'description' => undef,
					   'dbname'      => 'OTTG' }, {
					   'dbname'      => 'ArrayExpress',
					   'description' => '',
					   'db_display'  => 'ArrayExpress',
					   'display_id'  => 'ENSG00000204704',
					   'info_type'   => 'DIRECT',
					   'info_text'   => '',
					   'primary_id'  => 'ENSG00000204704' }, {
					   'db_display' => 'EntrezGene',
					   'description' =>
						 'olfactory receptor, family 2, subfamily W, member 1',
					   'dbname'     => 'EntrezGene',
					   'primary_id' => '26692',
					   'synonyms'   => [ 'hs6M1-15' ],
					   'info_type'  => 'DEPENDENT',
					   'display_id' => 'OR2W1',
					   'info_text'  => '' }, {
					   'db_display' => 'HGNC Symbol',
					   'description' =>
						 'olfactory receptor, family 2, subfamily W, member 1',
					   'dbname'     => 'HGNC',
					   'primary_id' => '8281',
					   'synonyms'   => [ 'hs6M1-15' ],
					   'info_type'  => 'DIRECT',
					   'display_id' => 'OR2W1',
					   'info_text'  => 'Generated via ensembl_manual' }, {
					   'dbname'      => 'Uniprot_gn',
					   'db_display'  => 'UniProtKB Gene Name',
					   'description' => '',
					   'display_id'  => 'OR2W1',
					   'info_text'   => '',
					   'info_type'   => 'DEPENDENT',
					   'primary_id'  => 'OR2W1' }, {
					   'dbname'     => 'WikiGene',
					   'db_display' => 'WikiGene',
					   'description' =>
						 'olfactory receptor, family 2, subfamily W, member 1',
					   'info_text'  => '',
					   'info_type'  => 'DEPENDENT',
					   'primary_id' => '26692',
					   'display_id' => 'OR2W1' } ],
		'ensembl_object_type' => 'gene',
		'start'               => '29011990',
		'transcripts'         => [ {
			   'coord_system' =>
				 { 'name' => 'chromosome', 'version' => 'GRCh38' },
			   'end'          => '29013017',
			   'biotype'      => 'protein_coding',
			   'id'           => 'ENST00000377175',
			   'previous_ids' => [ 'bananat' ],
			   'translations' => [ {
					  'protein_features' => [ {
									'translation_id'      => 'ENSP00000366380',
									'name'                => 'PF00001',
									'end'                 => '290',
									'interpro_ac'         => undef,
									'start'               => '41',
									'description'         => undef,
									'dbname'              => 'Pfam',
									'ensembl_object_type' => 'protein_feature'
								  }, {
									'translation_id'      => 'ENSP00000366380',
									'name'                => 'PF10323',
									'end'                 => '298',
									'interpro_ac'         => undef,
									'start'               => '26',
									'ensembl_object_type' => 'protein_feature',
									'description'         => undef,
									'dbname'              => 'Pfam' }, {
									'end'                 => '50',
									'name'                => 'PR00237',
									'translation_id'      => 'ENSP00000366380',
									'description'         => undef,
									'dbname'              => 'Prints',
									'ensembl_object_type' => 'protein_feature',
									'interpro_ac'         => undef,
									'start'               => '26' }, {
									'translation_id'      => 'ENSP00000366380',
									'name'                => 'PR00237',
									'end'                 => '80',
									'start'               => '59',
									'interpro_ac'         => undef,
									'ensembl_object_type' => 'protein_feature',
									'dbname'              => 'Prints',
									'description'         => undef }, {
									'translation_id'      => 'ENSP00000366380',
									'end'                 => '126',
									'name'                => 'PR00237',
									'start'               => '104',
									'interpro_ac'         => undef,
									'ensembl_object_type' => 'protein_feature',
									'dbname'              => 'Prints',
									'description'         => undef }, {
									'end'                 => '222',
									'name'                => 'PR00237',
									'translation_id'      => 'ENSP00000366380',
									'description'         => undef,
									'dbname'              => 'Prints',
									'ensembl_object_type' => 'protein_feature',
									'interpro_ac'         => undef,
									'start'               => '199' }, {
									'end'                 => '298',
									'name'                => 'PR00237',
									'translation_id'      => 'ENSP00000366380',
									'description'         => undef,
									'dbname'              => 'Prints',
									'ensembl_object_type' => 'protein_feature',
									'interpro_ac'         => undef,
									'start'               => '272' }, {
									'interpro_ac'         => undef,
									'start'               => '92',
									'description'         => undef,
									'dbname'              => 'Prints',
									'ensembl_object_type' => 'protein_feature',
									'translation_id'      => 'ENSP00000366380',
									'end'                 => '103',
									'name'                => 'PR00245' }, {
									'translation_id'      => 'ENSP00000366380',
									'name'                => 'PR00245',
									'end'                 => '141',
									'start'               => '129',
									'interpro_ac'         => undef,
									'dbname'              => 'Prints',
									'description'         => undef,
									'ensembl_object_type' => 'protein_feature'
								  }, {
									'ensembl_object_type' => 'protein_feature',
									'description'         => undef,
									'dbname'              => 'Prints',
									'interpro_ac'         => undef,
									'start'               => '176',
									'name'                => 'PR00245',
									'end'                 => '192',
									'translation_id'      => 'ENSP00000366380'
								  }, {
									'interpro_ac'         => undef,
									'start'               => '236',
									'ensembl_object_type' => 'protein_feature',
									'description'         => undef,
									'dbname'              => 'Prints',
									'translation_id'      => 'ENSP00000366380',
									'name'                => 'PR00245',
									'end'                 => '245' }, {
									'ensembl_object_type' => 'protein_feature',
									'dbname'              => 'Prints',
									'description'         => undef,
									'start'               => '283',
									'interpro_ac'         => undef,
									'name'                => 'PR00245',
									'end'                 => '294',
									'translation_id'      => 'ENSP00000366380'
								  }, {
									'translation_id'      => 'ENSP00000366380',
									'name'                => 'PS50262',
									'end'                 => '290',
									'start'               => '41',
									'interpro_ac'         => undef,
									'ensembl_object_type' => 'protein_feature',
									'dbname'              => 'Prosite_profiles',
									'description'         => undef }, {
									'translation_id'      => 'ENSP00000366380',
									'name'                => 'Seg',
									'end'                 => '216',
									'start'               => '202',
									'interpro_ac'         => undef,
									'dbname'              => 'low_complexity',
									'description'         => undef,
									'ensembl_object_type' => 'protein_feature'
								  }, {
									'translation_id'      => 'ENSP00000366380',
									'end'                 => '313',
									'name'                => 'SSF81321',
									'interpro_ac'         => undef,
									'start'               => '1',
									'ensembl_object_type' => 'protein_feature',
									'description'         => undef,
									'dbname'              => 'Superfamily' }, {
									'end'                 => '48',
									'name'                => 'Tmhmm',
									'translation_id'      => 'ENSP00000366380',
									'ensembl_object_type' => 'protein_feature',
									'dbname'              => 'transmembrane',
									'description'         => undef,
									'start'               => '26',
									'interpro_ac'         => undef }, {
									'translation_id'      => 'ENSP00000366380',
									'name'                => 'Tmhmm',
									'end'                 => '83',
									'interpro_ac'         => undef,
									'start'               => '61',
									'ensembl_object_type' => 'protein_feature',
									'description'         => undef,
									'dbname'              => 'transmembrane' },
								  { 'end'                 => '120',
									'name'                => 'Tmhmm',
									'translation_id'      => 'ENSP00000366380',
									'description'         => undef,
									'dbname'              => 'transmembrane',
									'ensembl_object_type' => 'protein_feature',
									'interpro_ac'         => undef,
									'start'               => '98' }, {
									'translation_id'      => 'ENSP00000366380',
									'end'                 => '162',
									'name'                => 'Tmhmm',
									'start'               => '140',
									'interpro_ac'         => undef,
									'ensembl_object_type' => 'protein_feature',
									'dbname'              => 'transmembrane',
									'description'         => undef }, {
									'start'               => '199',
									'interpro_ac'         => undef,
									'dbname'              => 'transmembrane',
									'description'         => undef,
									'ensembl_object_type' => 'protein_feature',
									'translation_id'      => 'ENSP00000366380',
									'name'                => 'Tmhmm',
									'end'                 => '221' }, {
									'ensembl_object_type' => 'protein_feature',
									'description'         => undef,
									'dbname'              => 'transmembrane',
									'interpro_ac'         => undef,
									'start'               => '241',
									'end'                 => '263',
									'name'                => 'Tmhmm',
									'translation_id'      => 'ENSP00000366380'
								  }, {
									'start'               => '273',
									'interpro_ac'         => undef,
									'dbname'              => 'transmembrane',
									'description'         => undef,
									'ensembl_object_type' => 'protein_feature',
									'translation_id'      => 'ENSP00000366380',
									'name'                => 'Tmhmm',
									'end'                 => '292' } ],
					  'previous_ids'        => [ 'bananap' ],
					  'ensembl_object_type' => 'translation',
					  'id'                  => 'ENSP00000366380',
					  'xrefs'               => [ {
							 'db_display'  => 'Vega translation',
							 'description' => undef,
							 'dbname'      => 'Vega_translation',
							 'primary_id'  => 'OTTHUMP00000029054',
							 'info_text' =>
							   'Added during ensembl-vega production',
							 'info_type'  => 'NONE',
							 'display_id' => 'OTTHUMP00000029054' }, {
							 'dbname'      => 'Vega_translation',
							 'db_display'  => 'Vega translation',
							 'description' => undef,
							 'display_id'  => '191160',
							 'info_type'   => 'NONE',
							 'info_text'   => '',
							 'primary_id'  => '191160' }, {
							 'dbname'      => 'EMBL',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'display_id'  => 'CH471081',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'CH471081' }, {
							 'display_id'  => 'BX927167',
							 'primary_id'  => 'BX927167',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'description' => '',
							 'dbname'      => 'EMBL' }, {
							 'db_display'  => 'European Nucleotide Archive',
							 'description' => '',
							 'dbname'      => 'EMBL',
							 'display_id'  => 'AL662865',
							 'primary_id'  => 'AL662865',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '' }, {
							 'db_display'  => 'European Nucleotide Archive',
							 'description' => '',
							 'dbname'      => 'EMBL',
							 'primary_id'  => 'AL662791',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'display_id'  => 'AL662791' }, {
							 'dbname'      => 'EMBL',
							 'db_display'  => 'European Nucleotide Archive',
							 'description' => '',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'AL929561',
							 'display_id'  => 'AL929561' }, {
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'dbname'      => 'EMBL',
							 'primary_id'  => 'AJ302594',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'display_id'  => 'AJ302594' }, {
							 'db_display'  => 'European Nucleotide Archive',
							 'description' => '',
							 'dbname'      => 'EMBL',
							 'primary_id'  => 'AJ302595',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'display_id'  => 'AJ302595' }, {
							 'display_id'  => 'AJ302596',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'AJ302596',
							 'dbname'      => 'EMBL',
							 'db_display'  => 'European Nucleotide Archive',
							 'description' => '' }, {
							 'display_id'  => 'AJ302597',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'AJ302597',
							 'dbname'      => 'EMBL',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive' }, {
							 'display_id'  => 'AJ302598',
							 'primary_id'  => 'AJ302598',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'dbname'      => 'EMBL' }, {
							 'primary_id'  => 'AJ302599',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'display_id'  => 'AJ302599',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'dbname'      => 'EMBL' }, {
							 'display_id'  => 'AJ302600',
							 'primary_id'  => 'AJ302600',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'dbname'      => 'EMBL' }, {
							 'primary_id'  => 'AJ302601',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'display_id'  => 'AJ302601',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'dbname'      => 'EMBL' }, {
							 'primary_id'  => 'AJ302602',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'display_id'  => 'AJ302602',
							 'db_display'  => 'European Nucleotide Archive',
							 'description' => '',
							 'dbname'      => 'EMBL' }, {
							 'display_id'  => 'AJ302603',
							 'primary_id'  => 'AJ302603',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'dbname'      => 'EMBL' }, {
							 'dbname'      => 'EMBL',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'AL035402',
							 'display_id'  => 'AL035402' }, {
							 'dbname'      => 'EMBL',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'display_id'  => 'BX248413',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'BX248413' }, {
							 'display_id'  => 'CR759957',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'CR759957',
							 'dbname'      => 'EMBL',
							 'db_display'  => 'European Nucleotide Archive',
							 'description' => '' }, {
							 'dbname'      => 'EMBL',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'display_id'  => 'CR936923',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'CR936923' }, {
							 'display_id'  => 'CR759835',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'CR759835',
							 'dbname'      => 'EMBL',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive' }, {
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'BC103870',
							 'display_id'  => 'BC103870',
							 'dbname'      => 'EMBL',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive' }, {
							 'db_display'  => 'European Nucleotide Archive',
							 'description' => '',
							 'dbname'      => 'EMBL',
							 'primary_id'  => 'BC103871',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'display_id'  => 'BC103871' }, {
							 'dbname'      => 'EMBL',
							 'db_display'  => 'European Nucleotide Archive',
							 'description' => '',
							 'display_id'  => 'BC103872',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'BC103872' }, {
							 'dbname'      => 'EMBL',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'display_id'  => 'AF399628',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'AF399628' }, {
							 'display_id'  => 'BK004522',
							 'primary_id'  => 'BK004522',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'description' => '',
							 'db_display'  => 'European Nucleotide Archive',
							 'dbname'      => 'EMBL' }, {
							 'db_display'  => 'GOSlim GOA',
							 'description' => 'biological_process',
							 'dbname'      => 'goslim_goa',
							 'primary_id'  => 'GO:0008150',
							 'info_text'   => 'Generated via main',
							 'info_type'   => 'DEPENDENT',
							 'display_id'  => 'GO:0008150' }, {
							 'display_id'  => 'GO:0003674',
							 'primary_id'  => 'GO:0003674',
							 'info_text'   => 'Generated via main',
							 'info_type'   => 'DEPENDENT',
							 'db_display'  => 'GOSlim GOA',
							 'description' => 'molecular_function',
							 'dbname'      => 'goslim_goa' }, {
							 'display_id'  => 'GO:0005575',
							 'primary_id'  => 'GO:0005575',
							 'info_text'   => 'Generated via main',
							 'info_type'   => 'DEPENDENT',
							 'description' => 'cellular_component',
							 'db_display'  => 'GOSlim GOA',
							 'dbname'      => 'goslim_goa' }, {
							 'display_id'  => 'GO:0005623',
							 'info_text'   => 'Generated via main',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'GO:0005623',
							 'dbname'      => 'goslim_goa',
							 'description' => 'cell',
							 'db_display'  => 'GOSlim GOA' }, {
							 'primary_id'  => 'GO:0005886',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => 'Generated via main',
							 'display_id'  => 'GO:0005886',
							 'db_display'  => 'GOSlim GOA',
							 'description' => 'plasma membrane',
							 'dbname'      => 'goslim_goa' }, {
							 'dbname'      => 'goslim_goa',
							 'db_display'  => 'GOSlim GOA',
							 'description' => 'signal transducer activity',
							 'display_id'  => 'GO:0004871',
							 'info_text'   => 'Generated via main',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'GO:0004871' }, {
							 'dbname'      => 'goslim_goa',
							 'db_display'  => 'GOSlim GOA',
							 'description' => 'signal transduction',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => 'Generated via main',
							 'primary_id'  => 'GO:0007165',
							 'display_id'  => 'GO:0007165' }, {
							 'display_id'  => 'CAC20514.1',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'CAC20514',
							 'dbname'      => 'protein_id',
							 'description' => '',
							 'db_display'  => 'INSDC protein ID' }, {
							 'display_id'  => 'CAC20515.1',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'CAC20515',
							 'dbname'      => 'protein_id',
							 'db_display'  => 'INSDC protein ID',
							 'description' => '' }, {
							 'db_display'  => 'INSDC protein ID',
							 'description' => '',
							 'dbname'      => 'protein_id',
							 'primary_id'  => 'CAC20516',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'display_id'  => 'CAC20516.1' }, {
							 'primary_id'  => 'CAC20517',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'display_id'  => 'CAC20517.1',
							 'db_display'  => 'INSDC protein ID',
							 'description' => '',
							 'dbname'      => 'protein_id' }, {
							 'dbname'      => 'protein_id',
							 'db_display'  => 'INSDC protein ID',
							 'description' => '',
							 'display_id'  => 'CAC20518.1',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'CAC20518' }, {
							 'dbname'      => 'protein_id',
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'display_id'  => 'CAC20519.1',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'CAC20519' }, {
							 'display_id'  => 'CAC20520.1',
							 'primary_id'  => 'CAC20520',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'db_display'  => 'INSDC protein ID',
							 'description' => '',
							 'dbname'      => 'protein_id' }, {
							 'dbname'      => 'protein_id',
							 'db_display'  => 'INSDC protein ID',
							 'description' => '',
							 'display_id'  => 'CAC20521.1',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'CAC20521' }, {
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'dbname'      => 'protein_id',
							 'display_id'  => 'CAC20522.1',
							 'primary_id'  => 'CAC20522',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '' }, {
							 'dbname'      => 'protein_id',
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'CAC20523',
							 'display_id'  => 'CAC20523.1' }, {
							 'dbname'      => 'protein_id',
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'CAB42853',
							 'display_id'  => 'CAB42853.1' }, {
							 'display_id'  => 'CAI18243.1',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'CAI18243',
							 'dbname'      => 'protein_id',
							 'description' => '',
							 'db_display'  => 'INSDC protein ID' }, {
							 'display_id'  => 'CAI41643.1',
							 'primary_id'  => 'CAI41643',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'dbname'      => 'protein_id' }, {
							 'dbname'      => 'protein_id',
							 'db_display'  => 'INSDC protein ID',
							 'description' => '',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'CAI41768',
							 'display_id'  => 'CAI41768.2' }, {
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'dbname'      => 'protein_id',
							 'primary_id'  => 'CAM26052',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'display_id'  => 'CAM26052.1' }, {
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'dbname'      => 'protein_id',
							 'display_id'  => 'CAQ07349.1',
							 'primary_id'  => 'CAQ07349',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT' }, {
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'primary_id'  => 'CAQ07643',
							 'display_id'  => 'CAQ07643.1',
							 'dbname'      => 'protein_id',
							 'description' => '',
							 'db_display'  => 'INSDC protein ID' }, {
							 'display_id'  => 'CAQ07834.1',
							 'primary_id'  => 'CAQ07834',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'db_display'  => 'INSDC protein ID',
							 'description' => '',
							 'dbname'      => 'protein_id' }, {
							 'display_id'  => 'CAQ08425.1',
							 'primary_id'  => 'CAQ08425',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'dbname'      => 'protein_id' }, {
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'dbname'      => 'protein_id',
							 'primary_id'  => 'EAX03181',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'display_id'  => 'EAX03181.1' }, {
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'dbname'      => 'protein_id',
							 'primary_id'  => 'AAI03871',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'display_id'  => 'AAI03871.1' }, {
							 'display_id'  => 'AAI03872.1',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'AAI03872',
							 'dbname'      => 'protein_id',
							 'db_display'  => 'INSDC protein ID',
							 'description' => '' }, {
							 'db_display'  => 'INSDC protein ID',
							 'description' => '',
							 'dbname'      => 'protein_id',
							 'primary_id'  => 'AAI03873',
							 'info_text'   => '',
							 'info_type'   => 'DEPENDENT',
							 'display_id'  => 'AAI03873.1' }, {
							 'display_id'  => 'AAK95113.1',
							 'primary_id'  => 'AAK95113',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'dbname'      => 'protein_id' }, {
							 'dbname'      => 'protein_id',
							 'description' => '',
							 'db_display'  => 'INSDC protein ID',
							 'display_id'  => 'DAA04920.1',
							 'info_type'   => 'DEPENDENT',
							 'info_text'   => '',
							 'primary_id'  => 'DAA04920' }, {
							 'primary_id'  => 'NP_112165',
							 'info_text'   => '',
							 'info_type'   => 'SEQUENCE_MATCH',
							 'display_id'  => 'NP_112165.1',
							 'db_display'  => 'RefSeq peptide',
							 'description' => 'olfactory receptor 2W1 ',
							 'dbname'      => 'RefSeq_peptide' }, {
							 'db_display'  => 'UniParc',
							 'description' => undef,
							 'dbname'      => 'UniParc',
							 'primary_id'  => 'UPI000003FF8A',
							 'info_text'   => '',
							 'info_type'   => 'CHECKSUM',
							 'display_id'  => 'UPI000003FF8A' }, {
							 'info_text'  => 'Generated via uniprot_mapped',
							 'display_id' => 'OR2W1_HUMAN',
							 'info_type'  => 'DIRECT',
							 'synonyms'   => [
										 'B0S7Y5', 'Q5JNZ1', 'Q6IEU0', 'Q96R17',
										 'Q9GZL0', 'Q9GZL1' ],
							 'primary_id'  => 'Q9Y3N9',
							 'dbname'      => 'Uniprot/SWISSPROT',
							 'description' => 'Olfactory receptor 2W1 ',
							 'db_display'  => 'UniProtKB/Swiss-Prot' }, {
							 'primary_id'       => 'GO:0004984',
							 'associated_xrefs' => [],
							 'display_id'       => 'GO:0004984',
							 'linkage_types'    => [ {
									'source' => { 'display_id'      => undef,
												  'primary_id'      => 'IEA',
												  'db_display_name' => undef,
												  'dbname'          => undef,
												  'description'     => undef },
									'evidence' => 'olfactory receptor activity'
								  } ],
							 'description' => 'GO',
							 'dbname'      => 'GO' }, {
							 'primary_id'       => 'GO:0007186',
							 'associated_xrefs' => [],
							 'display_id'       => 'GO:0007186',
							 'linkage_types'    => [ {
									'evidence' =>
'G-protein coupled receptor signaling pathway',
									'source' => {
										'display_id'      => 'IPR000276',
										'primary_id'      => 'IEA',
										'db_display_name' => 'Interpro',
										'dbname' =>
'G protein-coupled receptor, rhodopsin-like',
										'description' => 'GPCR_Rhodpsn' } } ],
							 'description' => 'GO',
							 'dbname'      => 'GO' }, {
							 'display_id'       => 'GO:0005886',
							 'associated_xrefs' => [],
							 'primary_id'       => 'GO:0005886',
							 'dbname'           => 'GO',
							 'description'      => 'GO',
							 'linkage_types'    => [ {
												'source' => {
													 'primary_id'      => 'TAS',
													 'db_display_name' => undef,
													 'display_id'      => undef,
													 'description'     => undef,
													 'dbname'          => undef
												},
												'evidence' => 'plasma membrane'
											  } ] }, {
							 'display_id'       => 'GO:0004930',
							 'primary_id'       => 'GO:0004930',
							 'associated_xrefs' => [],
							 'description'      => 'GO',
							 'dbname'           => 'GO',
							 'linkage_types'    => [ {
									   'evidence' =>
										 'G-protein coupled receptor activity',
									   'source' => { 'description'     => undef,
													 'dbname'          => undef,
													 'primary_id'      => 'IEA',
													 'db_display_name' => undef,
													 'display_id'      => undef
									   } } ] }, {
							 'display_id'       => 'GO:0016021',
							 'primary_id'       => 'GO:0016021',
							 'associated_xrefs' => [],
							 'description'      => 'GO',
							 'dbname'           => 'GO',
							 'linkage_types'    => [ {
										   'source' => {
													 'display_id'      => undef,
													 'db_display_name' => undef,
													 'primary_id'      => 'IEA',
													 'description'     => undef,
													 'dbname'          => undef
										   },
										   'evidence' => 'integral to membrane'
										 } ] } ],
					  'transcript_id' => 'ENST00000377175',
					  'version'       => '1' } ],
			   'seq_region_synonyms' => undef,
			   'seq_region_name'     => '6',
			   'description'         => undef,
			   'supporting_features' => [ { 'start'      => '1',
											'analysis'   => 'human_cdna2genome',
											'db_display' => 'RefSeq DNA',
											'db_name'    => 'RefSeq_dna',
											'evalue'     => undef,
											'end'        => '963',
											'trans_id'   => 'ENST00000377175',
											'id'         => 'NM_030903.3' }, {
											'db_display' => 'CCDS',
											'analysis'   => 'ccds',
											'start'      => '1',
											'trans_id'   => 'ENST00000377175',
											'id'         => 'CCDS4656.1',
											'end'        => '963',
											'evalue'     => undef,
											'db_name'    => 'CCDS' } ],
			   'analysis' => 'Ensembl/Havana merge',
			   'name'     => 'OR2W1-001',
			   'exons'    => [ {
						   'coord_system' =>
							 { 'name' => 'chromosome', 'version' => 'GRCh38' },
						   'end'                 => '29013017',
						   'rank'                => '1',
						   'id'                  => 'ENSE00001691220',
						   'trans_id'            => 'ENST00000377175',
						   'seq_region_name'     => '6',
						   'version'             => '1',
						   'ensembl_object_type' => 'exon',
						   'start'               => '29011990',
						   'strand'              => '-1' } ],
			   'gene_id' => 'ENSG00000204704',
			   'version' => '1',
			   'xrefs'   => [ {
					  'db_display'  => 'Vega transcript',
					  'description' => undef,
					  'dbname'      => 'Vega_transcript',
					  'primary_id'  => 'OTTHUMT00000076053',
					  'info_text'   => 'Added during ensembl-vega production',
					  'info_type'   => 'NONE',
					  'display_id'  => 'OTTHUMT00000076053' }, {
					  'primary_id'  => 'OTTHUMT00000076053',
					  'info_type'   => 'NONE',
					  'info_text'   => '',
					  'display_id'  => 'OR2W1-001',
					  'description' => undef,
					  'db_display'  => 'Vega transcript',
					  'dbname'      => 'Vega_transcript' }, {
					  'dbname' => 'shares_CDS_and_UTR_with_OTTT',
					  'db_display' =>
'Transcript having exact match between ENSEMBL and HAVANA',
					  'description' => undef,
					  'display_id'  => 'OTTHUMT00000076053',
					  'info_text'   => '',
					  'info_type'   => 'NONE',
					  'primary_id'  => 'OTTHUMT00000076053' }, {
					  'display_id'  => 'uc003nlw.2',
					  'primary_id'  => 'uc003nlw.2',
					  'info_text'   => '',
					  'info_type'   => 'COORDINATE_OVERLAP',
					  'description' => undef,
					  'db_display'  => 'UCSC Stable ID',
					  'dbname'      => 'UCSC' }, {
					  'dbname'      => 'CCDS',
					  'db_display'  => 'CCDS',
					  'description' => '',
					  'info_text'   => '',
					  'info_type'   => 'DIRECT',
					  'primary_id'  => 'CCDS4656',
					  'display_id'  => 'CCDS4656.1' }, {
					  'info_text'  => 'Generated via ensembl_manual',
					  'info_type'  => 'DIRECT',
					  'primary_id' => '8281',
					  'synonyms'   => [ 'hs6M1-15' ],
					  'display_id' => 'OR2W1',
					  'dbname'     => 'HGNC',
					  'description' =>
						'olfactory receptor, family 2, subfamily W, member 1',
					  'db_display' => 'HGNC Symbol' }, {
					  'primary_id' => 'OR2W1-001',
					  'info_type'  => 'MISC',
					  'info_text'  => '',
					  'display_id' => 'OR2W1-001',
					  'description' =>
						'olfactory receptor, family 2, subfamily W, member 1',
					  'db_display' => 'HGNC transcript name',
					  'dbname'     => 'HGNC_trans_name' }, {
					  'dbname'      => 'RefSeq_mRNA',
					  'description' => '',
					  'db_display'  => 'RefSeq mRNA',
					  'info_type'   => 'DIRECT',
					  'info_text'   => 'Generated via otherfeatures',
					  'primary_id'  => 'NM_030903',
					  'display_id'  => 'NM_030903.3' } ],
			   'ensembl_object_type' => 'transcript',
			   'start'               => '29011990',
			   'strand'              => '-1' } ],
		'synonyms'        => [ 'hs6M1-15' ],
		'strand'          => '-1',
		'coord_system'    => { 'name' => 'chromosome', 'version' => 'GRCh38' },
		'end'             => '29013017',
		'biotype'         => 'protein_coding',
		'id'              => 'ENSG00000204704',
		'previous_ids'    => [ 'bananag' ],
		'seq_region_name' => '6',
		'description' =>
'olfactory receptor, family 2, subfamily W, member 1 [Source:HGNC Symbol;Acc:8281]',
		'analysis' => 'Ensembl/Havana merge' };
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

