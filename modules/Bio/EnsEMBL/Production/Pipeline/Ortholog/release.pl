=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

${ensembl_cvs_root_dir}/ensembl-production/modules/Bio/EnsEMBL/Production/Pipeline/Ortholog/release.pl

=head1 DESCRIPTION

Run this script post DumpOrthologs pipeline to create
a release.txt timestamp file  

=head1 AUTHOR

ckong@ebi.ac.uk

=cut
use strict;
use warnings;
use Cwd;
use Fcntl qw( :mode );
use File::Spec;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use Bio::EnsEMBL::ApiVersion qw/software_version/;

my $DEFAULT_USER = 'ensgen';
my $OPTIONS      = options();

run();

sub options {
    my $opts = {};
    my @flags = qw(directory|d=s replace ignore_user help man );
    GetOptions($opts, @flags) or pod2usage(1);
  
    _exit( undef, 0, 1) if $opts->{help};
    _exit( undef, 0, 2) if $opts->{man};
    _exit('No -directory given. The location of the orthologs dump files', 1, 1) unless $opts->{directory};
    print STDERR "\t-replace option is on, release.txt timestamp file will be replaced if exists\n" if $opts->{replace};	  

    $opts->{directory} = File::Spec->rel2abs($opts->{directory});
      
    if($opts->{ignore_user}) {
      print STDERR "\t-ignore_user option is on, ignoring that user should be $DEFAULT_USER. I hope you know what you're doing\n";
    }
    else {
      if($ENV{USER} ne $DEFAULT_USER) {
      _exit('You are not ensgen; either become ensgen & rerun this command or give -ignore_user to the script.', 1, 1);
    }
   }
  
  return $opts;
}

sub _exit {
    my ($msg, $status, $verbose) = @_;
    print STDERR $msg, "\n" if defined $msg;
    pod2usage( -exitstatus => $status, -verbose => $verbose );
}

sub run {
  my $dirs  = get_dirs();
  my $release = software_version();

  foreach my $dir (@{$dirs}) {
    print STDERR "Processing $dir\n";
    my $contents = get_contents($dir);
    my $release_file = File::Spec->catfile($dir, 'release.txt');
    # Remove existing release.txt timestamp file
    # if -replace option provided
    if(-f $release_file) {
      return if ! $OPTIONS->{replace};
      print STDERR "Removing existing $release_file timestamp file\n";
      unlink $release_file;
    }

    open my $fh, '>', $release_file or die "Cannot open $release_file for writing: $!";
  
    print STDERR "Generating timestamp\n";
    my $timestamp = getLoggingTime($dir.'/'.$contents->{files}->[0]);
    $dir = $1 if($dir =~/(ensembl\w*)$/);
    print $fh "$dir\t$release\t$timestamp\n";

    close $fh or die "Cannot close $release_file: $!";
    print STDERR "Processing $dir Complete\n";
  }

return;
}

sub get_dirs {
    my $base_dir = $OPTIONS->{directory};
    my $output   = `find ${base_dir}/* -type d`;
    my @dirs     = map { chomp $_; $_ } split /\n/, $output;

return \@dirs;
}

sub get_contents {
    my ($dir) = @_;
    
    my $output = { dirs => [], files => [] };
    my $cwd    = cwd();
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

sub getLoggingTime {
  my ($file) = @_;
  my $mtime = (stat ($file))[9];
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($mtime);
  my $nice_timestamp = sprintf ( "%04d/%02d/%02d %02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
return $nice_timestamp;
}

__END__
=pod

=head1 NAME

release.pl

=head1 SYNOPSIS

  ./release.pl -directory /nfs/ftp/pub/databases/ensembl/projections

  ./release.pl -ignore_user -directory /nfs/ftp/pub/databases/ensembl/projections
  
  ./release.pl -replace -ignore_user -directory /nfs/ftp/pub/databases/ensembl/projections
    
=head1 DESCRIPTION


=head1 OPTIONS

=over 8

=item B<--directory>

Base directory where the orthologs dump files are located 

=item B<--ignore_user>

By default this program should be run as ensgen; giving this option turns
that check off. 

=item B<--replace>

Replace the release.txt timestamp file if it exists

=item B<--help>

Prints this help

=item B<--man>

Prints this manual

=back

=cut
