=head1 LICENSE

Copyright [2009-2017] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Utils::CopyDatabase;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Hive::Utils::URL;
use Log::Log4perl qw/:easy/;
use DBI;
use File::Spec::Functions
  qw( rel2abs curdir canonpath updir catdir catfile );
use File::Temp;
use IO::File;
use Tie::File;
use Carp qw/croak/;
use Time::Duration;
my $start_time = time();

my $logger = get_logger();
if(!Log::Log4perl->initialized()) {
  Log::Log4perl->easy_init($DEBUG);
}

sub copy_database {
  my ($source_db_uri,$target_db_uri,$opt_only_tables,$opt_skip_tables,$update,$drop,$skip_views, $noflush,$opt_skip_views) = @_;

	# Check executable
	$logger->info("Checking mysqlcheck exist");
	check_executables("mysqlcheck");
	$logger->info("Checking rsync exist");
	check_executables("rsync");

	my $working_dir = rel2abs( curdir() );

	# Get list of tables that we want to copy or skip
	my %only_tables;
	my %skip_tables;
	if ( defined($opt_only_tables) ) {
	  %only_tables = map( { $_ => 1 } split( /,/, $opt_only_tables ) );
	}

	if ( defined($opt_skip_tables) ) {
	  %skip_tables = map( { $_ => 1 } split( /,/, $opt_skip_tables ) );
	}

  my $source_db = get_db_connection_params( $source_db_uri);
  my $target_db = get_db_connection_params( $target_db_uri);

  # Verify source server exist.
  if ( !defined($source_db->{host}) || $source_db->{host} eq '' ) {
    croak "Source server $source_db->{host} is not valid";
  }


  #Connect to source database
  $logger->info("Connecting to source $source_db_uri database");
  my $source_dsn = create_dsn($source_db,$update,$opt_only_tables,$source_db_uri,"source");
  my $source_dbh = create_dbh($source_dsn,$source_db);
  
  #Connect to target database
  my $target_dsn = create_dsn($target_db,$update,$opt_only_tables,$target_db_uri,"target");
  my $target_dbh = create_dbh($target_dsn,$target_db);
  
  # Get source and target server data directories.
  my $source_dir = $source_dbh->selectall_arrayref("SHOW VARIABLES LIKE 'datadir'")->[0][1];
  my $target_dir = $target_dbh->selectall_arrayref("SHOW VARIABLES LIKE 'datadir'")->[0][1];

  if ( !defined($source_dir) ) {
    croak "Failed to find data directory for source server at $source_db->{host}";
  }

  if ( !defined($target_dir) ) {
    croak "Failed to find data directory for target server at $target_db->{host}";
  }

  $logger->debug("Using source server datadir: $source_dir");
  $logger->debug("Using target server datadir: $target_dir");

  my $destination_dir = catdir( $target_dir, $target_db->{dbname} );
  my $staging_dir;
  my $tmp_dir;
  my $force=0;
  
  # If we update the database, we don't need a tmp dir
  # We will use the dest dir instead of staging dir.
  if ($update || $opt_only_tables) {
    $staging_dir=$destination_dir;
  }
  else {
  	$tmp_dir = $target_dbh->selectall_arrayref("SHOW VARIABLES LIKE 'tmpdir'")->[0][1];
    if ( !-d $tmp_dir ) {
      croak "Can not find the temporary directory $tmp_dir";
    }
    $logger->info("Using tmp dir: $tmp_dir");
    
    $staging_dir = catdir( $tmp_dir, sprintf( "tmp.%s", $target_db->{dbname} ) );
    
    # Try to make sure the temporary directory and the final destination
    # directory actually exists, and that the staging directory within the
    # temporary directory does *not* exist.

    if ( !$drop && -d $destination_dir ) {
      $logger->info("Destination directory $destination_dir already exists");
      croak "Database destination directory $destination_dir exist. You can use the --drop option to drop the database on the target server";
    }
    # If option drop enabled, drop database on target server.
    if ($drop){
    	$logger->info("Dropping database $target_db->{dbname} on $target_db->{host}");
      $target_dbh->do("DROP DATABASE $target_db;");
    }
    
    if (-d $staging_dir ) {
      $logger->info("Staging directory $staging_dir already exists, using rsync with delete");
      $force=1;
    }
    
    my @create_staging_dir_cmd = ('ssh ', $target_db->{host}, ';','mkdir ', $staging_dir);
    if ( system(@create_staging_dir_cmd) != 0 ) {
      if ( !-d $staging_dir || !$update || !$opt_only_tables) {
        $logger->info("Failed to create staging directory $staging_dir");
        croak "Cannot create staging directory $staging_dir";      }
    }
  }

  my @tables;
  my @views;

  my $table_sth = $source_dbh->prepare('SHOW TABLE STATUS');

  $table_sth->execute();

  my %row;
  # Fancy magic from DBI manual.
  $table_sth->bind_columns( \( @row{ @{ $table_sth->{'NAME_lc'} } } ) );

  TABLE:
    while ( $table_sth->fetch() ) {
      my $table  = $row{'name'};
      my $engine = $row{'engine'};

      if ( defined($opt_only_tables) && !exists( $only_tables{$table} ) )
      {
        next TABLE;
      }
      elsif ( defined($opt_skip_tables) &&
        exists( $skip_tables{$table} ) )
      {
        next TABLE;
      }

      if ( defined($engine) ) {
        if ( $engine eq 'InnoDB' ) {
            croak "FAILED: can not copy InnoDB tables. Please convert $source_db->{dbname}.${table} to MyISAM";
        }
      }
      else {
        if ($skip_views) {
        	$logger->error("SKIPPING view $table");
        }
        else {
          push( @views, $table );
        }
        next TABLE;
      }
      push( @tables, $table );
    } ## end while ( $table_sth->fetch...)

  if (!$noflush){
    #Flushing and locking source database
    $logger->info("Flushing and locking source database\n");

    ## Checking MySQL version on the server. For MySQL version 5.6 and above,  FLUSH TABLES is not permitted when there is an active READ LOCK.
    if ($source_dbh->selectall_arrayref("SHOW VARIABLES LIKE 'version'")->[0][1] lt "5.6"){
      flush_and_lock($source_dbh,\@tables);
    }
    else {
      flush_with_read_lock_mysql_5_6($source_dbh,\@tables);
    }
     
    #Flushing and locking target database
    if ($update || $opt_only_tables) {
      $logger->info("Flushing and locking target database\n");
      if ($target_dbh->selectall_arrayref("SHOW VARIABLES LIKE 'version'")->[0][1] lt "5.6"){
        flush_and_lock($target_dbh,\@tables);
      }
      else{
        flush_with_read_lock_mysql_5_6($target_dbh,\@tables);
      }
    }

  }
  else{
    $logger->info("You are running the script with --noflush.The database will not be locked during the copy.This is not recomended!!!");
  }

  #Optimize source database
  optimize_tables($source_dbh,\@tables);
  
  #Disconnecting from the database before doing the copy
  $source_dbh->disconnect();
  $target_dbh->disconnect();

  # Copying mysql database files

  my $copy_failed = copy_mysql_files($force,$update,$opt_only_tables,$opt_skip_tables,\%only_tables,\%skip_tables,$source_db,$target_db,$staging_dir,$source_dir);

  # Unlock tables source and target

  unlock_tables($source_dbh);

  if ($update || $opt_only_tables){
    unlock_tables($target_dbh);
  }

  # Die if copy failed
  if ($copy_failed) {
    croak "FAILED: copy failed (cleanup of $staging_dir may be needed).";
  }
  
  # Repair views
  view_repair($opt_skip_views,$source_db,$target_db,\@views,$staging_dir);
  
  $target_dbh = create_dbh($target_dsn,$target_db);
  #Optimize target
  # if we use the update option, optimize the target database
  if ($update || $opt_only_tables) {    
    optimize_tables($target_dbh,\@tables);
  }

  $target_dbh->disconnect();

  # Check target database
  mysqlcheck_db ($target_db,\@tables);

  #move database from tmp dir to data dir
  # Only move the database from the temp directory to live directory if
  # we are not using the update option
  if (!$update) {
    if (!$opt_only_tables) {
      move_database($staging_dir, $destination_dir, \@tables, \@views, $target_db);
    }
  }
 
  if (!$noflush){
    #Flush tables
    flush_tables($target_dbh,\@tables,$target_db);
  }

  $target_dbh = create_dbh($target_dsn,$target_db);
  $source_dbh = create_dbh($source_dsn,$source_db);
  copy_functions_and_procedures($source_dbh,$target_dbh,$source_db,$target_db);

  $source_dbh->disconnect();
  $target_dbh->disconnect();

  $logger->info("Copy of $target_db->{dbname} from $source_db->{host} to $target_db->{host} successfull");

  my $runtime =  duration(time() - $start_time);

  $logger->info("Database copy took: $runtime"); 

  return;
}

sub create_dsn {
  my ($db,$update,$opt_only_tables,$db_uri,$server_type) = @_;
  my $dsn;
  if ($update || $opt_only_tables || $server_type eq "source"){
    $logger->debug("Connecting to $server_type $db_uri database");
    $dsn = sprintf( "DBI:mysql:database=%s;host=%s;port=%d", $db->{dbname}, $db->{host}, $db->{port} );
  }
  else{
    $logger->debug("Connecting to $server_type server $db_uri");
    $dsn = sprintf( "DBI:mysql:host=%s;port=%d",$db->{host}, $db->{port} );
  }

  return $dsn;
}

sub create_dbh {
  my ($dsn,$db) = @_;
  my $dbh = DBI->connect( $dsn, $db->{user}, $db->{pass}, {'PrintError' => 1,'AutoCommit' => 0 } );
  if ( !defined($dbh) ) {
    croak "Failed to connect to the server $dsn";
  }
  
  return $dbh;
}

sub check_executables {
  my ($executable) = @_;

  my $output = `which $executable`;
  my $rc     = $? >> 8;

  if($rc != 0) {
    chomp $output;
    croak "Could not find $executable in PATH";
  }
  return;
}

sub get_db_connection_params {
  my ($uri) = @_;
  return '' unless defined $uri;
  my $db = Bio::EnsEMBL::Hive::Utils::URL::parse($uri);
  return $db;
}

sub flush_with_read_lock_mysql_5_6 {
  my ($dbh,$tables) = @_;
  # Flush and Lock tables with a read lock.
  $logger->info("FLUSHING AND LOCKING TABLES...");
  $dbh->do(sprintf( "FLUSH TABLES %s WITH READ LOCK", join( ', ', @{$tables} ) ) );
  return;
}

sub flush_and_lock {
  my ($dbh,$tables) = @_;
  # Lock tables with a read lock.
  $logger->info("LOCKING TABLES...");
  $dbh->do(sprintf( "LOCK TABLES %s READ", join( ' READ, ', @{$tables} ) ) );
  # Flush tables.
  $logger->info("FLUSHING TABLES...");
  $dbh->do(sprintf( "FLUSH TABLES SOURCE %s", join( ', ', @{$tables} ) ) );
  return;
}

sub optimize_tables {
  my ($dbh, $tables) = @_;
  $logger->info("OPTIMIZING TABLES...");
  foreach my $table (@{$tables}) {
    $dbh->do( sprintf( "OPTIMIZE TABLE %s", $table ) );
  }
  return;
}

sub unlock_tables {
  my ($dbh) = @_;
  $logger->info("UNLOCKING TABLES SOURCE...");
  $dbh->do('UNLOCK TABLES');
  $dbh->disconnect();
  return;
}

sub flush_tables {
  my ($dbh,$tables,$target_db) = @_;
  $logger->info("FLUSHING TABLES ON TARGET...");
  $dbh->do("use $target_db->{dbname}");
  my $ddl = sprintf('FLUSH TABLES %s', join(q{, }, @{$tables}));
  $dbh->do($ddl);
  $dbh->disconnect();
  return;
}

sub view_repair {
  my ($opt_skip_views,$source_db,$target_db,$views,$staging_dir) =@_;

  if ($opt_skip_views) {
    $logger->info("SKIPPING VIEWS...");
  }
  else {
    $logger->info("PROCESSING VIEWS...");

    if ( $source_db->{dbname} eq $target_db->{dbname} ) {
      $logger->info("Source and target names ($source_db->{dbname}) are the same. Views do not need repairing");
    }
    else {
      my $ok = 1;

    VIEW:
      foreach my $current_view (@{$views}) {
        $logger->info("Processing $current_view");

        my $view_frm_loc = catfile( $staging_dir, "${current_view}.frm" );

        if ( tie my @view_frm, 'Tie::File', $view_frm_loc ) {
          for (@view_frm) {
            s/`$source_db`/`$target_db`/g;
          }
          untie @view_frm;
        }
        else {
          $logger->error("Cannot tie file $view_frm_loc for VIEW repair.");
          $ok = 0;
          next VIEW;
        }
      }

      if ( !$ok ) {
        croak "FAILED: view cleanup failed. (cleanup of view frm files in $staging_dir may be needed";
      }
    } ## end else [ if ( $source_db eq $target_db)]
  } ## end else [ if ($opt_skip_views) ]
  return;
}

sub myisamchk_db {
  my ($tables,$staging_dir) = @_;
  # Check the copied table files with myisamchk.  Let myisamchk
  # automatically repair any broken or un-closed tables.

  $logger->info("CHECKING TABLES...");

  foreach my $table (@{$tables}) {
    foreach my $index (
       glob( catfile( $staging_dir, sprintf( '%s*.MYI', $table ) ) ) )
    {
      my @check_cmd = (
        'myisamchk', '--check', '--check-only-changed',
        '--update-state', '--force', '--silent', '--silent',    # Yes, twice.
        $index );

      if ( system(@check_cmd) != 0 ) {
        croak "Failed to check some tables. Please clean up $staging_dir";

        last;
      }
    }
  } ## end foreach my $table (@tables)
  return;
}

sub mysqlcheck_db {
  my ($db,$tables) = @_;
  
  my @mysql_check_cmd = ('myisamchk', '--host', $db->{host}, '--port', $db->{port}, '--user', $db->{user}, '--pass', $db->{pass}, '--auto-repair', '--check-only-changed' ,'--check', '--database', $db->{dbname});

  if ($tables){
    foreach my $table (@{$tables}) {
      push @mysql_check_cmd, $table;
      if ( system(@mysql_check_cmd) != 0 ) {
        croak "Failed to check and repair $db->{dbname} on $db->{host}";
        last;
      }
      else { $logger->debug("database $db->{dbname} $table is fine") }
      pop @mysql_check_cmd;
    }
    $logger->debug("database $db->{dbname} is fine")
  }
  else{
    $logger->warn("no table copied, can't check them")
  }

  return;
}

sub move_database {
  my ($staging_dir, $destination_dir, $tables, $views, $target_db)=@_;

  # Move table files into place in and remove the staging directory.  We already
  # know that the destination directory does not exist.

  $logger->info("MOVING $staging_dir TO $destination_dir...");


  my @create_destination_dir_cmd = ('ssh ', $target_db->{host}, ';','mkdir ', $destination_dir);
  if ( system(@create_destination_dir_cmd) != 0 ) {
    croak "Failed to create destination directory $destination_dir. Please clean up $staging_dir.";
  }
  
  my @mv_db_opt = ('ssh ', $target_db->{host}, ';','mv ',catfile( $staging_dir, 'db.opt' ), $destination_dir);
  if ( system(@mv_db_opt) != 0 ) {
    croak "Failed to move db.opt to $destination_dir. Please clean up $staging_dir.";
  }

  foreach my $table (@{$tables}, @{$views}) {
    my @files = glob( catfile( $staging_dir, sprintf( "%s*", $table ) ) );

    $logger->info( "Moving $table...\n");

     my @mv_db_files = ('ssh ', $target_db->{host}, ';','mv ');

  FILE:
    foreach my $file (@files) {
      push @mv_db_files, $file, $destination_dir;
      if ( system(@mv_db_files) != 0 ) {
        croak "Failed to move $file. Please clean up $staging_dir and $destination_dir";
        next FILE;
      }
      pop @mv_db_files;
      pop @mv_db_files;
    }
  }

  # Remove the now empty staging directory.
  my @rm_staging_dir = ('ssh ', $target_db->{host}, ';','rm -r ', $staging_dir);
  if ( system(@rm_staging_dir) != 0 ) {
    croak "Failed to unlink the staging directory $staging_dir. Clean this up manually.";
  }
  return;
}

sub copy_functions_and_procedures{
  my ($source_dbh,$target_dbh,$source_db,$target_db) = @_;
  my $sql_select = "select name, type, returns, body from mysql.proc where db = '$source_db->{dbname}'";
  my $proc_funcs = $source_dbh->selectall_hashref($sql_select, 'name') or die $source_dbh->errstr ;
  if ($proc_funcs){
    foreach my $name (sort keys %{$proc_funcs}){

      my $type = $proc_funcs->{$name}->{type};
      if($type !~ /FUNCTION|PROCEDURE/){
        $logger->warn("Copying '$type' not implemted. Skipping....");
        next;
      }

      # Functions must return something, Procedures must not return anything
      my $returns = '';
      if($type eq 'FUNCTION') {
        $returns = "RETURNS $proc_funcs->{$name}->{returns}";
      }

      my $sql = "CREATE $type $target_db->{dbname}.$name()\n $returns\n $proc_funcs->{$name}->{body}";
      $logger->info("COPYING $proc_funcs->{$name}->{type} $name");
      $target_dbh->do($sql) or die $source_dbh->errstr;
    }
    $logger->info("Finished copying functions and procedures");
  }
  else {
    $logger->debug("No functions or procedures to copy")
  }

  return;
}

# Set up database copying.  We're using rsync for this because it's
# using SSH for network transfers, because it may be used for local
# copy too, and because it has good inclusion/exclusion filter
# options.

sub copy_mysql_files {
  my ($force,$update,$opt_only_tables,$opt_skip_tables,$only_tables,$skip_tables,$source_db,$target_db,$staging_dir,$source_dir) = @_;

  my @copy_cmd;
  
  @copy_cmd = ('rsync');

  push(@copy_cmd, '--whole-file', '--archive', '--progress' );

  if ($force) {
    push( @copy_cmd, '--delete', '--delete-excluded' );
  }
  
  # Update will copy updated tables from source db to target db

  if ($update) {
    push( @copy_cmd, '--update', '--checksum');
  }

  # Set files permission to 755 (rwxr-xr-x)
  push (@copy_cmd, '--chmod=Du=rwx,go=rx,Fu=rwx,go=rx');  

  # Add TCP with arcfour encryption, TCP does go pretty fast (~110 MB/s) and is a better choice in LAN situation.
  push(@copy_cmd, '-e', q{ssh -c arcfour} );

  if ( defined($opt_only_tables) ) {
    push( @copy_cmd, '--ignore-times' );

    push( @copy_cmd,
          map { sprintf( '--include=%s.*', $_ ) } keys(%{$only_tables}) );

    # Partitioned tables:
    push( @copy_cmd,
          map { sprintf( '--include=%s#P#*.*', $_ ) }
            keys(%{$only_tables}) );

    push( @copy_cmd, "--exclude=*" );
  }
  elsif ( defined($opt_skip_tables) ) {
    push( @copy_cmd, '--include=db.opt' );

    push( @copy_cmd,
          map { sprintf( '--exclude=%s.*', $_ ) } keys(%{$skip_tables}) );

    # Partitioned tables:
    push( @copy_cmd,
          map { sprintf( '--exclude=%s#P#*.*', $_ ) }
            keys(%{$skip_tables}) );

    push( @copy_cmd, "--include=*" );
  }
  
  #Copying over ssh
  push (@copy_cmd, "-e ssh ");


  # Copy from remote server.
  push( @copy_cmd,
          sprintf( "%s:%s/", $source_db->{host}, catdir( $source_dir, $source_db->{dbname} ) )
  );

  push( @copy_cmd, sprintf( "%s:%s/", $target_db->{host}, $staging_dir ) );

  # Perform the copy and make sure it succeeds.

  printf( "COPYING '%s:%d/%s' TO STAGING DIRECTORY '%s'\n",
          $source_db->{host}, $source_db->{port}, $source_db->{dbname}, $staging_dir );

  # For debugging:
  # print( join( ' ', @copy_cmd ), "\n" );

  my $copy_failed = 0;
  if ( system(@copy_cmd) != 0 ) {
     $logger->info("Failed to copy database. Please clean up $staging_dir (if needed).");
    $copy_failed = 1;
  }

  return $copy_failed;
} 


1;