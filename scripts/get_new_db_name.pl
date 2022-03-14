#!/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

if(scalar(@ARGV) != 1) {
    die "Usage $0 <db_name>";
}
my $name = $ARGV[0];
if($name =~ m/^(.*_[a-z]+_)([0-9]+)$/) {
    my $v = $2 + 1;
    print "$1$v\n";
} elsif($name =~ m/^(.+_[a-z]+_)([0-9]+)_([0-9]+)(_[^_]+)$/) {
    my $v1 = $2 + 1;
    my $v2 = $3 + 1;
    print "${1}${v1}_${v2}${4}\n";
} elsif($name =~ m/^(.*_[a-z]+_)([0-9]+)_([0-9]+)$/) {
    my $v1 = $2 + 1;
    print "${1}${v1}_${3}\n";
} else {
    print "$name\n";
}
