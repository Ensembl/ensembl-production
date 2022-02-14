=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::TaxonomyUpdate::BackUpDatabase

=head1 DESCRIPTION

Backup databases before taxonomy update 
=over 8

=item type - The format to parse

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::TaxonomyUpdate::BackUpDatabase;

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use POSIX qw(strftime);

sub fetch_input {
  my ($self) = @_;

  #$self->throw("No 'type' parameter specified") unless $self->param('type');

  return;
}

sub run {
  my ($self) = @_;
  my $dbname = $self->param('dbname');
  my $dropbaks = $self->param('dropbaks');
  my $table = 'meta_bak';
  my ($dba) = @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors_by_dbname($dbname) };
  if (! defined $dba){
      throw "Database $dbname not found in registry.";  
  }
  
  #drop bak meta table 
  if($dropbaks){
      $self->warning('drop backup');
      $dba->dbc->do('drop table if exists '.$table);
      return ; 	  
  } 

  $self->warning("Processing $dbname ");
  my $backup_table = $self->_backup($dba, $table);

  return;
}


sub _backup {
  my ( $self, $dba, $table ) = @_;

  my $dbname = $dba->dbc->dbname;
  $dba->dbc->do('drop table if exists '.$table);
  $self->warning( "Backing up to $table" );
  $dba->dbc->do( sprintf( 'create table %s like meta', $table ) );
  #$self->warning( 'Copying data from meta to %s', $table );
  $dba->dbc->do( sprintf( 'insert into %s select * from meta', $table ) );
  $self->warning('Done backup');
  my $dumppath =  $self->param('dumppath');
  if ( defined($dumppath) ) {
    my $timestamp = strftime( "%Y%m%d-%H%M%S", localtime() );

    # Backup the table on file.
    my $filename = sprintf( "%s/%s.%s.%s.sql",
                            $dumppath, $dbname,
                            $table,    $timestamp );

    if ( -e $filename ) {
      die( sprintf( "File '%s' already exists.", $filename ) );
    }

    $self->warning( "Backing up table $table onto file $filename");
    if (system( join(q{ }, "mysqldump",
                "--host=".$dba->dbc->host,
                "--port=".$dba->dbc->port,
                "--user=".$dba->dbc->user,
                "--password=".$dba->dbc->pass,
                "--result-file=$filename",
                $dba->dbc->dbname,
                $table)))
    {
      throw "mysqldump failed: $?";
    }
  }

  return $table;
}


1;
