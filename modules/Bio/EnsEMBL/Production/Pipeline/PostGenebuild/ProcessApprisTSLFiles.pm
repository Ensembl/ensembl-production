=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::PostGenebuild::ProcessApprisTSLFiles

=head1 DESCRIPTION

Create working directory and APPRIS/TSL subdirectories
Copy the APPRIS and TSL files from their FTP site to the working directory location
Process the files per species, find the most recent file for each species
Connect to the metadata, get the species division and check that it matches with the pipeline
Then check that the assembly version match the file for APPRIS
Flow into load APPRIS and TSL analysis

=head1 Author

Thomas Maurel

=cut

package Bio::EnsEMBL::Production::Pipeline::PostGenebuild::ProcessApprisTSLFiles;

use strict;
use warnings;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use base('Bio::EnsEMBL::Production::Pipeline::Common::Base');
use Bio::EnsEMBL::MetaData::Base qw(process_division_names fetch_and_set_release);

sub run {
  my ($self) = @_;
  my $appris_ftp_base = $self->param_required('appris_ftp_base');
  my $tsl_ftp_base = $self->param_required('tsl_ftp_base');
  my $working_dir = $self->param_required('working_dir');
  my $release = $self->param_required('release');
  my $division = $self->param_required('division');
  my $appris_dir = $working_dir."/appris_".$release;
  my $tsl_dir = $working_dir."/TSL_".$release;
  
  # # #
  # Create working directories for APPRIS and TSL
  # # #
  $self->info('Creating working dir %s', $working_dir);
  if ( system("mkdir -p $working_dir") != 0 ) {
    die "Could not create working dir $working_dir";
  }
  $self->info('Creating APPRIS working dir %s', $appris_dir);
  if ( system("mkdir -p $appris_dir") != 0 ) {
    die "Could not create APPRIS working dir $appris_dir";
  }
  $self->info('Creating TSL working dir %s', $tsl_dir);
  if ( system("mkdir -p $tsl_dir") != 0 ) {
    die "Could not create TSL working dir $tsl_dir";
  }
  
  # # #
  # Fetch and process APPRIS FTP files
  # # #
  $self->info('Processing APPRIS FTP files');
  my $appris_species;
  $self->info('Copying files from directory %s to %s', $appris_ftp_base,$appris_dir);
  if ( system("wget -nd -r $appris_ftp_base -P $appris_dir -A txt") != 0 ) {
    die "Could not copy files from $appris_ftp_base to $appris_dir";
  }
  $self->info('Searching directory %s', $appris_dir);
  opendir(my $dh, $appris_dir) or die "Cannot open directory $appris_dir";
  # Sort file by release number
  foreach (sort { $self->get_rel_num($a) <=> $self->get_rel_num($b) } readdir($dh)) {
    next if $_ =~ /^\.\.?$/;
    my $species = (split /\./, $_)[0];
    $appris_species->{lc($species)} = $_;
  }
  closedir($dh) or die "Cannot close directory $appris_dir";
  
  # # #
  # Fetch and process TSL FTP files
  # # #
  $self->info('Processing TSL FTP files');
  my $tsl_species;
  $self->info('Copying and ungizipping files from directory %s to %s', $tsl_ftp_base,$tsl_dir);
  if ( system("wget -m -np -nd -e robots=off -r $tsl_ftp_base -P $tsl_dir -A tsv.gz;gunzip -f $tsl_dir/*.gz") != 0 ) {
    die "Could not copy files from $tsl_ftp_base to $tsl_dir";
  }
  $self->info('Searching directory %s', $tsl_dir);
  opendir(my $dh2, $tsl_dir) or die "Cannot open directory $tsl_dir";
  # Sort file by gencode version
  foreach (sort { $self->get_gencode_num($a) <=> $self->get_gencode_num($b) } readdir($dh2)) {
    next if $_ =~ /^\.\.?$/;
    my $gencode_version = (split /\./, $_)[1];
    if ($gencode_version =~ m/vM/){
      $tsl_species->{'mus_musculus'} = $_;
    }
    else{
      $tsl_species->{'homo_sapiens'} = $_;
    }
  }
  closedir($dh2) or die "Cannot close directory $tsl_dir";
  
  # # #
  # Connect and setup adaptor for the metadata database
  # # #
  my $metadatadba = Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(-USER => $self->param('muser'), -DBNAME=>$self->param('mdbname'), -HOST=>$self->param('mhost'), -PORT=>$self->param('mport'));
  #Create metadata adaptors
  my $gdba = $metadatadba->get_GenomeInfoAdaptor();
  my $dbdba = $metadatadba->get_DatabaseInfoAdaptor();
  my $rdba = $metadatadba->get_DataReleaseInfoAdaptor();
  # Get the release version
  my $release_info;
  ($rdba,$gdba,$release,$release_info) = fetch_and_set_release($release,$rdba,$gdba);

  # # #
  # Process APPRIS species and flow to loading analysis
  # # #
  while(my($species, $file) = each %{$appris_species}) {
    # Fetch genome info information from the metadata database
    my $genomeInfos = $gdba->fetch_by_name($species);
    foreach my $gen (@{$genomeInfos}){
      my ($div,$division_name)=process_division_names($gen->division());
      # Check that species division
      if ( grep( /$div/, @{$division})){
        # Check that the file is matching current species assembly
        my $assembly_default = $gen->assembly_default();
        if ($file =~ /$assembly_default/) {
          $self->dataflow_output_id( { 'species'=> $species, 'file' => $appris_dir."/".$file, 'coord_system_version' => $assembly_default, 'analysis' => 'appris' },2 );
          $self->dataflow_output_id( { 'species'=> $species}, 1);
        }
      }
    }
  }

  # # #
  # Process TSL species and flow to loading analysis
  # # #
  while(my($species, $file) = each %{$tsl_species}) {
    # Fetch genome info information from the metadata database
    my $genomeInfos = $gdba->fetch_by_name($species);
    foreach my $gen (@{$genomeInfos}){
      my ($div,$division_name)=process_division_names($gen->division());
      # Check that species division
      if ( grep( /$div/, @{$division})){
        $self->dataflow_output_id( { 'species'=> $species, 'file' => $tsl_dir."/".$file, 'coord_system_version' => $gen->assembly_default(), 'analysis' => 'tsl' },2 );
        $self->dataflow_output_id( { 'species'=> $species}, 1);
      }
    }
  }
  return;
}
sub get_gencode_num {
  my ($self,$v) = @_;
  return( ($v =~ /(\d+)/)[0] || 0);
}
sub get_rel_num {
  my ($self,$v) = @_;
  return( ($v =~ /e(\d+)/)[0] || 0);
}
1;