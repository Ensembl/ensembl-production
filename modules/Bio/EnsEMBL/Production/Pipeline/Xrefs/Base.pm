=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::Base;

use strict;
use warnings;
use DBI;
use Net::FTP;
use HTTP::Tiny;
use URI;
use URI::file;
use File::Basename;
use File::Spec::Functions;
use File::Path qw/make_path/;
use XrefParser::BaseParser;
use IO::File;
use JSON;
use Bio::EnsEMBL::Hive::Utils::URL;
use Bio::EnsEMBL::DBSQL::DBConnection;
use Text::Glob qw( match_glob );
use File::Copy qw(copy);
use LWP::Simple;
use Bio::EnsEMBL::Utils::IO qw/slurp/;
use Bio::EnsEMBL::Utils::URI qw(parse_uri);

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub parse_config {
  my ($self, $file) = @_;
  my $contents = slurp($file);
  my $sources = from_json($contents);
  return $sources;
}

sub create_db {
  my ($self, $source_dir, $source_url, $reuse_db_if_present) = @_;
  my ($user, $pass, $host, $port, $source_db) = $self->parse_url($source_url);
  my $dbconn = sprintf( "dbi:mysql:host=%s;port=%s", $host, $port);
  my $dbh = DBI->connect( $dbconn, $user, $pass, {'RaiseError' => 1}) or croak( "Can't connect to server: " . $DBI::errstr );
  my %dbs = map {$_->[0] => 1} @{$dbh->selectall_arrayref('SHOW DATABASES')};
  return if $reuse_db_if_present and $dbs{$source_db};

  $dbh->do( "DROP DATABASE IF EXISTS $source_db" );
  $dbh->do( 'CREATE DATABASE ' . $source_db);
  my $table_file = catfile( $source_dir, 'table.sql' );
  my $cmd = "mysql -u $user -p'$pass' -P $port -h $host $source_db < $table_file";
  system($cmd);
}

sub download_file {
  my ($self, $file, $base_path, $source_name, $db, $extra_args) = @_;

  # Create uri object and get scheme
  my $uri = URI->new($file);
  if (!defined $uri->scheme) { return $file; }

  # Get extra parameters
  my $skip_download_if_file_present = $extra_args->{'skip_download_if_file_present'} || 0;
  my $release = $extra_args->{'release'} || undef;
  my $rel_number = $extra_args->{'rel_number'} || undef;
  my $catalog = $extra_args->{'catalog'} || undef;

  # Create file download path
  my $file_path;
  $source_name =~ s/\///g;
  my $dest_dir = catdir($base_path, $source_name);
  if (defined $db and $db eq 'checksum') {
    $dest_dir = catdir($base_path, 'Checksum');
  }
  make_path($dest_dir);

  # If file is in local ftp, copy from there
  if ($file =~ /ftp.ebi.ac.uk/) {
    # Construct local path
    my $local_file = $file;
    $local_file =~ s|http://ftp.ebi.ac.uk/pub/|/nfs/ftp/public/|;

    # Check if local file exists
    if (-e $local_file) {
      $file_path = catfile($dest_dir, basename($uri->path));
      if (defined $db and $db eq 'checksum') {
        $file_path = catfile($dest_dir, $source_name."-".basename($uri->path));
      }

      unless ($skip_download_if_file_present && -f $file_path) {
        copy $local_file, $file_path;

        # Check if copy was successful
        if (-e $file_path) {
          return $file_path if (defined $release);
          return dirname($file_path);
        }
      }
    }
  }

  if ($source_name =~ /RefSeq/ && defined($rel_number) && defined($catalog) && !defined($release)) {
    # Get current release number
    my $release_number = get($rel_number);
    $release_number =~ s/\n//g;
    if (!$release_number) {
      die "No release number in ".$rel_number;
    }

    # Get list of files in catalog
    my $list = get($catalog);
    $catalog =~ s/\*/$release_number/;
    my %refseq_files = map {(split /\n/)} split /\t/, $list;

    while (my ($checksum, $file_name) = each %refseq_files) {
      # Only interested in files matching pattern
      next if (!match_glob(basename($uri->path), $file_name));

      $file_path = catfile($dest_dir, basename($file_name));
      unless ($skip_download_if_file_present && -f $file_path) {
        my $http = HTTP::Tiny->new();
        my $response = $http->get(dirname($file)."/".$file_name);

        if ($response->{success}) {
          open OUT, ">$file_path" or die "Couldn't open file $file_path $!";
          print OUT $response->{content};
          close OUT;
        } else {
          die "Error in downloading file from ".dirname($file)."/".$file_name;
        }
      }
    }
  } elsif ($uri->scheme eq 'ftp') {
    my $ftp = ftp_connect($uri);
    my @remote_files = $ftp->ls();
    foreach my $remote_file ( @remote_files ) {
      if ( !match_glob( basename( $uri->path() ), $remote_file ) ) { next; }
      $remote_file =~ s/\///g;
      $file_path = catfile($dest_dir, basename($remote_file));
      if (defined $db and $db eq 'checksum') {
        $file_path = catfile($dest_dir, $source_name."-".basename($remote_file));
      }
      unless ($skip_download_if_file_present and -f $file_path) {
        if (!$ftp->get( $remote_file, $file_path )) {
          $ftp->quit;
          $ftp = ftp_connect($uri);
          $ftp->get( $remote_file, $file_path ) or die "Error in downloading ftp file from ".$uri->as_string();
        }
      }
    }
    $ftp->quit;
  } elsif ($uri->scheme eq 'http' || $uri->scheme eq 'https') {
    if ($source_name =~ /RefSeq/ && defined($rel_number) && defined($release)) {
      # Get current release number
      my $release_number = get($rel_number);
      $release_number =~ s/\n//g;
      if (!$release_number) {
        die "No release number in ".$rel_number;
      }

      $file =~ s/\*/$release_number/;
      $uri = URI->new($file);
    }

    $file_path = catfile($dest_dir, basename($uri->path));
    unless ($skip_download_if_file_present and -f $file_path) {
      if (defined $db and $db eq 'checksum') {
        $file_path = catfile($dest_dir, $source_name."-".basename($uri->path));
      }

      my $http = HTTP::Tiny->new();
      my $response = $http->get($uri->as_string());

      if ($response->{success}) {
        open OUT, ">$file_path" or die "Couldn't open file $file_path $!";
        print OUT $response->{content};
        close OUT;
      } else {
        die "Error in downloading file from ".$uri->as_string();
      }
    }
  }
  if (defined $release) {
    return $file_path;
  }
  return dirname($file_path);
  
}

sub ftp_connect {
  my ($uri) = @_;

  my $ftp = Net::FTP->new( $uri->host(), 'Debug' => 0);
  if (!defined($ftp) or ! $ftp->can('ls') or !$ftp->ls()) {
    $ftp = Net::FTP->new( $uri->host(), 'Debug' => 0);
  }

  $ftp->login( 'anonymous', '-anonymous@' );
  $ftp->cwd( dirname( $uri->path ) );
  $ftp->binary();

  return $ftp;
}

sub parse_url {
  my ($self, $url) = @_;
  my $parsed_url = Bio::EnsEMBL::Hive::Utils::URL::parse($url);
  my $user = $parsed_url->{'user'};
  my $pass = $parsed_url->{'pass'};
  my $host = $parsed_url->{'host'};
  my $port = $parsed_url->{'port'};
  my $db   = $parsed_url->{'dbname'};
  return ($user, $pass, $host, $port, $db);
}

sub load_checksum {
  my ($self, $path, $dbi) = @_;
  my $load_checksum_sth = $dbi->prepare("load data local infile ? into table checksum_xref");
  my $checksum_dir = catdir($path, 'Checksum');
  make_path($checksum_dir);
  my $counter = 1;
  my $source_id = 1;

  my @files = `ls $checksum_dir`;
  my $checksum_file = catfile($checksum_dir, 'checksum.txt');
  my $output_fh = IO::File->new($checksum_file, 'w');
  foreach my $file (@files) {
    $file =~ s/\n//;
    if ($file =~ /checksum/) { next; }
    my $input_file = catfile($checksum_dir, $file);
    $input_file =~ /\/([A-Za-z]*)-.*$/;
    my $source_name = $1;
    $source_id = $self->get_source_id_from_name($dbi, $source_name);
    my $input_fh = XrefParser::BaseParser->get_filehandle($input_file);
    while(my $line = <$input_fh>) {
      chomp $line;
      my ($id, $checksum) = split(/\s+/, $line);
      my @output = ($counter++, $source_id, $id, $checksum);
      print $output_fh join("\t", @output);
      print $output_fh "\n";
    }
    close $input_fh;
  }
  close $output_fh;

  $load_checksum_sth->execute($checksum_file);
  $load_checksum_sth->finish();

}

sub get_source_id_from_name {
  my ($self, $dbi, $source_name) = @_;
  my $select_source_id_sth = $dbi->prepare("SELECT source_id FROM source WHERE name = ?");
  $select_source_id_sth->execute($source_name);
  my $source_id = ($select_source_id_sth->fetchrow_array());
  $select_source_id_sth->finish();
  return $source_id;
}

sub get_source_id {
  my ($self, $dbi, $parser, $species_id, $name, $division_id) = @_;
  $name = "%$name%";
  my $source_id;
  my $select_source_id_sth = $dbi->prepare("SELECT u.source_id FROM source_url u, source s WHERE s.source_id = u.source_id AND parser = ? and species_id = ?");
  my $select_count_source_id_sth = $dbi->prepare("SELECT count(*) FROM source_url u, source s WHERE s.source_id = u.source_id AND parser = ? AND species_id = ?");
  $select_count_source_id_sth->execute($parser, $species_id);
  my $count = ($select_count_source_id_sth->fetchrow_array());
  if ($count == 1) { 
    $select_source_id_sth->execute($parser, $species_id);
    $source_id = ($select_source_id_sth->fetchrow_array());
  }
  $select_source_id_sth = $dbi->prepare("SELECT u.source_id FROM source_url u, source s WHERE s.source_id = u.source_id AND parser = ? and species_id = ? and name like ?");
  $select_count_source_id_sth = $dbi->prepare("SELECT count(*) FROM source_url u, source s WHERE s.source_id = u.source_id AND parser = ? AND species_id = ? AND name like ?");
  $select_count_source_id_sth->execute($parser, $species_id, $name);
  $count = ($select_count_source_id_sth->fetchrow_array());
  if ($count == 1) {
    $select_source_id_sth->execute($parser, $species_id, $name);
    $source_id = ($select_source_id_sth->fetchrow_array());
  }
  # If no species-specific source, look for common sources
  if (!defined $source_id) {
    $select_source_id_sth->execute($parser, $division_id, $name);
    $source_id = ($select_source_id_sth->fetchrow_array())[0];
  }
  $select_source_id_sth->finish();
  $select_count_source_id_sth->finish();
  return $source_id;
}

sub get_dbi {
  my ($self, $host, $port, $user, $pass, $dbname) = @_;
  my $dbconn;
  if (defined $dbname) {
    $dbconn = sprintf("dbi:mysql:host=%s;port=%s;database=%s", $host, $port, $dbname);
  } else {
    $dbconn = sprintf("dbi:mysql:host=%s;port=%s", $host, $port);
  }
  my $dbi = DBI->connect( $dbconn, $user, $pass, { 'RaiseError' => 1 } ) or croak( "Can't connect to database: " . $DBI::errstr );
  return $dbi;
}

sub get_dbc {
  my ($self, $host, $port, $user, $pass, $dbname) = @_;
  my $dbconn = Bio::EnsEMBL::DBSQL::DBConnection->new(
        -HOST   => $host,
        -DBNAME => $dbname,
        -USER   => $user,
        -PASS   => $pass,
        -PORT   => $port);
  return $dbconn;
}

sub get_path {
  my ($self, $base_path, $species, $release, $category, $file_name) = @_;
  my $full_path = File::Spec->catfile($base_path, $species, $release, $category);
  make_path($full_path);
  if (defined $file_name) {
    return File::Spec->catfile($full_path, $file_name);
  } else {
    return $full_path;
  }
}

sub get_xref_mapper {
  my ($self, $xref_url, $species, $base_path, $release) = @_;
  my ($user, $pass, $host, $port, $dbname) = $self->parse_url($xref_url);

  my $registry = 'Bio::EnsEMBL::Registry';
  my $core_adaptor = $registry->get_DBAdaptor($species, 'Core');
  my $core_dbc = $core_adaptor->dbc;
  $core_dbc->disconnect_if_idle();
  my $core_db = XrefMapper::db->new(
    -host    => $core_dbc->host,
    -dbname  => $core_dbc->dbname,
    -port    => $core_dbc->port,
    -user    => $core_dbc->user,
    -pass    => $core_dbc->pass,
    -disconnect_if_idle => 1
  );
  $core_db->dir("$base_path/$species");
  $core_db->species($species);
  my $cdna_path = $self->get_path($base_path, $species, $release, "ensembl", 'transcripts.fa');
  my $pep_path = $self->get_path($base_path, $species, $release, "ensembl", 'peptides.fa');
  $core_db->dna_file($cdna_path);
  $core_db->protein_file($pep_path);

  my $xref_db = XrefMapper::db->new(
    -host    => $host,
    -dbname  => $dbname,
    -port    => $port,
    -user    => $user,
    -pass    => $pass,
    -disconnect_if_idle => 1
  );

  # Look for species-specific mapper
  my $module = 'XrefMapper::BasicMapper';;
  my $class = "XrefMapper/$species.pm";
  my $eval_test = eval { require $class; };
  if (defined $eval_test) {
    $module = "XrefMapper::$species" if $eval_test == 1;
  }

  my $mapper = $module->new();
  $mapper->xref($xref_db);
  $mapper->add_meta_pair("xref", $host.":".$dbname);
  $mapper->core($core_db);
  $mapper->add_meta_pair("species", $host.":".$dbname);

  return $mapper;
}

sub get_taxon_id {
  my $self = shift;
  my $species = shift;
  my $registry = 'Bio::EnsEMBL::Registry';
  my $meta_container = $registry->get_adaptor($species,'core', 'MetaContainer');
  my $species_id = $meta_container->get_taxonomy_id();

  return $species_id;
}

sub get_division_id {
  my $self = shift;
  my $species = shift;
  my $registry = 'Bio::EnsEMBL::Registry';
  my $meta_container = $registry->get_adaptor($species,'core', 'MetaContainer');
  my $division = $meta_container->get_division();
  my %division_taxon = (
    'Ensembl'            => 7742,
    'EnsemblVertebrates' => 7742,
    'Vertebrates'        => 7742,
    'EnsemblMetazoa'     => 33208,
    'Metazoa'            => 33208,
    'Plants'             => 33090,
    'EnsemblPlants'      => 33090,
  );
  my $division_id = $division_taxon{$division};
  return $division_id;
}


1;

