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
use Exporter qw/import/;
our @EXPORT_OK = qw(copy_database);
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
  my ($source_db_uri,$target_db_uri,$opt_only_tables,$opt_skip_tables,$update,$drop, $verbose) = @_;

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

  # Verify target server exist.
  if ( !defined($target_db->{host}) || $target_db->{host} eq '' ) {
    croak "Target server $target_db->{host} is not valid";
  }

  if (!defined($target_db->{pass}) || $target_db->{pass} eq ''){
    croak "You need to run this script as the MySQL user that can write on $target_db->{host}"
  }


  if ((defined $update && defined $drop) || (defined $opt_only_tables && defined $drop)) {
    croak "You can't drop the target database when using the --update and --only_tables options.";
  }

  if (!defined($source_db->{dbname}) || !defined($target_db->{dbname})) {
    croak "You need to specify a database name in source and target URI";
  }

  # Check executable
  $logger->debug("Checking myisamchk exist");
  check_executables("myisamchk",$target_db);
  $logger->debug("Checking rsync exist");
  check_executables("rsync",$target_db);


  #Connect to source database
  my $source_dsn = create_dsn($source_db,$source_db_uri);
  my $source_dbh = create_dbh($source_dsn,$source_db);
  
  #Connect to target database
  my $target_dsn = create_dsn($target_db,$target_db_uri);
  my $target_dbh = create_dbh($target_dsn,$target_db);
  
  # Get source and target server data directories.
  my $source_dir = $source_dbh->selectall_arrayref("SHOW VARIABLES LIKE 'datadir'")->[0][1];
  my $target_dir = $target_dbh->selectall_arrayref("SHOW VARIABLES LIKE 'datadir'")->[0][1];

  if ( !defined($source_dir) ) {
      #disconnect from MySQL server
    $source_dbh->disconnect();
    $target_dbh->disconnect();
    croak "Failed to find data directory for source server at $source_db->{host}";
  }

  if ( !defined($target_dir) ) {
      #disconnect from MySQL server
    $source_dbh->disconnect();
    $target_dbh->disconnect();
    croak "Failed to find data directory for target server at $target_db->{host}";
  }

  $logger->debug("Using source server datadir: $source_dir");
  $logger->debug("Using target server datadir: $target_dir");

  my $destination_dir = catdir( $target_dir, $target_db->{dbname} );
  my $staging_dir;
  my $force=0;
  
  #Check if database exist on target server
  if (system("ssh $target_db->{host} ls $destination_dir >/dev/null 2>&1") == 0) {
    # If we update the database, we don't need a tmp dir
    # We will use the dest dir instead of staging dir.
    if ($update || $opt_only_tables){
      $staging_dir=$destination_dir;
    }
    # If option drop enabled, drop database on target server.
    elsif ($drop){
      $logger->info("Dropping database $target_db->{dbname} on $target_db->{host}");
      $target_dbh->do("DROP DATABASE $target_db->{dbname};") or die $target_dbh->errstr;
      # Create the staging dir in server temp directory
      ($force,$staging_dir)=create_staging_db_tmp_dir($target_dbh,$target_db,$staging_dir,$force);
    }
    # If drop not enable, die
    else
    {
      $logger->error("Destination directory $destination_dir already exists");
      #disconnect from MySQL server
      $source_dbh->disconnect();
      $target_dbh->disconnect();
      croak "Database destination directory $destination_dir exist. You can use the --drop option to drop the database on the target server";
    }
  }
  # If database don't exist on source server
  else {
    # If option update is defined, the database need to exist on target server.
    if ($update || $opt_only_tables){
      #disconnect from MySQL server
      $source_dbh->disconnect();
      $target_dbh->disconnect();
      croak "The database need to exist on $target_db->{host} if you want to use the --update or --only_tables options"
    }
    else {
      # Create the staging dir in server temp directory
      ($force,$staging_dir)=create_staging_db_tmp_dir($target_dbh,$target_db,$staging_dir,$force);
    }
  }

  my $target_db_exist=system("ssh $target_db->{host} ls $destination_dir >/dev/null 2>&1");


  #Check if we have enough space on target server before starting the db copy
  check_space_before_copy($source_db,$source_dir,$target_db,$staging_dir);

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
      elsif ( defined($opt_skip_tables) && exists( $skip_tables{$table} ) )
      {
        next TABLE;
      }

      if ( defined($engine) ) {
        if ( $engine eq 'InnoDB' ) {
          #disconnect from MySQL server
          $source_dbh->disconnect();
          $target_dbh->disconnect();
          croak "FAILED: can not copy InnoDB tables. Please convert $source_db->{dbname}.${table} to MyISAM";
        }
      }
      else {
        push( @views, $table );
        next TABLE;
      }
      push( @tables, $table );
    } ## end while ( $table_sth->fetch...)

  #Flushing and locking source database
  $logger->info("Flushing and locking source database");

  ## Checking MySQL version on the server. For MySQL version 5.6 and above,  FLUSH TABLES is not permitted when there is an active READ LOCK.

  flush_with_read_lock($source_dbh,\@tables);

  #Flushing and locking target database
  if ($target_db_exist == 0) {
    $logger->info("Flushing and locking target database");
    flush_with_read_lock($target_dbh,\@tables);
  }

  # Copying mysql database files
  my $copy_failed = copy_mysql_files($force,$update,$opt_only_tables,$opt_skip_tables,\%only_tables,\%skip_tables,$source_db,$target_db,$staging_dir,$source_dir,$verbose);

  # Unlock tables source and target
  $logger->info("Unlocking tables on source database");

  unlock_tables($source_dbh);

  if ($target_db_exist == 0){
    $logger->info("Unlocking tables on target database");
    unlock_tables($target_dbh);
  }

  # Die if copy failed
  if ($copy_failed) {
    #disconnect from MySQL server
    $source_dbh->disconnect();
    $target_dbh->disconnect();
    croak "FAILED: copy failed (cleanup of $staging_dir may be needed).";
  }
  
  # Repair views
  view_repair($source_db,$target_db,\@views,$staging_dir,$source_dbh,$target_dbh);

  $logger->info("Checking/repairing tables on target database");

  # Check target database
  myisamchk_db(\@tables,$staging_dir,$source_dbh,$target_dbh);

  #move database from tmp dir to data dir
  # Only move the database from the temp directory to live directory if
  # we are not using the update option
  if ($target_db_exist != 0) {
      move_database($staging_dir, $destination_dir, \@tables, \@views, $target_db, $source_dbh, $target_dbh);
  }
 
  #Flush tables
  $logger->info("Flushing tables on target database");
  flush_tables($target_dbh,\@tables,$target_db);

  # Copy functions and procedures if exists
  copy_functions_and_procedures($source_dbh,$target_dbh,$source_db,$target_db);

  #Optimize target
  $logger->info("Optimizing tables on target database");
  optimize_tables($target_dbh,\@tables,$target_db);

  #disconnect from MySQL server
  $source_dbh->disconnect();
  $target_dbh->disconnect();

  $logger->info("Copy of $target_db->{dbname} from $source_db->{host} to $target_db->{host} successfull");

  my $runtime =  duration(time() - $start_time);

  $logger->info("Database copy took: $runtime"); 

  return;
}

sub create_staging_db_tmp_dir {
  my ($dbh,$db,$staging_dir,$force) = @_;
  $logger->debug("creating database tmp dir on target server");
  my $tmp_dir = $dbh->selectall_arrayref("SHOW VARIABLES LIKE 'tmpdir'")->[0][1];
  if ( system("ssh $db->{host} ls $tmp_dir >/dev/null 2>&1") != 0 ) {
    #disconnect from MySQL server
    $dbh->disconnect();
    croak "Can not find the temporary directory $tmp_dir";
  }
  $logger->debug("Using tmp dir: $tmp_dir");

  $staging_dir = catdir( $tmp_dir, sprintf( "tmp.%s", $db->{dbname} ) );

  if (system("ssh $db->{host} ls $staging_dir >/dev/null 2>&1") == 0 ) {
    $logger->info("Staging directory $staging_dir already exists, using rsync with delete");
    $force=1;
  }
  else {
    # Creating staging directory
    $logger->debug("Creating $staging_dir");
    system("ssh $db->{host} mkdir -p $staging_dir >/dev/null 2>&1");
    if ( system("ssh $db->{host} ls $staging_dir >/dev/null 2>&1") != 0) {
      $logger->info("Failed to create staging directory $staging_dir");
      #disconnect from MySQL server
      $dbh->disconnect();
      croak "Cannot create staging directory $staging_dir";
    }
  }
  return ($force,$staging_dir);
}

sub create_dsn {
  my ($db,$db_uri) = @_;
  my $dsn;
  my $exist_db = `mysql -ss -r --host=$db->{host} --port=$db->{port} --user=$db->{user} --password=$db->{pass} -e "show databases like '$db->{dbname}'"`;
  if ($exist_db){
    $logger->debug("Connecting to $db_uri database");
    $dsn = sprintf( "DBI:mysql:database=%s;host=%s;port=%d", $db->{dbname}, $db->{host}, $db->{port} );
  }
  else{
    $logger->debug("Connecting to server $db->{host}:$db->{port}");
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
  my ($executable,$db) = @_;

  my $output = `ssh $db->{host} which $executable`;
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

sub flush_with_read_lock {
  my ($dbh,$tables) = @_;
  # Flush and Lock tables with a read lock.
  my $ddl = sprintf( "FLUSH TABLES %s WITH READ LOCK", join( ', ', @{$tables} ) );
  $dbh->do($ddl) or die $dbh->errstr;
  return;
}

sub optimize_tables {
  my ($dbh, $tables, $db) = @_;
  $dbh->do("use $db->{dbname}") or die $dbh->errstr;
  foreach my $table (@{$tables}) {
    $dbh->do( sprintf( "OPTIMIZE TABLE %s", $table ) ) or die $dbh->errstr;
  }
  return;
}

sub unlock_tables {
  my ($dbh) = @_;
  $dbh->do('UNLOCK TABLES') or die $dbh->errstr;
  return;
}

sub flush_tables {
  my ($dbh,$tables,$db) = @_;
  $dbh->do("use $db->{dbname}") or die $dbh->errstr;
  my $ddl = sprintf('FLUSH TABLES %s', join(q{, }, @{$tables}));
  $dbh->do($ddl) or die $dbh->errstr;
  return;
}

sub view_repair {
  my ($source_db,$target_db,$views,$staging_dir, $source_dbh, $target_dbh) =@_;

  $logger->info("Processing views");

  if ( $source_db->{dbname} eq $target_db->{dbname} ) {
    $logger->info("Source and target names ($source_db->{dbname}) are the same. Views do not need repairing");
  }
  else {
    foreach my $current_view (@{$views}) {
      $logger->info("Processing $current_view");
      my $view_frm_loc = catfile( $staging_dir, "${current_view}.frm" );
      if ( system("ssh $target_db->{host} sed -i -e 's/$source_db->{dbname}/$target_db->{dbname}/g' $view_frm_loc >/dev/null 2>&1") != 0 ) {
        #disconnect from MySQL server
        $source_dbh->disconnect();
        $target_dbh->disconnect();
        croak "Failed to repair view $current_view in $staging_dir.";
      }
    }
  }
  return;
}

sub myisamchk_db {
  my ($tables,$staging_dir,$source_dbh,$target_dbh) = @_;
  # Check the copied table files with myisamchk.  Let myisamchk
  # automatically repair any broken or un-closed tables.

  foreach my $table (@{$tables}) {
    foreach my $index (
       glob( catfile( $staging_dir, sprintf( '%s*.MYI', $table ) ) ) )
    {
      my @check_cmd = (
        'myisamchk', '--check', '--check-only-changed',
        '--update-state', '--force', '--silent', '--silent',    # Yes, twice.
        $index );

      if ( system(@check_cmd) != 0 ) {
        #disconnect from MySQL server
        $source_dbh->disconnect();
        $target_dbh->disconnect();
        croak "Failed to check $table table. Please clean up $staging_dir";
        last;
      }
    }
  } ## end foreach my $table (@tables)
  return;
}

sub move_database {
  my ($staging_dir, $destination_dir, $tables, $views, $target_db, $source_dbh, $target_dbh)=@_;

  # Move table files into place in and remove the staging directory.  We already
  # know that the destination directory does not exist.

  $logger->info("Moving $staging_dir to $destination_dir");

  if ( system("ssh $target_db->{host} mkdir -p $destination_dir >/dev/null 2>&1") != 0 ) {
    #disconnect from MySQL server
    $source_dbh->disconnect();
    $target_dbh->disconnect();
    croak "Failed to create destination directory $destination_dir. Please clean up $staging_dir.";
  }
  
  my @mv_db_opt = ('ssh', $target_db->{host},'mv',catfile( $staging_dir, 'db.opt' ), $destination_dir);
  if ( system(@mv_db_opt) != 0 ) {
    #disconnect from MySQL server
    $source_dbh->disconnect();
    $target_dbh->disconnect();
    croak "Failed to move db.opt to $destination_dir. Please clean up $staging_dir.";
  }

  # Moving tables
  foreach my $table (@{$tables}) {
    my @files;
    foreach my $file_extention ("MYD", "MYI", "frm"){
      push @files, catfile( $staging_dir, sprintf( "%s.%s", $table, $file_extention));
    }

    $logger->debug( "Moving $table");

  FILE:
    foreach my $file (@files) {
      if ( system('ssh', $target_db->{host}, 'mv', $file, $destination_dir) != 0 ) {
        croak "Failed to move $file. Please clean up $staging_dir and $destination_dir";
        next FILE;
      }
    }
  }

  # Moving views
  foreach my $view (@{$views}) {
    my $file = catfile( $staging_dir, sprintf( "%s.%s", $view, "frm"));

    $logger->debug( "Moving $view");

    if ( system('ssh', $target_db->{host}, 'mv', $file, $destination_dir) != 0 ) {
      #disconnect from MySQL server
      $source_dbh->disconnect();
      $target_dbh->disconnect();
      croak "Failed to move $file. Please clean up $staging_dir and $destination_dir";
    }
  }

  # Remove the now empty staging directory.
  if ( system("ssh $target_db->{host} rm -r  $staging_dir") != 0 ) {
    #disconnect from MySQL server
    $source_dbh->disconnect();
    $target_dbh->disconnect();
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
        $logger->warn("Copying '$type' not implemted. Skipping");
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
    $logger->debug("Finished copying functions and procedures");
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
  my ($force,$update,$opt_only_tables,$opt_skip_tables,$only_tables,$skip_tables,$source_db,$target_db,$staging_dir,$source_dir,$verbose) = @_;

  my @copy_cmd;
  
  @copy_cmd = ('ssh', $target_db->{host}, 'rsync');

  push(@copy_cmd, '--whole-file', '--archive');

  if ($verbose){
    push (@copy_cmd, '--progress');
  }

  if ($force) {
    push( @copy_cmd, '--delete', '--delete-excluded' );
  }
  
  # Update will copy updated tables from source db to target db
  if ($update) {
    push( @copy_cmd, '--checksum', '--delete');
  }

  # Set files permission to 755 (rwxr-xr-x)
  push (@copy_cmd, '--chmod=Du=rwx,go=rx,Fu=rwx,go=rx');  

  # Add TCP with arcfour encryption, TCP does go pretty fast (~110 MB/s) and is a better choice in LAN situation.
  push(@copy_cmd, '-e ssh');

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

  if ( $source_db->{host} eq $target_db->{host} ) {
    # Local copy.
    push( @copy_cmd,
          sprintf( "%s/", catdir( $source_dir, $source_db->{dbname} ) ) );
  }
  else {
    # Copy from remote server.
    push( @copy_cmd,
          sprintf( "%s:%s/",
                   $source_db->{host}, catdir( $source_dir, $source_db->{dbname} ) )
    );
  }

  push( @copy_cmd, sprintf( "%s/", $staging_dir ) );

  # Perform the copy and make sure it succeeds.

  $logger->info( "Copying $source_db->{host}:$source_db->{port}/$source_db->{dbname} to staging directory $staging_dir");

  # For debugging:
  # print( join( ' ', @copy_cmd ), "\n" );

  my $copy_failed = 0;
  if ( system(@copy_cmd) != 0 ) {
     $logger->info("Failed to copy database. Please clean up $staging_dir (if needed).");
    $copy_failed = 1;
  }

  return $copy_failed;
} 

# Subroutine to check source database size and target server space available.
# Added 10% of server space to the calculation to make sure we don't completely fill up the server.
sub check_space_before_copy {
my ($source_db,$source_dir,$target_db,$staging_dir) = @_;
my $threshold = 10;

#Getting source database size
my ($source_database_size,$source_database_dir) = map { m!(\d+)\s+(.*)! } `ssh $source_db->{host} du ${source_dir}/$source_db->{dbname}`;

#Getting target server space
my @cmd = `ssh $target_db->{host} df -P $staging_dir`;
my ($filesystem,$blocks,$used,$available,$used_percent,$mounted_on) = split('\s+',$cmd[1]);

#Calculate extra space to make sure we don't fully fill up the server
my $threshold_server = ($threshold * $available)/100;

my $space_left_after_copy = $available - ($source_database_size + $threshold_server);

if ( $space_left_after_copy == abs($space_left_after_copy) ) {
    $logger->debug("The database is ".scaledkbytes($source_database_size)." and there is ".scaledkbytes($available)." available on the $target_db->{host}, we can copy the database.")
} else {
    croak("The database is ".scaledkbytes($source_database_size)." and there is ".scaledkbytes($available)." available on the $target_db->{host}, please clean up the server before copying this database.")
}

return;
}

#Subroutine to convert kilobytes in MB, GB, TB...
sub scaledkbytes {
   (sort { length $a <=> length $b }
   map { sprintf '%.3g%s', $_[0]/1024**$_->[1], $_->[0] }
   [KB => 0],[MB=>1],[GB=>2],[TB=>3],[PB=>4],[EB=>5])[0]
}


1;
