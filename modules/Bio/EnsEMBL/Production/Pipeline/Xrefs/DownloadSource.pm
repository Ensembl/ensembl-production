=head1 LICENSE

Copyright [2009-2015] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::DownloadSource;

use strict;
use warnings;
use DBI;
use URI;
use Net::FTP;
use HTTP::Tiny;
use URI;
use URI::file;
use File::Basename;
use File::Spec::Functions;
use XrefParser::Database;
use IO::File;
use Bio::EnsEMBL::Hive::Utils::URL;
use Text::Glob qw( match_glob );

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub run {
  my ($self) = @_;
  my $base_path        = $self->param_required('base_path');
  my $config_file      = $self->param_required('config_file');
  my $source_dir       = $self->param_required('source_dir');
  my $reuse_db         = $self->param_required('reuse_db');
  my $skip_download    = $self->param_required('skip_download');

  my $user             = $self->param_required('source_user');
  my $pass             = $self->param_required('source_pass');
  my $db_url           = $self->param('source_url');
  my $source_db        = $self->param('source_db');
  my $host             = $self->param('source_host');
  my $port             = $self->param('source_port');

  if (defined $db_url) {
    my $parsed_url = Bio::EnsEMBL::Hive::Utils::URL::parse($db_url);
    $user      = $parsed_url->{'user'};
    $pass      = $parsed_url->{'pass'};
    $host      = $parsed_url->{'host'};
    $port      = $parsed_url->{'port'};
    $source_db = $parsed_url->{'dbname'};
  }
  $self->create_db($source_dir, $user, $pass, $db_url, $source_db, $host, $port) unless $reuse_db;

  my $dbconn = sprintf( "dbi:mysql:host=%s;port=%s;database=%s", $host, $port, $source_db);
  my $dbi = DBI->connect( $dbconn, $user, $pass, { 'RaiseError' => 1 } ) or croak( "Can't connect to database: " . $DBI::errstr );
  my $insert_source_sth = $dbi->prepare("INSERT IGNORE INTO source (name, parser) VALUES (?, ?)");
  my $insert_version_sth = $dbi->prepare("INSERT INTO version (source_id, uri, file_name, count_seen) VALUES ((SELECT source_id FROM source WHERE name = ?), ?, ?, 1)");

  # Can re-use existing files if specified
  if ($skip_download) { return; }

  open( INFILE, "<$config_file" ) or die("Can't read $config_file $! \n");
  while ( my $line = <INFILE> ) {
    chomp $line;
    my ($name, $parser, $file) = split( /\t/, $line );
    my $file_name = $self->download_file($file, $base_path, $name);
    $insert_source_sth->execute($name, $parser);
    $insert_version_sth->execute($name, $file, $file_name);
  }
  close INFILE;

}

sub create_db {
  my ($self, $source_dir, $user, $pass, $db_url, $source_db, $host, $port) = @_;
  my $dbconn = sprintf( "dbi:mysql:host=%s;port=%s", $host, $port);
  my $dbh = DBI->connect( $dbconn, $user, $pass, {'RaiseError' => 1}) or croak( "Can't connect to server: " . $DBI::errstr );
  my %dbs = map {$_->[0] => 1} @{$dbh->selectall_arrayref('SHOW DATABASES')};
  if ($dbs{$source_db}) {
    $dbh->do( "DROP DATABASE $source_db" );
  }
  $dbh->do( 'CREATE DATABASE ' . $source_db);
  my $table_file = catfile( $source_dir, 'table.sql' );
  my $cmd = "mysql -u $user -p'$pass' -P 4524 -h mysql-ens-core-prod-1 $source_db < $table_file";
  system($cmd);
}

sub download_file {
  my ($self, $file, $base_path, $source_name) = @_;

  my $uri = URI->new($file);
  if (!defined $uri->scheme) { return; }
  my $file_path;
  $source_name =~ s/\///g;
  my $dest_dir = catdir($base_path, $source_name);

  if ($uri->scheme eq 'ftp') {
    my $ftp = Net::FTP->new( $uri->host(), 'Debug' => 0);
    if (!defined($ftp) or ! $ftp->can('ls') or !$ftp->ls()) {
      $ftp = Net::FTP->new( $uri->host(), 'Debug' => 0);
    }
    $ftp->login( 'anonymous', '-anonymous@' ); 
    $ftp->cwd( dirname( $uri->path ) );
    $ftp->binary();
    foreach my $remote_file ( ( @{ $ftp->ls() } ) ) {
      if ( !match_glob( basename( $uri->path() ), $remote_file ) ) { next; }
      $remote_file =~ s/\///g;
      $file_path = catfile($dest_dir, basename($remote_file));
      mkdir(dirname($file_path));
      $ftp->get( $remote_file, $file_path );
    }
  } elsif ($uri->scheme eq 'http') {
    $file_path = catfile($dest_dir, basename($uri->path));
    mkdir(dirname($file_path));
    open OUT, ">$file_path" or die "Couldn't open file $file_path $!";
    my $http = HTTP::Tiny->new();
    my $response = $http->get($uri->as_string());
    print OUT $response->{content};
    close OUT;
  }
  return $file_path;
  
}


1;

