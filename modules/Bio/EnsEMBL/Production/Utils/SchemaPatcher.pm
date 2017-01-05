#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::Production::Utils::SchemaPatcher;

use strict;
use warnings;

use Exporter qw/import/;
our @EXPORT_OK = qw(apply_patch find_missing_patches list_patch_files);
use File::Slurp qw/read_file/;
use File::Basename;
use Carp;
use Log::Log4perl qw/get_logger/;

my $logger = get_logger();

sub list_patch_files {
  my ($patch_dir) = @_;
  opendir(my $dh, $patch_dir) || die "can't opendir $patch_dir: $!";
  my @patch_files = map {$patch_dir."/".$_} grep { /patch.*.sql/ } readdir($dh);
  closedir $dh;
  return \@patch_files;
}

sub find_db_patches {
  my ($dbh, $db_name) = @_;
  # read patches from meta into a hash
  my $existing_patches = {};
  $dbh->do("use $db_name");
  my $sth = $dbh->prepare(q/select meta_value from meta where meta_key='patch'/);
  $sth->execute();
  while (my $row = $sth->fetchrow_arrayref()) {
    next unless defined $row;
    my $patch = $row->[0];
    my ($patch_file) = split('\|', $patch);
    $existing_patches->{$patch_file} = $patch;
  }
  $sth->finish();
  return $existing_patches;
}


sub find_missing_patches {
  my ($dbh, $db_name, $all_patches, $release) = @_;
  if(defined $release) {
    my $last_release = $release - 1;
    $all_patches = [grep {m/patch_${last_release}_${release}_*[a-z]+.sql/} @$all_patches];
  }
  # read patches from meta into a hash
  my $existing_patches = find_db_patches($dbh, $db_name);
  my $missing_patches = [];
  for my $patch (@{$all_patches}) {
    my $patch_file = basename($patch);
    if(!defined $existing_patches->{$patch_file}) {
      push @$missing_patches, $patch;
    }
  }
  return [sort @$missing_patches];
}

sub apply_patch {
  my ($dbh, $db_name, $patch_file) = @_;
  $logger->info("Applying $patch_file to $db_name");
  my $lines = join ' ', grep {$_ !~ m/^#/ && $_ !~ m/^--/} read_file($patch_file);
  $dbh->do("use $db_name") || croak "Cannot use $db_name";
  for my $line (split ';', $lines) {
    $line =~ s/^\s*(.*)\s*$/$1/sg;
    next unless defined $line && $line ne '';
    $logger->debug("Applying $line");
    $dbh->do($line) || croak "Could not apply SQL $line on $db_name";
  }
  return;
}

1;
