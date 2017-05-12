=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::Common::Base;

=head1 DESCRIPTION


=head1 MAINTAINER

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::Common::Base;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Hive::Process/;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;
use Bio::EnsEMBL::Utils::Scalar qw/check_ref/;
use File::Find;
use File::Spec;
use File::Path qw/mkpath/;
use POSIX qw/strftime/;
use Carp;

sub hive_dbc {
    my $self = shift;
    my $dbc  = $self->dbc();
    confess('Type error!') unless($dbc->isa('Bio::EnsEMBL::DBSQL::DBConnection'));

return $dbc;
}

sub hive_dbh {
    my $self = shift;
    my $dbh  = $self->hive_dbc->db_handle();
    confess('Type error!') unless($dbh->isa('DBI::db'));

return $dbh;
}

sub core_dba {
    my $self = shift;
    my $dba  = $self->get_DBAdaptor('core');
    confess('Type error!') unless($dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'));

return $dba;
}

sub core_dbc {
    my $self = shift;
    my $dbc  = $self->core_dba()->dbc();
    confess('Type error!') unless($dbc->isa('Bio::EnsEMBL::DBSQL::DBConnection'));

return $dbc;
}

sub otherfeatures_dba {	
  my $self = shift;

  my $dba = $self->get_DBAdaptor('otherfeatures');
  confess('Type error!') unless($dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'));
	
  return $dba;
}

sub otherfeatures_dbc {
  my $self = shift;

  my $dbc = $self->otherfeatures_dba()->dbc();	
  confess('Type error!') unless($dbc->isa('Bio::EnsEMBL::DBSQL::DBConnection'));

  return $dbc;
}

sub otherfeatures_dbh {
  my $self = shift;

  my $dbh = $self->otherfeatures_dba()->dbc()->db_handle();	
  confess('Type error!') unless($dbh->isa('DBI::db'));

  return $dbh;
}


sub core_dbh {
    my $self = shift;
    my $dbh  = $self->core_dbc->db_handle();
    confess('Type error!') unless($dbh->isa('DBI::db'));

return $dbh;
}

sub production_dba {
    my $self = shift;
    my $dba = $self->{production_dba};
    if(!defined $dba) {
      $dba  = $self->get_DBAdaptor('production');
      if (!defined $dba && defined $self->param('production_db')) {      
        my %production_db = %{$self->param('production_db')};
        $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%production_db);
      }
      if(defined $dba) {
        confess('Type error!') unless($dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'));
        $self->{production_dba} = $dba;
      }
    }
    return $self->{production_dba};
}

sub production_dbc {
    my $self = shift;
    my $dbc  = $self->production_dba()->dbc();
    confess('Type error!') unless($dbc->isa('Bio::EnsEMBL::DBSQL::DBConnection'));
    return $dbc;
}

sub production_dbh {
    my $self = shift;
    my $dbh  = $self->production_dba()->dbc()->db_handle();
    confess('Type error!') unless($dbh->isa('DBI::db'));
    return $dbh;
}

sub get_DBAdaptor {
    my ($self, $type) = @_;
    $type ||= 'core';
    my $species = ($type eq 'production') ? 'multi' : $self->param_required('species');

return Bio::EnsEMBL::Registry->get_DBAdaptor($species, $type);
}

# Called from 
#  GTF, GFF3, TSV, Chainfile/DumpFile.pm  
sub build_base_directory {
    my ($self, @extras) = @_;
    my @dirs = ($self->param('base_path'), $self->division());

return File::Spec->catdir(@dirs);
}

sub division {
    my ($self) = @_;
    my $dba        = $self->get_DBAdaptor();
    my ($division) = @{$dba->get_MetaContainer()->list_value_by_key('species.division')};
    return if ! $division;
    $division =~ s/^Ensembl//;

return lc($division);
}

# New function to replace data_path, in TSV & ChainFile/DumpFile.pm
sub get_data_path {
    my ($self, $format) = @_;

    $self->throw("No 'species' parameter specified")
    unless $self->param('species');

return $self->get_dir($format, $self->param('species'));
}

sub get_dir {
    my ($self, @extras) = @_;
    my $base_dir = $self->param('base_path');
    my $dir      = File::Spec->catdir($base_dir, @extras);

    if ($self->param('species')) {
       my $mc       = $self->get_DBAdaptor()->get_MetaContainer();

       if($mc->is_multispecies()==1){
         my $collection_db;
         $collection_db = $1 if($mc->dbc->dbname()=~/(.+)\_core/);
         my $fasta_type    = pop(@extras) if($extras[0] eq 'fasta');
         my $species       = pop(@extras);
         push @extras, $collection_db;
         push @extras, $species;
         push @extras, $fasta_type if(defined $fasta_type);
         $dir = File::Spec->catdir($base_dir, @extras);
       }
    }
    mkpath($dir);

return $dir;
}

sub has_chromosomes {
    my ($self, $dba) = @_;
    my $helper = $dba->dbc->sql_helper();

    my $sql = q{
    SELECT COUNT(*) FROM
    coord_system cs INNER JOIN
    seq_region sr USING (coord_system_id) INNER JOIN
    seq_region_attrib sa USING (seq_region_id) INNER JOIN
    attrib_type at USING (attrib_type_id)
    WHERE cs.species_id = ?
    AND at.code = 'karyotype_rank'
    };
    my $count = $helper->execute_single_result(-SQL => $sql, -PARAMS => [$dba->species_id()]);

   $dba->dbc->disconnect_if_idle();

return $count;
}

# Called from 
#  TSV/DumpFile.pm  

=head2 get_Slices

        Arg[1]      : String type of DB to use (defaults to core)
        Arg[2]      : Boolean should we filter the slices if it is human
  Example     : my $slices = $self->get_Slices('core', 1);
  Description : Basic get_Slices() method to return all distinct slices
                for a species but also optionally filters for the 
                first portion of Human Y which is a non-informative region
                (composed solely of N's). The code will only filter for 
                GRCh38 forcing the developer to update the test for other 
                regions. 
  Returntype  : ArrayRef[Bio::EnsEMBL::Slice] 
  Exceptions  : Thrown if you are filtering Human but also are not on GRCh38

=cut
sub get_Slices {
    my ($self, $type, $filter_human) = @_;

    my $dba    = $self->get_DBAdaptor($type);
    throw "Cannot get a DB adaptor" unless $dba;
    my $sa     = $dba->get_SliceAdaptor();
    my @slices = @{$sa->fetch_all('toplevel', undef, 1, undef, undef)};

    if($filter_human) {
       my $production_name = $self->production_name();

       if($production_name eq 'homo_sapiens') {
       # Coord system with highest rank should always be the one, apart from VEGA databases where it would be the second highest
       my ($cs, $alternative_cs) = @{$dba->get_CoordSystem()->fetch_all()};
       my $expected = 'GRCh38';

       if($cs->version() ne $expected && $alternative_cs->version() ne $expected) {
          throw sprintf(q{Cannot continue as %s's coordinate system %s is not the expected %s }, $production_name, $cs->version(), $expected);
       }

       @slices = grep {
         if($_->seq_region_name() eq 'Y' && ($_->end() < 2781480 || $_->start() > 56887902)) {
           $self->info('Filtering small Y slice');
           0;
         }
         else {
           1;
         }
      } @slices;
    }
   }

return [ sort { $b->length() <=> $a->length() } @slices ];
}


#####

# Takes in a key, checks if the current $self->param() was an empty array
# and replaces it with the value from $self->param_defaults()
sub reset_empty_array_param {
  my ($self, $key) = @_;

  my $param_defaults = $self->param_defaults();
  my $current        = $self->param($key); 
  my $replacement    = $self->param_defaults()->{$key};

  if(check_ref($current, 'ARRAY') && check_ref($replacement, 'ARRAY')) {
    if(! @{$current}) {
      $self->fine('Restting param %s because the given array was empty', $key);
      $self->param($key, $replacement);
    }
  }

return;
}

=head2 get_chromosome_name

  Example     : my $chromosome_name = $self->get_chromosome_name();
  Description : Basic get_chromosome_name method to return the name
                used for the toplevel coordinate system
                Usually chromosome, but can be group for stickleback for example
  Returntype  : String or undef

=cut
sub get_chromosome_name {
  my ($self) = @_;

  my $dba    = $self->get_DBAdaptor('core');
  throw "Cannot get a DB adaptor" unless $dba;
  my $sa     = $dba->get_SliceAdaptor();
  if (scalar(@{$sa->fetch_all_karyotype()}) == 0) { return; }
  my $csa    = $dba->get_CoordSystemAdaptor();
  # List returned is in rank order, first one will be smallest rank
  my $cs     = $csa->fetch_all();

  return $cs->[0]->name();
}

sub cleanup_DBAdaptor {
  my ($self, $type) = @_;
  my $dba = $self->get_DBAdaptor($type);
  $dba->clear_caches;
  $dba->dbc->disconnect_if_idle;
return;
}

sub web_name {
  my ($self) = @_;
  my $name   = ucfirst($self->production_name());

return $name;
}

sub scientific_name {
  my ($self) = @_;
  my $dba    = $self->get_DBAdaptor();
  my $mc     = $dba->get_MetaContainer();
  my $name   = $mc->get_scientific_name();
  $dba->dbc()->disconnect_if_idle();

return $name;
}

sub assembly {
  my ($self) = @_;
  my $dba    = $self->get_DBAdaptor();

return $dba->get_CoordSystemAdaptor()->fetch_all()->[0]->version();
}

sub production_name {
  my ($self, $name) = @_;

  my $dba;

  if($name) {
    $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($name, 'core');
  }
  else {
    $dba = $self->get_DBAdaptor();
  }
  my $mc = $dba->get_MetaContainer();
  my $prod = $mc->get_production_name();
  $dba->dbc()->disconnect_if_idle();

return $prod;
}

# Closes file handle, and deletes the file stub if no data was written to
# the file handle (using tell). We can also only close a file handle and unlink
# the data if it was open otherwise we just ignore it 
# Returns success if we managed to delete the file
sub tidy_file_handle {
  my ($self, $fh, $path) = @_;

  if($fh->opened()) {
    my $unlink = ($fh->tell() == 0) ? 1 : 0;
    $fh->close();
    if($unlink && -f $path) {
      unlink($path);
      return 1;
    }
  } 

return 0;
}

sub info {
  my ($self, $msg, @params) = @_;

  if ($self->debug() > 1) {
    my $formatted_msg;
    if(scalar(@params)) {
      $formatted_msg = sprintf($msg, @params);
    } 
    else {
      $formatted_msg = $msg;
    }
    printf STDERR "INFO [%s]: %s %s\n", $self->_memory_consumption(), strftime('%c',localtime()), $formatted_msg;
  }

return
}

sub fine {
  my ($self, $msg, @params) = @_;

  if ($self->debug() > 2) {
    my $formatted_msg;

    if(scalar(@params)) {
      $formatted_msg = sprintf($msg, @params);
    } 
    else {
      $formatted_msg = $msg;
    }
    printf STDERR "FINE [%s]: %s %s\n", $self->_memory_consumption(), strftime('%c',localtime()), $formatted_msg;
  }

return
}

sub _memory_consumption {
  my ($self)  = @_;
  my $content = `ps -o rss $$ | grep -v RSS`;
  return q{?MB} if $? >> 8 != 0;
  $content    =~ s/\s+//g;
  my $mem     = $content/1024;
  
return sprintf('%.2fMB', $mem);
}

sub find_files {
  my ($self, $dir, $boolean_callback) = @_;

  $self->throw("Cannot find path $dir") unless -d $dir;
  my @files;

  find(sub {
    my $path = $File::Find::name;
    if($boolean_callback->($_)) {
      push(@files, $path);
    }
  }, $dir);

return \@files;
}

sub unlink_all_files {
  my ($self, $dir) = @_;

  $self->info('Removing files from the directory %s', $dir);
  #Delete anything which is a file & not the current or higher directory
  my $boolean_callback = sub {
    return ( $_[0] =~ /^\.\.?$/) ? 0 : 1;
  };
  my $files = $self->find_files($dir, $boolean_callback);

  foreach my $file (@{$files}) {
    $self->fine('Unlinking %s', $file);
    unlink $file;
  }

  $self->info('Removed %d file(s)', scalar(@{$files}));

return;
}

sub assert_executable {
  my ($self, $exe) = @_;

  if(! -x $exe) {
    my $output = `which $exe 2>&1`;
    chomp $output;
    my $rc = $? >> 8;

    if($rc != 0) {
       my $possible_location = `locate -l 1 $exe 2>&1`;
       my $loc_rc = $? >> 8;

       if($loc_rc != 0) {
         my $msg = 'Cannot find the executable "%s" after trying "which" and "locate -l 1". Please ensure it is on your PATH or use an absolute location and try again';
        $self->throw(sprintf($msg, $exe));
       }
    }
  }

return 1;
}

sub run_cmd {
  my ($self, $cmd) = @_;
  $self->info('About to run "%s"', $cmd);
  my $output = `$cmd 2>&1`;
  my $rc     = $? >> 8;
  $self->throw("Cannot run program '$cmd'. Return code was ${rc}. Program output was $output") if $rc;

return ($rc, $output);
}

sub get_production_DBAdaptor {
  my ($self) = @_;

return Bio::EnsEMBL::Registry->get_DBAdaptor('multi', 'production');
}


sub taxonomy_dba {
  my $self = shift;
  
  my $dba = $self->get_DBAdaptor('taxonomy');
  if (!defined $dba) {
    my %taxonomy_db = %{$self->param('taxonomy_db')};
    $dba = Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor->new(%taxonomy_db);
  }
  if (!defined $dba) {
    my %taxonomy_db = %{$self->param('tax_db')};
    $dba = Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor->new(%taxonomy_db);
  }
  confess('Type error!') unless($dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'));
	
  return $dba;
}

sub taxonomy_dbc {
  my $self = shift;

  my $dbc = $self->taxonomy_dba()->dbc();	
  confess('Type error!') unless($dbc->isa('Bio::EnsEMBL::DBSQL::DBConnection'));

  return $dbc;
}

sub taxonomy_dbh {
  my $self = shift;

  my $dbh = $self->taxonomy_dba()->dbc()->db_handle();	
  confess('Type error!') unless($dbh->isa('DBI::db'));

  return $dbh;
}

sub fetch_external_db_id {
  my ($self, $db_name, $type) = @_;
  
  my $sql = 'SELECT external_db_id FROM external_db WHERE db_name = ?';
  
  my $dba = $self->get_DBAdaptor($type);
  my $dbh = $dba->dbc->db_handle;
  my $sth = $dbh->prepare($sql);
  $sth->execute($db_name);
  
  my ($external_db_id) = $sth->fetchrow_array;
  
  return $external_db_id;
}

sub fetch_external_db_display {
  my ($self, $db_name, $type) = @_;
  
  my $sql = 'SELECT db_display_name FROM external_db WHERE db_name = ?';
  
  my $dba = $self->get_DBAdaptor($type);
  my $dbh = $dba->dbc->db_handle;
  my $sth = $dbh->prepare($sql);
  $sth->execute($db_name);
  
  my ($db_display_name) = $sth->fetchrow_array;
  
  return $db_display_name;
}

=head2 hive_database_string_for_user

  Return the name and location of the database in a human readable way.

=cut
sub hive_database_string_for_user {
  my $self = shift;
  return $self->hive_dbc->dbname . " on " . $self->hive_dbc->host 
  
}

=head2 core_database_string_for_user

	Return the name and location of the database in a human readable way.

=cut
sub core_database_string_for_user {
  my $self = shift;
  return $self->core_dbc->dbname . " on " . $self->core_dbc->host 
	
}

=head2 otherfeatures_database_name

	Return the name of the otherfeatures db
    
=cut
sub otherfeatures_database_name {
  my $self = shift;
  return $self->otherfeatures_dbc->dbname;
	
}

=head2 mysql_command_line_connect
=cut
sub mysql_command_line_connect {
  my $self = shift;

  my $cmd = 
      "mysql"
      . " --host ". $self->core_dbc->host
      . " --port ". $self->core_dbc->port
      . " --user ". $self->core_dbc->username
      . " --pass=". $self->core_dbc->password
  ;

  return $cmd;
}

=head2 mysql_command_line_connect_core_db
=cut
sub mysql_command_line_connect_core_db {
	
  my $self = shift;

  my $cmd =
      $self->mysql_command_line_connect
      . " ". $self->core_dbc->dbname
  ;

  return $cmd;
}

=head2 mysql_command_line_connect_otherfeatures_db
=cut
sub mysql_command_line_connect_otherfeatures_db {
	
  my $self = shift;

  my $cmd = 
      "mysql"
      . " --host ". $self->otherfeatures_dbc->host
      . " --port ". $self->otherfeatures_dbc->port
      . " --user ". $self->otherfeatures_dbc->username
      . " --pass=". $self->otherfeatures_dbc->password
      . " ". $self->otherfeatures_dbc->dbname
  ;

  return $cmd;
}

=head2 mysql_command_line_connect_core_db
=cut
sub mysqldump_command_line_connect_core_db {
	
  my $self = shift;

  my $cmd = 
      "mysqldump"
      . " --lock_table=FALSE --no-create-info"
      . " --host ". $self->core_dbc->host
      . " --port ". $self->core_dbc->port
      . " --user ". $self->core_dbc->username
      . " --pass=". $self->core_dbc->password
      . " ". $self->core_dbc->dbname
  ;

  return $cmd;
}

sub mysqlimport_command_line {
  my ($self, $dbc) = @_;
  
  my $cmd = 
    "mysqlimport"
    . " --local"
    . " --host ". $dbc->host
    . " --port ". $dbc->port
    . " --user ". $dbc->username
    . " --pass=". $dbc->password
    . " ". $dbc->dbname
  ;

  return $cmd;
}

sub has_chromosomes {
  my ($self, $dba) = @_;
  my $helper = $dba->dbc->sql_helper();
  my $sql = q{
    SELECT COUNT(*) FROM
    coord_system cs INNER JOIN
    seq_region sr USING (coord_system_id) INNER JOIN
    seq_region_attrib sa USING (seq_region_id) INNER JOIN
    attrib_type at USING (attrib_type_id)
    WHERE cs.species_id = ?
    AND at.code = 'karyotype_rank'
  };
  my $count = $helper->execute_single_result(-SQL => $sql, -PARAMS => [$dba->species_id()]);
  
  $dba->dbc->disconnect_if_idle();
  
  return $count;
}

sub has_genes {
  my ($self, $dba) = @_;
  my $helper = $dba->dbc->sql_helper();
  my $sql = q{
    SELECT COUNT(*) FROM
    coord_system cs INNER JOIN
    seq_region sr USING (coord_system_id) INNER JOIN
    gene g USING (seq_region_id)
    WHERE cs.species_id = ?
  };
  my $count = $helper->execute_single_result(-SQL => $sql, -PARAMS => [$dba->species_id()]);
  
  $dba->dbc->disconnect_if_idle();
  
  return $count;
}


1;
