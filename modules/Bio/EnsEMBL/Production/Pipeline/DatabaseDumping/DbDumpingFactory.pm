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

sub run {
  my ($self) = @_;
  my $division = $self->param('division');
  my $database = $self->param('database');
  my $release = $self->param('release');
  my $base_output_dir = $self->param('base_output_dir');

  #Connect to the metadata database
  my $dba = Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(
          -USER=>$self->param('meta_user'),
          -HOST=> $self->param('meta_host'),
          -PORT=>$self->param('meta_port'),
          -DBNAME=>$self->param('meta_database'),
  );
  #Get metadata adaptors
  my $gcdba = $dba->get_GenomeComparaInfoAdaptor();
  my $gdba = $dba->get_GenomeInfoAdaptor();
  my $dbdba = $dba->get_DatabaseInfoAdaptor();
  my $rdba = $dba->get_DataReleaseInfoAdaptor();
  #set release by querying the metadata db
  my $release_info;
  my $release_dir;
  $release_info = $rdba->fetch_by_ensembl_genomes_release($release);
  if (!$release_info){
    $release_info = $rdba->fetch_by_ensembl_release($release);
    $release_dir = $release_info->{ensembl_version};
  }
  else{
    $release_dir = $release_info->{ensembl_genomes_version};
  }
  $gdba->data_release($release_info);

  # Either dump databases from databases array or loop through divisions
  if (@$database) {
    #Dump given databases
    foreach my $db (@$database){
      if (scalar @$division > 1) {
        die "Please run a separare pipeline for each divisions";
      }
      my ($division_short_name,$division_name)=process_division_names($division->[0]);
      $self->dataflow_output_id({
                  database=>$db,
                  output_dir => $base_output_dir.$division_short_name.'/release-'.$release_dir.'/mysql/',
                  }, 1);
    }
  }
  else{
    #Foreach divisions, get all the genomes and then databases associated.
    # Get the compara databases and other databases like mart
    foreach my $div (@$division){
      my ($division_short_name,$division_name)=process_division_names($div);
      my $division_databases;
      my $genomes = $gdba->fetch_all_by_division($division_name);
      #Genome databases
      foreach my $genome (@$genomes){
        foreach my $database (@{$genome->databases()}){
          push (@$division_databases,$database->dbname);
        }
      }
      #release and mart databases
      foreach my $release_database (@{$dbdba->fetch_databases_DataReleaseInfo($release_info,$division_name)}){
        if ($division_short_name eq "pan"){
          if (check_if_db_exists($self,$release_database)){
            push (@$division_databases,$release_database->dbname);
      }
          else{
            $self->warning("Can't find ".$release_database->dbname." on server: ".$self->param('host'));
      }
        }
        else{
          push (@$division_databases,$release_database->dbname);
      }
      }
      #compara databases
      foreach my $compara_database (@{$gcdba->fetch_division_databases($division_name,$release_info)}){
        push (@$division_databases,$compara_database);
      }
      foreach my $division_database (uniq(@$division_databases)){
          $self->dataflow_output_id({
          database=>$division_database,
          output_dir => $base_output_dir.$division_short_name.'/release-'.$release_dir.'/mysql/',
          }, 1);
      }
    }
  }
}
# Check if a database exist on the mysql server
sub check_if_db_exists {
  my ($self,$database_name)=@_;
  my $database=$database_name->dbname;
  my $host = $self->param('host');
  my $port = $self->param('port');
  my $pass = $self->param('password');
  my $user = $self->param('user');
  return `mysql -ss -r --host=$host --port=$port --user=$user --password=$pass -e "show databases like '$database'"`;
}

#Process the division name, and return both division like metazoa and division name like EnsemblMetazoa
sub process_division_names {
  my ($div) = @_;
  my $division;
  my $division_name;
  #Creating the Division name EnsemblBla and division bla variables
  if ($div !~ m/[E|e]nsembl/){
    $division = $div;
    $division_name = 'Ensembl'.ucfirst($div) if defined $div;
  }
  else{
    $division_name = $div;
    $division = $div;
    $division =~ s/Ensembl//;
    $division = lc($division);
  }
  return ($division,$division_name)
}
1;
