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
use File::Slurp;
use FindBin qw( $Bin );
use JSON;
use XML::Simple;

BEGIN {
	use_ok('Bio::EnsEMBL::Production::Search::EBEyeFormatter');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

my $genome_in_file = File::Spec->catfile( $Bin, "genome_test.json" );
my $formatter = Bio::EnsEMBL::Production::Search::EBEyeFormatter->new();
subtest "EBEye genome", sub {
	my $out_file = File::Spec->catfile( $Bin, "ebeye_genome_test.xml" );
	$formatter->reformat_genome($genome_in_file, $out_file);
	my $genome =  XMLin($out_file, ForceArray => 1);
	my $genome_expected =  XMLin($out_file.'.expected', ForceArray => 1);
	is_deeply($genome,$genome_expected,"Testing structure");
	unlink $out_file;
};

subtest "EBEye genes", sub {
	my $in_file  = File::Spec->catfile( $Bin, "genes_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "ebeye_genes_test.json" );
};

done_testing;
