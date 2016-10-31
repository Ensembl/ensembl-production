#!/bin/env perl

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
    my $v2 = $3 + 1;
    print "${1}${v1}_${v2}\n";
} else {
    print "$name\n";
}
