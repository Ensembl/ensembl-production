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
	use_ok('Bio::EnsEMBL::Production::Search::VariationSolrFormatter');
}

my $genome_in_file = File::Spec->catfile( $Bin, "genome_test.json" );
my $genome         = decode_json( read_file($genome_in_file) );
my $formatter      = Bio::EnsEMBL::Production::Search::VariationSolrFormatter->new();

subtest "Variation reformat", sub {
	my $in_file  = File::Spec->catfile( $Bin, "variants_test.json" );
	my $out_file = File::Spec->catfile( $Bin, "solr_variants_test.json" );
	$formatter->reformat_variants( $in_file, $out_file, $genome, 'variation' );
	my $new_variations = decode_json( read_file($out_file) );
	{
		my ($var) = grep { $_->{id} eq 'rs7569578' } @$new_variations;
		print Dumper($var);
	}
	{
		my ($var) = grep { $_->{id} eq 'rs2299222' } @$new_variations;
		print Dumper($var);
	}
  	unlink $out_file;
};

done_testing;
