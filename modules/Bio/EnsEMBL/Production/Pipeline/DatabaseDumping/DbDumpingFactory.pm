=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::DatabaseDumping::DbFactory;

=head1 DESCRIPTION

The factory will use the metadata database to find databases for a given division and dataflow
The database names and dumping location.
If databases array is defined, the module will flow these databases directly without checks.
Please note that you can only dump databases directly for one division. The metadata database won't be checked for this.

=cut

package Bio::EnsEMBL::Production::Pipeline::DatabaseDumping::DbDumpingFactory;

use base ('Bio::EnsEMBL::Hive::Process');
use strict;
use warnings;
use DBI;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use List::MoreUtils qw(uniq);
use Bio::EnsEMBL::MetaData::Base qw(process_division_names fetch_and_set_release);

sub run {
  my ($self) = @_;
  my $division = $self->param_required('division');
  my $database = $self->param('database');
  my $release = $self->param('release');
  my $base_output_dir = $self->param('base_output_dir');
  my $isGrch37 = $self->param('isGrch37');

  #Connect to the metadata database
  my $dba = Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(
      -USER   => $self->param('meta_user'),
      -HOST   => $self->param('meta_host'),
      -PORT   => $self->param('meta_port'),
      -DBNAME => $self->param('meta_database'),
  );
  #Get metadata adaptors
  my $gcdba = $dba->get_GenomeComparaInfoAdaptor();
  my $gdba = $dba->get_GenomeInfoAdaptor();
  my $dbdba = $dba->get_DatabaseInfoAdaptor();
  my $rdba = $dba->get_DataReleaseInfoAdaptor();
  #Get and set release
  my ($release_num, $release_info);
  ($rdba, $gdba, $release_num, $release_info) = fetch_and_set_release($release, $rdba, $gdba);

  # Either dump databases from databases array or loop through divisions
  if (@$database) {
    #Dump given databases
    foreach my $db (@$database) {
      if (scalar @$division > 1) {
        die "Please run a separate pipeline for each divisions";
      }
      my ($division_short_name, $division_name) = process_division_names($division->[0]);
      my $dir_release = directory_release($division_short_name, $release_info);
      if ($isGrch37 == 1) {
        $self->dataflow_output_id({
            database   => $db,
            output_dir => $base_output_dir . '/grch37/release-' . $dir_release . '/mysql/',
        }, 1);
      }
      elsif ($division_short_name eq "pan") {
          $self->dataflow_output_id({
              database   => $db,
              output_dir => $base_output_dir . '/release-' . $dir_release . '/' . 'pan_ensembl' . '/mysql/',
          }, 1);
      }
      else {
        $self->dataflow_output_id({
            database   => $db,
            output_dir => $base_output_dir . '/release-' . $dir_release . '/' . $division_short_name . '/mysql/',
        }, 1);
      }
    }
  }
  else {
    #Foreach divisions, get all the genomes and then databases associated.
    # Get the compara databases and other databases like mart
    foreach my $div (@$division) {
      my ($division_short_name, $division_name) = process_division_names($div);
      my $division_databases;
      my $genomes = $gdba->fetch_all_by_division($division_name);
      my $dir_release = directory_release($division_short_name, $release_info);
      #Genome databases
      foreach my $genome (@$genomes) {
        foreach my $database (@{$genome->databases()}) {
          push(@$division_databases, $database->dbname);
        }
      }
      #release and mart databases
      foreach my $release_database (@{$dbdba->fetch_databases_DataReleaseInfo($release_info, $division_name)}) {
        if ($division_short_name eq "pan") {
          if (check_if_db_exists($self, $release_database)) {
            push(@$division_databases, $release_database->dbname);
          }
          else {
            $self->warning("Can't find " . $release_database->dbname . " on server: " . $self->param('host'));
          }
        }
        else {
          push(@$division_databases, $release_database->dbname);
        }
      }
      # For vertebrates, we want the pan databases in the same directory
      if ($division_short_name eq "vertebrates") {
        foreach my $release_database (@{$dbdba->fetch_databases_DataReleaseInfo($release_info, "EnsemblPan")}) {
          if (check_if_db_exists($self, $release_database)) {
            push(@$division_databases, $release_database->dbname);
          }
          else {
            $self->warning("Can't find " . $release_database->dbname . " on server: " . $self->param('host'));
          }
        }
      }
      #compara databases
      foreach my $compara_database (@{$gcdba->fetch_division_databases($division_name, $release_info)}) {
        push(@$division_databases, $compara_database);
      }
      foreach my $division_database (uniq(@$division_databases)) {
        if ($isGrch37 == 1) {
          $self->dataflow_output_id({
              database   => $division_database,
              output_dir => $base_output_dir . '/grch37/release-' . $dir_release . '/mysql/',
          }, 1);

        }
        elsif ($division_short_name eq "pan") {
          $self->dataflow_output_id({
              database   => $division_database,
              output_dir => $base_output_dir . '/release-' . $dir_release . '/' . 'pan_ensembl' . '/mysql/',
          }, 1);
        }
        else {
          $self->dataflow_output_id({
              database   => $division_database,
              output_dir => $base_output_dir . '/release-' . $dir_release . '/' . $division_short_name . '/mysql/',
          }, 1);
        }
      }
    }
  }
}
# Check if a database exist on the mysql server
sub check_if_db_exists {
  my ($self, $database_name) = @_;
  my $database = $database_name->dbname;
  my $host = $self->param('host');
  my $port = $self->param('port');
  my $pass = $self->param('password');
  my $user = $self->param('user');
  return `mysql -ss -r --host=$host --port=$port --user=$user --password=$pass -e "show databases like '$database'"`;
}

# Get the directory release number for each division
# E.g 97 for vertebrates and 44 for non-vertebrates
sub directory_release {
  my ($division, $release) = @_;
  my $dir_release;
  if ($division eq 'vertebrates') {
    $dir_release = $release->ensembl_version;
  }
  else {
    $dir_release = $release->ensembl_genomes_version;
  }
  return $dir_release;
}

1;
