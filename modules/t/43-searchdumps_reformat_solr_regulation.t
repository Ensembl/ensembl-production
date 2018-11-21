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
use warnings;
use strict;

use Test::More;
use File::Slurp;
use JSON;
use FindBin qw( $Bin );
use File::Spec;
use Data::Dumper;

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
	my $in_file  = File::Spec->catfile( $Bin, "regulatory_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_regulatory_test.json" );
	$formatter->reformat_regulatory_features( $in_file, $out_file, $genome,
											  'funcgen' );
	my $new_elems = decode_json( read_file($out_file) );
	is( scalar @$new_elems, 6 );

	{
		my $e = { 'ref_boost'        => 10,
				  'reference_strain' => 0,
				  'feature_type'     => 'RegulatoryFeature',
				  'species'          => 'homo_sapiens',
				  'website'          => 'http://www.ensembl.org/',
				  'db_boost'         => 1,
				  'description'      => 'Promoter regulatory feature',
				  'domain_url' =>
					'Homo_sapiens/Regulation/Summary?rf=ENSR00000082108',
				  'species_name'  => 'Homo sapiens',
				  'id'            => 'ENSR00000082108',
				  'database_type' => 'funcgen' };
		my ($g) = grep { $_->{id} eq 'ENSR00000082108' } @$new_elems;
		is_deeply( $g, $e );
	}
	{
		my $e = { 'description'   => 'Enhancer regulatory feature',
				  'database_type' => 'funcgen',
				  'species_name'  => 'Homo sapiens',
				  'id'            => 'ENSR00000082147',
				  'domain_url' =>
					'Homo_sapiens/Regulation/Summary?rf=ENSR00000082147',
				  'species'          => 'homo_sapiens',
				  'website'          => 'http://www.ensembl.org/',
				  'feature_type'     => 'RegulatoryFeature',
				  'db_boost'         => 1,
				  'reference_strain' => 0,
				  'ref_boost'        => 10 };
		my ($g) = grep { $_->{id} eq 'ENSR00000082147' } @$new_elems;
		is_deeply( $g, $e );
	}
	{
		my $e = { 'ref_boost'        => 10,
				  'reference_strain' => 0,
				  'db_boost'         => 1,
				  'species'          => 'homo_sapiens',
				  'feature_type'     => 'RegulatoryFeature',
				  'website'          => 'http://www.ensembl.org/',
				  'id'               => 'ENSR00000279375',
				  'species_name'     => 'Homo sapiens',
				  'domain_url' =>
					'Homo_sapiens/Regulation/Summary?rf=ENSR00000279375',
				  'database_type' => 'funcgen',
				  'description'   => 'CTCF Binding Site regulatory feature' };
		my ($g) = grep { $_->{id} eq 'ENSR00000279375' } @$new_elems;
		is_deeply( $g, $e );
	}
	{
		my $e = { 'reference_strain' => 0,
				  'description'      => 'Open chromatin regulatory feature',
				  'domain_url' =>
					'Homo_sapiens/Regulation/Summary?rf=ENSR00000082116',
				  'species_name'  => 'Homo sapiens',
				  'database_type' => 'funcgen',
				  'id'            => 'ENSR00000082116',
				  'species'       => 'homo_sapiens',
				  'website'       => 'http://www.ensembl.org/',
				  'feature_type'  => 'RegulatoryFeature',
				  'db_boost'      => 1,
				  'ref_boost'     => 10 };
		my ($g) = grep { $_->{id} eq 'ENSR00000082116' } @$new_elems;
		is_deeply( $g, $e );
	}
	{
		my $e = { 'ref_boost'        => 10,
				  'reference_strain' => 0,
				  'db_boost'         => 1,
				  'website'          => 'http://www.ensembl.org/',
				  'species'          => 'homo_sapiens',
				  'feature_type'     => 'RegulatoryFeature',
				  'species_name'     => 'Homo sapiens',
				  'database_type'    => 'funcgen',
				  'id'               => 'ENSR00000082128',
				  'domain_url' =>
					'Homo_sapiens/Regulation/Summary?rf=ENSR00000082128',
				  'description' => 'TF binding site regulatory feature' };
		my ($g) = grep { $_->{id} eq 'ENSR00000082128' } @$new_elems;
		is_deeply( $g, $e );
	}
	{
		my $e = {
			'ref_boost'        => 10,
			'reference_strain' => 0,
			'description' =>
'hsa-miR-7-5p is a RNA from TarBase miRNA which hits the genome in 5 locations',
			'domain_url' =>
'Homo_sapiens/Location/Genome?ftype=RegulatoryFactor;id=hsa-miR-7-5p;fset=TarBase miRNA',
			'species_name'  => 'Homo sapiens',
			'id'            => 'hsa-miR-7-5p',
			'database_type' => 'funcgen',
			'species'       => 'homo_sapiens',
			'feature_type'  => 'RegulatoryFeature',
			'website'       => 'http://www.ensembl.org/',
			'db_boost'      => 1 };
		my ($g) = grep { $_->{id} eq 'hsa-miR-7-5p' } @$new_elems;
		is_deeply( $g, $e );
	}
	unlink $out_file;
};

done_testing;
