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
use File::Slurp;
use JSON;
use FindBin qw( $Bin );
use File::Spec;
use Data::Dumper;
use Log::Log4perl qw/:easy/;
use List::Util qw(first);


Log::Log4perl->easy_init($DEBUG);

BEGIN {
	use_ok('Bio::EnsEMBL::Production::Search::RegulationSolrFormatter');
}

my $genome_in_file = File::Spec->catfile( $Bin, "genome_test.json" );
my $genome         = decode_json( read_file($genome_in_file) );
my $formatter      = Bio::EnsEMBL::Production::Search::RegulationSolrFormatter->new();

subtest "Probes reformat", sub {
	my $in_file  = File::Spec->catfile( $Bin, "probes_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_probes_test.json" );
	$formatter->reformat_probes( $in_file, $out_file, $genome, 'funcgen' );
	my $new_probes = decode_json( read_file($out_file) );
	{
		my ($probe) = grep { $_->{id} eq '1165690' } @$new_probes;
		my $expected = {
			'website'          => 'http://www.ensembl.org/',
			'db_boost'         => 1,
			'reference_strain' => 0,
			'id'               => '1165690',
			'species'          => 'homo_sapiens',
			'ref_boost'        => 10,
			'domain_url' =>
'Homo_sapiens/Location/Genome?fdb=funcgen;ftype=ProbeFeature;id=1165690',
			'database_type' => 'funcgen',
			'description' =>
'AFFY probe 212:211; (HG-Focus array) hits the genome in 2 location(s). It hits transcripts in the following gene: ASCL1 (ENST00000266744)',
			'feature_type' => 'OligoProbe',
			'species_name' => 'Homo sapiens' };
		is_deeply( $probe, $expected );
	}
	{
		my ($probe) = grep { $_->{id} eq '1086121' } @$new_probes;
		my $expected = {
			'id'               => '1086121',
			'reference_strain' => 0,
			'db_boost'         => 1,
			'website'          => 'http://www.ensembl.org/',
			'species'          => 'homo_sapiens',
			'ref_boost'        => 10,
			'domain_url' =>
'Homo_sapiens/Location/Genome?fdb=funcgen;ftype=ProbeFeature;id=1086121',
			'description' =>
'AFFY probe 77:81; (HC-G110 array) hits the genome in 4 location(s). It hits transcripts in the following gene: AP003097.1 (ENST00000530657, ENST00000525099, ENST00000302279, ENST00000533336, ENST00000526755, ENST00000533383, ENST00000529687, ENST00000528400)',
			'species_name'  => 'Homo sapiens',
			'feature_type'  => 'OligoProbe',
			'database_type' => 'funcgen' };
		is_deeply( $probe, $expected );

	}
	{
		my ($probe) = grep { $_->{id} eq '13396' } @$new_probes;
		my $expected = {
			'database_type' => 'funcgen',
			'description' =>
'PHALANX probe PH_hs_0020454 (OneArray array) hits the genome in 1 location(s).',
			'species_name' => 'Homo sapiens',
			'feature_type' => 'OligoProbe',
			'ref_boost'    => 10,
			'domain_url' =>
'Homo_sapiens/Location/Genome?fdb=funcgen;ftype=ProbeFeature;id=13396',
			'species'          => 'homo_sapiens',
			'reference_strain' => 0,
			'website'          => 'http://www.ensembl.org/',
			'db_boost'         => 1,
			'id'               => '13396' };
		is_deeply( $probe, $expected );
	}
	unlink $out_file;
};

subtest "Probesets reformat", sub {
	my $in_file  = File::Spec->catfile( $Bin, "probesets_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_probesets_test.json" );
	$formatter->reformat_probesets( $in_file, $out_file, $genome, 'funcgen' );
	my $new_probes = decode_json( read_file($out_file) );
	{
		my ($probe) =
		  grep { $_->{id} eq 'homo_sapiens_probeset_1' } @$new_probes;
		my $expected = {
			'id'               => 'homo_sapiens_probeset_1',
			'species_name'     => 'Homo sapiens',
			'db_boost'         => 1,
			'database_type'    => 'funcgen',
			'feature_type'     => 'OligoProbe',
			'reference_strain' => 0,
			'species'          => 'homo_sapiens',
			'description' =>
'AFFY probeset 1000_at (HC-G110 array) hits the genome in 30 location(s). They hit transcripts in the following gene: MAPK3 (ENST00000263025, ENST00000322266, ENST00000461737, ENST00000466521, ENST00000484663, ENST00000485579, ENST00000490298, ENST00000494643)',
			'domain_url' =>
'Homo_sapiens/Location/Genome?fdb=funcgen;ftype=ProbeFeature;id=homo_sapiens_probeset_1;ptype=pset',
			'website'   => 'http://www.ensembl.org/',
			'ref_boost' => 10 };
		is_deeply( $probe, $expected );
	}
	{
		my ($probe) =
		  grep { $_->{id} eq 'homo_sapiens_probeset_201' } @$new_probes;
		my $expected = {
			'id'               => 'homo_sapiens_probeset_201',
			'reference_strain' => 0,
			'species_name'     => 'Homo sapiens',
			'description' =>
'AFFY probeset 1059_at (HC-G110 array) hits the genome in 23 location(s).',
			'ref_boost' => 10,
			'species'   => 'homo_sapiens',
			'domain_url' =>
'Homo_sapiens/Location/Genome?fdb=funcgen;ftype=ProbeFeature;id=homo_sapiens_probeset_201;ptype=pset',
			'feature_type'  => 'OligoProbe',
			'database_type' => 'funcgen',
			'website'       => 'http://www.ensembl.org/',
			'db_boost'      => 1 };
		is_deeply( $probe, $expected );

	}
	unlink $out_file;
};

subtest "Regulatory features reformat", sub {
	my $in_file  = File::Spec->catfile( $Bin, "regulatory_features_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_regulatory_test.json" );
	$formatter->reformat_regulation( $in_file, $out_file, $genome,
											  'funcgen' );
	my $new_reg_features = decode_json( read_file($out_file) );
	is( scalar @$new_reg_features, 4 );

	{
		my $e = {   'database_type' => 'funcgen',
								'db_boost' => 1,
								'description' => 'Promoter Flanking Region regulatory feature',
								'domain_url' => 'Homo_sapiens/Regulation/Summary?rf=ENSR00000999056',
								'feature_type' => 'Regulatory Features',
								'id' => 'ENSR00000999056',
								'ref_boost' => 10,
								'reference_strain' => 0,
								'species' => 'homo_sapiens',
								'species_name' => 'Homo sapiens',
								'website' => 'http://www.ensembl.org/' };
		my ($g) = first { $_->{id} eq 'ENSR00000999056' } @$new_reg_features;
		is_deeply( $g, $e );
	}
	{
		my $e = {     'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Enhancer regulatory feature',
									'domain_url' => 'Homo_sapiens/Regulation/Summary?rf=ENSR00000530121',
									'feature_type' => 'Regulatory Features',
									'id' => 'ENSR00000530121',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/' };
		my ($g) = first { $_->{id} eq 'ENSR00000530121' } @$new_reg_features;
		is_deeply( $g, $e );
	}
	{
		my $e = {   'database_type' => 'funcgen',
								'db_boost' => 1,
								'description' => 'Open chromatin regulatory feature',
								'domain_url' => 'Homo_sapiens/Regulation/Summary?rf=ENSR00000673436',
								'feature_type' => 'Regulatory Features',
								'id' => 'ENSR00000673436',
								'ref_boost' => 10,
								'reference_strain' => 0,
								'species' => 'homo_sapiens',
								'species_name' => 'Homo sapiens',
								'website' => 'http://www.ensembl.org/' };
		my ($g) = first { $_->{id} eq 'ENSR00000673436' } @$new_reg_features;
		is_deeply( $g, $e );
	}
	{
		my $e = {   'database_type' => 'funcgen',
								'db_boost' => 1,
								'description' => 'Open chromatin regulatory feature',
								'domain_url' => 'Homo_sapiens/Regulation/Summary?rf=ENSR00000917529',
								'feature_type' => 'Regulatory Features',
								'id' => 'ENSR00000917529',
								'ref_boost' => 10,
								'reference_strain' => 0,
								'species' => 'homo_sapiens',
								'species_name' => 'Homo sapiens',
								'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'ENSR00000917529' } @$new_reg_features;
		is_deeply( $g, $e );
	}
	unlink $out_file;
};

subtest "Motifs reformat", sub {
	my $in_file  = File::Spec->catfile( $Bin, "motifs_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_motifs.json" );
	$formatter->reformat_regulation( $in_file, $out_file, $genome,
											  'funcgen' );
	my $new_motifs = decode_json( read_file($out_file) );
	is( scalar @$new_motifs, 6 );

	{
		my $e = {      'database_type' => 'funcgen',
										'db_boost' => 1,
										'description' => 'Binding motif with stable id ENSPFM0573 and a score of -2 which hits the genome in 7:97417461-97417488:1 locations',
										'domain_url' => undef,
										'feature_type' => 'Binding Motifs',
										'id' => 'ENSM00166647826',
										'ref_boost' => 10,
										'reference_strain' => 0,
										'species' => 'homo_sapiens',
										'species_name' => 'Homo sapiens',
										'website' => 'http://www.ensembl.org/' };
		my ($g) = first { $_->{id} eq 'ENSM00166647826' } @$new_motifs;
		is_deeply( $g, $e );
	}
	{
		my $e = {       'database_type' => 'funcgen',
										'db_boost' => 1,
										'description' => 'Binding motif with stable id ENSPFM0573 and a score of 1 which hits the genome in 11:102389587-102389614:1 locations',
										'domain_url' => undef,
										'feature_type' => 'Binding Motifs',
										'id' => 'ENSM00521793739',
										'ref_boost' => 10,
										'reference_strain' => 0,
										'species' => 'homo_sapiens',
										'species_name' => 'Homo sapiens',
										'website' => 'http://www.ensembl.org/' };
		my ($g) = first { $_->{id} eq 'ENSM00521793739' } @$new_motifs;
		is_deeply( $g, $e );
	}
	{
		my $e = {      'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Binding motif with stable id ENSPFM0573 and a score of -3 which hits the genome in 14:69048581-69048608:-1 locations',
									'domain_url' => undef,
									'feature_type' => 'Binding Motifs',
									'id' => 'ENSM00521793740',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'ENSM00521793740' } @$new_motifs;
		is_deeply( $g, $e );
	}
	{
		my $e = {     'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Binding motif with stable id ENSPFM0573 and a score of -2 which hits the genome in 16:29460528-29460555:-1 locations',
									'domain_url' => undef,
									'feature_type' => 'Binding Motifs',
									'id' => 'ENSM00521793741',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'ENSM00521793741' } @$new_motifs;
		is_deeply( $g, $e );
	}
	{
		my $e = {
									'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Binding motif with stable id ENSPFM0573 and a score of 2 which hits the genome in 10:30423551-30423578:1 locations',
									'domain_url' => undef,
									'feature_type' => 'Binding Motifs',
									'id' => 'ENSM00207470375',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'ENSM00207470375' } @$new_motifs;
		is_deeply( $g, $e );
	}
	{
		my $e = {
										'database_type' => 'funcgen',
										'db_boost' => 1,
										'description' => 'Binding motif with stable id ENSPFM0573 and a score of 0 which hits the genome in 7:60920514-60920541:1 locations',
										'domain_url' => undef,
										'feature_type' => 'Binding Motifs',
										'id' => 'ENSM00482444211',
										'ref_boost' => 10,
										'reference_strain' => 0,
										'species' => 'homo_sapiens',
										'species_name' => 'Homo sapiens',
										'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'ENSM00482444211' } @$new_motifs;
		is_deeply( $g, $e );
	}
	unlink $out_file;
};
subtest "TarBase miRNA reformat", sub {
	my $in_file  = File::Spec->catfile( $Bin, "mirnas_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_mirnas_test.json" );
	$formatter->reformat_regulation( $in_file, $out_file, $genome,
											  'funcgen' );
	my $new_mirnas = decode_json( read_file($out_file) );
	is( scalar @$new_mirnas, 1 );

	{
		my $e = {      'database_type' => 'funcgen',
										'db_boost' => 1,
										'description' => 'hsa-miR-4524a-5p is a RNA from TarBase miRNA which hits the genome in 55 locations',
										'domain_url' => 'Homo_sapiens/Location/Genome?ftype=RegulatoryFactor;id=hsa-miR-4524a-5p;fset=TarBase miRNA',
										'feature_type' => 'TarBase miRNA',
										'id' => 'hsa-miR-4524a-5p',
										'ref_boost' => 10,
										'reference_strain' => 0,
										'species' => 'homo_sapiens',
										'species_name' => 'Homo sapiens',
										'website' => 'http://www.ensembl.org/' };
		my ($g) = first { $_->{id} eq 'hsa-miR-4524a-5p' } @$new_mirnas;
		is_deeply( $g, $e );
	}
	unlink $out_file;
};
subtest "External features reformat", sub {
	my $in_file  = File::Spec->catfile( $Bin, "external_features_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_external_feature_test.json" );
	$formatter->reformat_regulation( $in_file, $out_file, $genome,
											  'funcgen' );
	my $new_ext_features = decode_json( read_file($out_file) );
	is( scalar @$new_ext_features, 3 );

	{
		my $e = {     'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Other regulatory region with name p@chr12:133109321..133109323,+,0.1677 is a Transcription Start Site from FANTOM TSS, relaxed which hits the genome in 1 locations',
									'domain_url' => undef,
									'feature_type' => 'Other Regulatory Regions',
									'id' => 'p@chr12:133109321..133109323,+,0.1677',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/' };
		my ($g) = first { $_->{id} eq 'p@chr12:133109321..133109323,+,0.1677' } @$new_ext_features;
		is_deeply( $g, $e );
	}
	{
		my $e = {       'database_type' => 'funcgen',
										'db_boost' => 1,
										'description' => 'Other regulatory region with name p12@APOM,0.1654 is a Transcription Start Site from FANTOM TSS, relaxed which hits the genome in 1 locations',
										'domain_url' => undef,
										'feature_type' => 'Other Regulatory Regions',
										'id' => 'p12@APOM,0.1654',
										'ref_boost' => 10,
										'reference_strain' => 0,
										'species' => 'homo_sapiens',
										'species_name' => 'Homo sapiens',
										'website' => 'http://www.ensembl.org/' };
		my ($g) = first { $_->{id} eq 'p12@APOM,0.1654' } @$new_ext_features;
		is_deeply( $g, $e );
	}
	{
		my $e = {     'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Other regulatory region with name p@chr11:134253749..134253754,+,0.2358 is a Transcription Start Site from FANTOM TSS, strict which hits the genome in 1 locations',
									'domain_url' => undef,
									'feature_type' => 'Other Regulatory Regions',
									'id' => 'p@chr11:134253749..134253754,+,0.2358',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/' };
		my ($g) = first { $_->{id} eq 'p@chr11:134253749..134253754,+,0.2358' } @$new_ext_features;
		is_deeply( $g, $e );
	}
	unlink $out_file;
};
subtest "Peaks reformat", sub {
	my $in_file  = File::Spec->catfile( $Bin, "peaks_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_peaks_test.json" );
	$formatter->reformat_regulation( $in_file, $out_file, $genome,
											  'funcgen' );
	my $new_peaks = decode_json( read_file($out_file) );
	is( scalar @$new_peaks, 1 );

	{
		my $e = {     'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Regulatory Evidence with name H3K4me3 is a Histone from Histone 3 Lysine 4 Tri-Methylation with epigenome IHECRE00001049 which hits the genome in 1494 locations',
									'domain_url' => undef,
									'feature_type' => 'Regulatory Evidence',
									'id' => 'H3K4me3',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'H3K4me3' } @$new_peaks;
		is_deeply( $g, $e );
	}
	unlink $out_file;
};
subtest "Transcription factors reformat", sub {
	my $in_file  = File::Spec->catfile( $Bin, "transcription_factors_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_transcription_factors_test.json" );
	$formatter->reformat_regulation( $in_file, $out_file, $genome,
											  'funcgen' );
	my $new_transcription_factors = decode_json( read_file($out_file) );
	is( scalar @$new_transcription_factors, 7 );

	{
		my $e = {     'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Transcription factor with name VDR is a VDR Transcription Factor Binding which hits Ensembl gene id ENSG00000111424',
									'domain_url' => undef,
									'feature_type' => 'Transcription Factor',
									'id' => 'VDR',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/' };
		my ($g) = first { $_->{id} eq 'VDR' } @$new_transcription_factors;
		is_deeply( $g, $e );
	}
	{
		my $e = {     'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Transcription factor with name PKNOX1 is a PKNOX1 TF binding which hits Ensembl gene id ENSG00000160199',
									'domain_url' => undef,
									'feature_type' => 'Transcription Factor',
									'id' => 'PKNOX1',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'PKNOX1' } @$new_transcription_factors;
		is_deeply( $g, $e );
	}
	{
		my $e = {     'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Transcription factor with name CLOCK is a CLOCK TF binding which hits Ensembl gene id ENSG00000134852 with 15 Binding matrix',
									'domain_url' => undef,
									'feature_type' => 'Transcription Factor',
									'id' => 'CLOCK',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'CLOCK' } @$new_transcription_factors;
		is_deeply( $g, $e );
	}
	{
		my $e = {   'database_type' => 'funcgen',
								'db_boost' => 1,
								'description' => 'Transcription factor with name CREB3L1 is a CREB3L1 TF binding which hits Ensembl gene id ENSG00000157613 with 2 Binding matrix',
								'domain_url' => undef,
								'feature_type' => 'Transcription Factor',
								'id' => 'CREB3L1',
								'ref_boost' => 10,
								'reference_strain' => 0,
								'species' => 'homo_sapiens',
								'species_name' => 'Homo sapiens',
								'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'CREB3L1' } @$new_transcription_factors;
		is_deeply( $g, $e );
	}
	{
		my $e = {   'database_type' => 'funcgen',
								'db_boost' => 1,
								'description' => 'Transcription factor with name E2F7 is a E2F7 TF binding which hits Ensembl gene id ENSG00000165891',
								'domain_url' => undef,
								'feature_type' => 'Transcription Factor',
								'id' => 'E2F7',
								'ref_boost' => 10,
								'reference_strain' => 0,
								'species' => 'homo_sapiens',
								'species_name' => 'Homo sapiens',
								'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'E2F7' } @$new_transcription_factors;
		is_deeply( $g, $e );
	}
		{
		my $e = {     'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Transcription factor with name ZBTB7B is a ZBTB7B TF binding which hits Ensembl gene id ENSG00000160685',
									'domain_url' => undef,
									'feature_type' => 'Transcription Factor',
									'id' => 'ZBTB7B',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'ZBTB7B' } @$new_transcription_factors;
		is_deeply( $g, $e );
	}
		{
		my $e = {     'database_type' => 'funcgen',
									'db_boost' => 1,
									'description' => 'Transcription factor with name IRF4 is a IRF4 Transcription Factor Binding which hits Ensembl gene id ENSG00000137265',
									'domain_url' => undef,
									'feature_type' => 'Transcription Factor',
									'id' => 'IRF4',
									'ref_boost' => 10,
									'reference_strain' => 0,
									'species' => 'homo_sapiens',
									'species_name' => 'Homo sapiens',
									'website' => 'http://www.ensembl.org/'};
		my ($g) = first { $_->{id} eq 'IRF4' } @$new_transcription_factors;
		is_deeply( $g, $e );
	}
	unlink $out_file;
};

done_testing;
