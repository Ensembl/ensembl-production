#!/usr/bin/env perl

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

create_release_file.pl

=head1 DESCRIPTION

Run this script to create a release.txt timestamp file  

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

use Bio::EnsEMBL::Production::Pipeline::Common::CreateReleaseFile
  qw/create_release_file/;
use Log::Log4perl qw(:easy);
my $DEFAULT_USER = 'ensgen';
my $OPTIONS      = options();

Log::Log4perl->easy_init($INFO);

run();

sub options {
	my $opts  = {};
	my @flags = qw(directory|d=s version|v=s help man );
	GetOptions( $opts, @flags ) or pod2usage(1);

	_exit( undef, 0, 1 ) if $opts->{help};
	_exit( undef, 0, 2 ) if $opts->{man};
	_exit( 'No -directory given. The location of the orthologs dump files',
		   1, 1 )
	  unless $opts->{directory};

	my $logger = get_logger();

	$logger->warn(
"replace option is on, release.txt timestamp file will be replaced if exists"
	) if $opts->{replace};

	$opts->{directory} = File::Spec->rel2abs( $opts->{directory} );

	return $opts;
} ## end sub options

sub _exit {
	my ( $msg, $status, $verbose ) = @_;
	print STDERR $msg, "\n" if defined $msg;
	pod2usage( -exitstatus => $status, -verbose => $verbose );
}

sub run {
	create_release_file( $OPTIONS->{directory}, $OPTIONS->{version} );
	return;
}

__END__
=pod

=head1 NAME

release.pl

=head1 SYNOPSIS

  ./create_release_file.pl -directory /nfs/ftp/pub/databases/ensembl/projections
  ./create_release_file.pl -directory /nfs/ftp/pub/databases/ensembl/projections -version 35

    
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
