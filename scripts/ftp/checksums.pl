#!/usr/bin/env perl
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

use strict;
use warnings;

my $DEFAULT_USER = 'ensgen';

use Cwd;
use Fcntl qw( :mode );
use File::Spec;
use Getopt::Long;
use Pod::Usage;

my $OPTIONS = options();
run();

sub options {
  my $opts = {};
  my @flags = qw(
    directory=s replace ignore_user help man
  );
  GetOptions($opts, @flags) or pod2usage(1);

  _exit( undef, 0, 1) if $opts->{help};
        _exit( undef, 0, 2) if $opts->{man};

        _exit('No -directory given. Need somewhere to start scanning from', 1, 1) unless $opts->{directory};

  $opts->{directory} = File::Spec->rel2abs($opts->{directory});

  print STDERR "Replace is on; will re-calculate all checksums\n" if $opts->{replace};

  if($opts->{ignore_user}) {
    print STDERR "Ignoring that our user should be $DEFAULT_USER. I hope you know what you're doing\n";
  }
  else {
    if($ENV{USER} ne $DEFAULT_USER) {
      _exit('You are not ensgen; either become ensgen & rerun this command or give -ignore_user to the script.', 1, 1);
    }
  }

  return $opts;
}

sub run {
  my $dirs = get_dirs();
  foreach my $dir (@{$dirs}) {
    print STDERR "Processing $dir\n";
    my $contents = get_contents($dir);
    if(leaf_directory($contents)) {
      print STDERR "Directory is a leaf; will generate checksums\n";
      remove_checksums($dir, $contents);
      generate_checksums($dir, $contents);
    }
  }
  print STDERR "Done\n";
  return;
}

sub get_dirs {
  my $base_dir = $OPTIONS->{directory};
  my $output = `find $base_dir -type d`;
  my @dirs = map { chomp $_; $_ } split /\n/, $output;
  return \@dirs;
}

sub get_contents {
  my ($dir) = @_;

  my $output = {
    dirs => [],
    files => []
  };

  my $cwd = cwd();
  chdir($dir);

  opendir my $dh, $dir or die "Cannot open directory '$dir': $!";
  my @contents = readdir($dh);
  closedir $dh or die "Cannot close directory '$dir': $!";

  foreach my $c (@contents) {
    if(-f $c) {
      push(@{$output->{files}}, $c);
    }
    elsif($c eq '.' || $c eq '..') {
      next;
    }
    elsif(-d $c) {
      push(@{$output->{dirs}}, $c);
    }
    else {
      #Don't know what type this is ... symbolic link?
    }
  }

  chdir($cwd);
  return $output;
}

sub remove_checksums {
  my ($dir, $contents) = @_;
  remove_file($dir, 'CHECKSUMS');
  remove_file($dir, 'MD5SUM');
  my @filtered_files =
    grep { $_ ne 'CHECKSUMS' } grep { $_ ne 'MD5SUM' } @{$contents->{files}};
  $contents->{files} = \@filtered_files;
  return;
}

sub remove_file {
  my ($dir, $file) = @_;
  return if ! $OPTIONS->{replace};
  my $target = File::Spec->catfile($dir, $file);
  if(-f $target) {
    unlink $target;
  }
  return;
}

sub leaf_directory {
  my ($contents) = @_;
  return (scalar(@{$contents->{dirs}}) == 0) ? 1 : 0;
}

sub generate_checksums {
  my ($dir, $contents) = @_;
  my $files = $contents->{files};
  return if scalar(@{$files}) == 0;
  my $checksum_file = File::Spec->catfile($dir, 'CHECKSUMS');
  if(-f $checksum_file) {
    print STDERR "Skipping the checksum file $checksum_file as it exists\n";
  }
  open my $fh, '>', $checksum_file or die "Cannot open $checksum_file for writing: $!";
  foreach my $file (sort {$a cmp $b} @{$files}) {
    my $target = File::Spec->catfile($dir, $file);
    next if ! -f $target; # skip if the file was removed
    my $checksum = `sum $target`;
    chomp($checksum);
    print $fh "$checksum $file\n";
  }
  close $fh or die "Cannot close $checksum_file: $!";

  chmod S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH, $checksum_file;

  print STDERR "Finished writing the checksum file $checksum_file\n";
  return;
}

sub _exit {
  my ($msg, $status, $verbose) = @_;
  print STDERR $msg, "\n" if defined $msg;
  pod2usage( -exitstatus => $status, -verbose => $verbose );
}

__END__
=pod

=head1 NAME

checksums.pl

=head1 SYNOPSIS

  ./checksums.pl -directory /nfs/ensemblgenomes/ftp/pub/.release-10

  ./checksums.pl -directory /nfs/ensemblgenomes/ftp/pub/.release-10 -replace

=head1 DESCRIPTION

Formalisation of the checksum procedure which iterates through all
sub-directories from the specified location and creates checksums for
all leaf directories.

=head1 OPTIONS

=over 8

=item B<--directory>

Base directory to start the search from

=item B<--replace>

Forces re-calculation of all checksums

=item B<--ignore_user>

By default this program should be run as ensgen; giving this option turns
that check off. Do so at your own peril (all files on FTP have to be
owned by ensgen & writable ONLY by ensgen)

=item B<--help>

Prints this help

=item B<--man>

Prints this manual

=back

=cut
