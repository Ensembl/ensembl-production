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
use JSON;
use File::Slurp;
use Data::Dumper;

BEGIN {
	use_ok('Bio::EnsEMBL::Production::Search::JSONReformatter');
}

diag("Testing ensembl-production Bio::EnsEMBL::Production::Search, Perl $], $^X"
);

subtest "Array only", sub {
	# create a test structure
	my $test_data = [ {  a => 1,
						 b => 2,
						 c => [ { d => 3 }, { d => 4 }, { d => 5 } ] }, {
						 a => 2,
						 b => 5,
						 c => [ { d => 3 }, { d => 4 }, { d => 5 } ] },
					  { a => 3, b => 9 },
					  { a => 4 } ];

	# write to a JSON file
	my $test_file = "./40-searchdumps_reformat_base.json";
	open my $out, ">",
	  $test_file || die "Could not open $test_file for writing";
	print $out encode_json($test_data);
	close $out;
	my $objs = [];
	process_json_file(
		$test_file,
		sub {
			my $obj = shift;
			push @$objs, $obj;
			return;
		} );
	unlink $test_file;
	is_deeply( $objs, $test_data, "Comparing input and output" );
};

subtest "Array with flanking whitespace", sub {
	# create a test structure
	my $test_data = [ {  a => 1,
						 b => 2,
						 c => [ { d => 3 }, { d => 4 }, { d => 5 } ] }, {
						 a => 2,
						 b => 5,
						 c => [ { d => 3 }, { d => 4 }, { d => 5 } ] },
					  { a => 3, b => 9 },
					  { a => 4 } ];

	# write to a JSON file
	my $test_file = "./40-searchdumps_reformat_base.json";
	open my $out, ">",
	  $test_file || die "Could not open $test_file for writing";
	print $out " \t\n";
	print $out encode_json($test_data);
	print $out " \t\n";
	close $out;
	my $objs = [];
	process_json_file(
		$test_file,
		sub {
			my $obj = shift;
			push @$objs, $obj;
			return;
		} );
	unlink $test_file;
	is_deeply( $objs, $test_data, "Comparing input and output" );
};

subtest "Empty array", sub {
	# create a test structure
	my $test_data = [];
	# write to a JSON file
	my $test_file = "./40-searchdumps_reformat_base.json";
	open my $out, ">",
	  $test_file || die "Could not open $test_file for writing";
	print $out encode_json($test_data);
	close $out;
	my $objs = [];
	eval {
		process_json_file(
			$test_file,
			sub {
				my $obj = shift;
				push @$objs, $obj;
				return;
			} );
		fail("Processing an empty array should raise an error");
	};
	if ($@) {
		pass("Processing an empty array should raise an error");
	}
	unlink $test_file;
};

subtest "Hash", sub {
	# create a test structure
	my $test_data = { a => 1 };
	# write to a JSON file
	my $test_file = "./40-searchdumps_reformat_base.json";
	open my $out, ">",
	  $test_file || die "Could not open $test_file for writing";
	print $out encode_json($test_data);
	close $out;
	my $objs = [];
	eval {
		process_json_file(
			$test_file,
			sub {
				my $obj = shift;
				push @$objs, $obj;
				return;
			} );
		fail("Processing a non-array should raise an error");
	};
	if ($@) {
		pass("Processing a non-array should raise an error");
	}
	unlink $test_file;
};

subtest "Reformat object file", sub {
	# create a test structure
	my $test_data = [ { a => 1 }, { a => 2 }, { a => 3 } ];
	# write to a JSON file
	my $test_file = "./40-searchdumps_reformat_base.json";
	open my $out, ">",
	  $test_file || die "Could not open $test_file for writing";
	print $out encode_json($test_data);
	close $out;
	my $out_file = "./40-searchdumps_reformat_base_out.json";
	reformat_json(
		$test_file, $out_file,
		sub {
			my $obj = shift;
			return { b => $obj->{a}, done => 1 };
		} );
	my $test_data2 = decode_json( read_file($out_file) );
	is( 3, scalar @$test_data2, "3 objs" );
	my $obj1 = $test_data2->[0];
	my $obj2 = $test_data2->[1];
	my $obj3 = $test_data2->[2];
	is( 1, $obj1->{b},    "b in obj 0" );
	is( 2, $obj2->{b},    "b in obj 1" );
	is( 3, $obj3->{b},    "b in obj 2" );
	is( 1, $obj1->{done}, "done in obj 0" );
	is( 1, $obj2->{done}, "done in obj 1" );
	is( 1, $obj3->{done}, "done in obj 2" );
	ok( !defined $obj1->{a}, "a in obj 0" );
	ok( !defined $obj2->{a}, "a in obj 0" );
	ok( !defined $obj3->{a}, "a in obj 0" );
	unlink $test_file;
	unlink $out_file;
};

subtest "Reformat object file with arrays", sub {
	# create a test structure
	my $test_data = [ { a => 1 }, { a => 2 }, { a => 3 } ];
	# write to a JSON file
	my $test_file = "./40-searchdumps_reformat_base.json";
	open my $out, ">",
	  $test_file || die "Could not open $test_file for writing";
	print $out encode_json($test_data);
	close $out;
	my $out_file = "./40-searchdumps_reformat_base_out.json";
	reformat_json(
		$test_file, $out_file,
		sub {
			my $obj = shift;
			return [{ b => $obj->{a}},{ done => 1 }];
		} );
	my $test_data2 = decode_json( read_file($out_file) );
	is( 6, scalar @$test_data2, "6 objs" );
	my $obj1 = $test_data2->[0];
	my $obj2 = $test_data2->[1];
	my $obj3 = $test_data2->[2];
	my $obj4 = $test_data2->[3];
	my $obj5 = $test_data2->[4];
	my $obj6 = $test_data2->[5];
	is( 1, $obj1->{b},    "b in obj 0" );
	is( 2, $obj3->{b},    "b in obj 2" );
	is( 3, $obj5->{b},    "b in obj 4" );
	is( 1, $obj2->{done}, "done in obj 1" );
	is( 1, $obj4->{done}, "done in obj 3" );
	is( 1, $obj6->{done}, "done in obj 5" );
	ok( !defined $obj1->{a}, "a in obj 0" );
	ok( !defined $obj2->{a}, "a in obj 0" );
	ok( !defined $obj3->{a}, "a in obj 0" );
	unlink $test_file;
	unlink $out_file;
};

done_testing;
