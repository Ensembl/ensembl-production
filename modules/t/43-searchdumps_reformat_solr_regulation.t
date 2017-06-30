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
	use_ok('Bio::EnsEMBL::Production::Search::SolrFormatter');
}

my $genome_in_file = File::Spec->catfile( $Bin, "genome_test.json" );
my $genome         = decode_json( read_file($genome_in_file) );
my $formatter      = Bio::EnsEMBL::Production::Search::SolrFormatter->new();

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
	my $out_file = File::Spec->catfile( $Bin, "solr_probes_test.json" );
	$formatter->reformat_probesets( $in_file, $out_file, $genome, 'funcgen' );
	my $new_probes = decode_json( read_file($out_file) );
	{
		my ($probe) = grep { $_->{id} eq 'homo_sapiens_probeset_1' } @$new_probes;
		my $expected = {
          'id' => 'homo_sapiens_probeset_1',
          'species_name' => 'Homo sapiens',
          'db_boost' => 1,
          'database_type' => 'funcgen',
          'feature_type' => 'OligoProbe',
          'reference_strain' => 0,
          'species' => 'homo_sapiens',
          'description' => 'AFFY probeset 1000_at (HC-G110 array) hits the genome in 30 location(s). They hit transcripts in the following gene: MAPK3 (ENST00000263025, ENST00000322266, ENST00000461737, ENST00000466521, ENST00000484663, ENST00000485579, ENST00000490298, ENST00000494643)',
          'domain_url' => 'Homo_sapiens/Location/Genome?fdb=funcgen;ftype=ProbeFeature;id=homo_sapiens_probeset_1;ptype=pset',
          'website' => 'http://www.ensembl.org/',
          'ref_boost' => 10
        };
		is_deeply( $probe, $expected );
	}
	{
		my ($probe) = grep { $_->{id} eq 'homo_sapiens_probeset_201' } @$new_probes;
		my $expected = {
          'id' => 'homo_sapiens_probeset_201',
          'reference_strain' => 0,
          'species_name' => 'Homo sapiens',
          'description' => 'AFFY probeset 1059_at (HC-G110 array) hits the genome in 23 location(s).',
          'ref_boost' => 10,
          'species' => 'homo_sapiens',
          'domain_url' => 'Homo_sapiens/Location/Genome?fdb=funcgen;ftype=ProbeFeature;id=homo_sapiens_probeset_201;ptype=pset',
          'feature_type' => 'OligoProbe',
          'database_type' => 'funcgen',
          'website' => 'http://www.ensembl.org/',
          'db_boost' => 1
        };
		is_deeply( $probe, $expected );

	}
	unlink $out_file;
};

done_testing;
