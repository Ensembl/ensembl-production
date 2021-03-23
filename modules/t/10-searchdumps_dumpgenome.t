#!perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
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

use Bio::EnsEMBL::Production::Search::GenomeFetcher;
use Bio::EnsEMBL::MetaData::GenomeInfo;

BEGIN {
	use_ok('Bio::EnsEMBL::Production::Search::GenomeFetcher');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X");

my %oargs = ( '-NAME'                => "test",
			  '-DISPLAY_NAME'        => "Testus testa",
			  '-TAXONOMY_ID'         => 999,
			  '-SPECIES_TAXONOMY_ID' => 99,
			  '-STRAIN'              => 'stress',
			  '-SEROTYPE'            => 'icky',
			  '-IS_REFERENCE'        => 1 );
my $org = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(%oargs);
$org->aliases( ["alias"] );

my %aargs = ( '-ASSEMBLY_NAME'      => "v2.0",
			  '-ASSEMBLY_ACCESSION' => 'GCA_181818181.1',
			  '-ASSEMBLY_LEVEL'     => 'chromosome',
			  '-BASE_COUNT'         => 99 );

my $assembly = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(%aargs);
$assembly->sequences( [ { name => "a", acc => "xyz.1" } ] );

my %rargs = ( -ENSEMBL_VERSION         => 999,
			  -ENSEMBL_GENOMES_VERSION => 666,
			  -RELEASE_DATE            => '2025-09-29' );
my $release = Bio::EnsEMBL::MetaData::DataReleaseInfo->new(%rargs);

my %args = ( '-DBNAME'       => "test_species_core_27_80_1",
			 '-SPECIES_ID'   => 1,
			 '-GENEBUILD'    => 'awesomeBuild1',
			 '-DIVISION'     => 'EnsemblSomewhere',
			 '-IS_REFERENCE' => 1,
			 '-ASSEMBLY'     => $assembly,
			 '-ORGANISM'     => $org,
			 '-DATA_RELEASE' => $release );
my $genome = Bio::EnsEMBL::MetaData::GenomeInfo->new(%args);

my $fetcher = Bio::EnsEMBL::Production::Search::GenomeFetcher->new();

my $genome_hash = $fetcher->metadata_to_hash($genome);
ok ( $genome_hash , "Genome hash returned");

is( $genome->dbname(),     $genome_hash->{dbname},     "dbname correct" );
is( $genome->species_id(), $genome_hash->{species_id}, "species_id correct" );
is( $genome->division(),   $genome_hash->{division},   "division correct" );
is( $genome->genebuild(),  $genome_hash->{genebuild},  "genebuild correct" );
is( $genome->reference(), $genome_hash->{reference}, "reference correct" );
is( $genome->assembly_name(), $genome_hash->{assembly}->{name},	"ass name correct" );
is( $genome->assembly_accession(), $genome_hash->{assembly}->{accession}, "ass ID correct" );
is( $genome->assembly_level(), $genome_hash->{assembly}->{level}, "ass level correct" );
is( $genome->name(), $genome_hash->{organism}->{name}, "name correct" );
is( $genome->display_name(), $genome_hash->{organism}->{display_name}, "display_name ID correct" );
is( $genome->taxonomy_id(),	$genome_hash->{organism}->{taxonomy_id}, "taxid correct" );
is( $genome->species_taxonomy_id(),	$genome_hash->{organism}->{species_taxonomy_id}, "species taxid correct" );
is( $genome->strain(), $genome_hash->{organism}->{strain}, "strain correct" );
is( $genome->serotype(), $genome_hash->{organism}->{serotype}, "serotype correct" );

done_testing();
