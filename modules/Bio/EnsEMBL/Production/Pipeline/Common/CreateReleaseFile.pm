=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Pipeline::Ortholog::CreateReleaseFile

=head1 DESCRIPTION

Functionality to produce a post-release FTP dump file summary

=head1 AUTHOR

ckong@ebi.ac.uk

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::CreateReleaseFile;

use strict;
use warnings;
use Cwd;
use Fcntl qw( :mode );
use File::Spec;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use Carp qw/croak/;
use Bio::EnsEMBL::ApiVersion qw/software_version/;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(create_release_file); 

sub create_release_file {

	my ( $directory, $version ) = @_;
	
	$version ||= software_version();

	my $logger = get_logger();

	my $release_file = File::Spec->catfile( $directory, 'release.txt' );
	$logger->info("Creating $release_file");
	my $dirs = get_dirs($directory);

	# Remove existing release.txt timestamp file
	if ( -f $release_file ) {
	  $logger->info("Removing existing $release_file timestamp file");
	  unlink $release_file;
	}

	open my $fh, '>', $release_file or
	  croak "Cannot open $release_file for writing: $!";

	foreach my $dir ( @{$dirs} ) {
		$logger->info("Processing $dir");
		my $contents = get_contents($dir);

		if ( leaf_directory($contents) ) {
			$logger->info("Directory is a leaf; generating timestamp");
			my $timestamp = getLoggingTime();
			$dir = $1 if ( $dir =~ /(ensembl\w*)$/ );
			print $fh join("\t",$dir,$version,$timestamp)."\n";
		}
	}
	close $fh or croak "Cannot close $release_file: $!";
	$logger->info("Processing complete");

	return;
} ## end sub create_release_file

sub get_dirs {
	my ($base_dir) = @_;
	my $output = `find $base_dir -type d`;
	my @dirs = map { chomp $_; $_ } split /\n/, $output;

	return \@dirs;
}

sub get_contents {
	my ($dir) = @_;

	my $output = { dirs => [], files => [] };
	my $cwd = cwd();
	chdir($dir);

	opendir my $dh, $dir or croak "Cannot open directory '$dir': $!";
	my @contents = readdir($dh);
	closedir $dh or croak "Cannot close directory '$dir': $!";

	foreach my $c (@contents) {
		if ( -f $c ) {
			push( @{ $output->{files} }, $c );
		}
		elsif ( $c eq '.' || $c eq '..' ) {
			next;
		}
		elsif ( -d $c ) {
			push( @{ $output->{dirs} }, $c );
		}
		else {
			#Don't know what type this is ... symbolic link?
		}
	}

	chdir($cwd);

	return $output;
} ## end sub get_contents

sub leaf_directory {
	my ($contents) = @_;

	return ( scalar( @{ $contents->{dirs} } ) == 0 ) ? 1 : 0;
}

sub getLoggingTime {
	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
	  localtime(time);
	my $nice_timestamp = sprintf( "%04d/%02d/%02d %02d:%02d:%02d",
								  $year + 1900,
								  $mon + 1, $mday, $hour, $min, $sec );

	return $nice_timestamp;
}
