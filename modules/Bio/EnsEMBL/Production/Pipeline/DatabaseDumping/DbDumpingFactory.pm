=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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
  my $databases = $self->param('databases');
  my $vertebrates_release = $self->param('vertebrates_release');
  my $non_vertebrates_release = $self->param('non_vertebrates_release');
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
  my $release;
  my $release_dir;
  if ($non_vertebrates_release){
    $release = $rdba->fetch_by_ensembl_genomes_release($non_vertebrates_release);
    $release_dir = $non_vertebrates_release;
  }
  else{
    $release = $rdba->fetch_by_ensembl_release($vertebrates_release);
    $release_dir = $vertebrates_release;
  }
  $gdba->data_release($release);

  # Either dump databases from databases array or loop through divisions
  if (@$databases) {
    #Dump given databases
    foreach my $database (@$databases){
      if (scalar @$division > 1) {
        die "Please run a separare pipeline for each divisions";
      }
      $self->dataflow_output_id({
                  database=>$database,
                  output_dir => $base_output_dir.$division->[0].'/release-'.$release_dir.'/mysql/',
                  }, 1);
    }
  }
  else{
    #Foreach divisions, get all the genomes and then databases associated.
    # Get the compara databases and other databases like mart
    foreach my $div (@$division){
      my $division_databases;
      my $genomes = $gdba->fetch_all_by_division($div);
      #Genome databases
      foreach my $genome (@$genomes){
        foreach my $database (@{$genome->databases()}){
          push (@$division_databases,$database->dbname);
        }
      }
      #mart databases
      foreach my $mart_database (@{$dbdba->fetch_databases_DataReleaseInfo($release,$div)}){
        push (@$division_databases,$mart_database->dbname);
      }
      #compara databases
      foreach my $compara_database (@{$gcdba->fetch_division_databases($div,$release)}){
        push (@$division_databases,$compara_database);
      }
      foreach my $division_database (uniq(@$division_databases)){
          $self->dataflow_output_id({
          database=>$division_database,
          output_dir => $base_output_dir.$div.'/release-'.$release_dir.'/mysql/',
          }, 1);
      }
    }
  }
}
1;
