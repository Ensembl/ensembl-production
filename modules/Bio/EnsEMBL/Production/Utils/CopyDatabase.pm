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
  my ($source_db_uri,$target_db_uri,$opt_only_tables,$opt_skip_tables,$update,$drop,$convert_innodb_to_myisam,$skip_optimize,$verbose) = @_;

  $logger->info("Pre-Copy Checks");
  # Path for MySQL dump
  my $dump_path='/nfs/nobackup/ensembl/ensprod/copy_service/';
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


  if (defined $update && defined $drop) {
    croak "You can't drop the target database when using the --update options.";
  }

  if (!defined($source_db->{dbname}) || !defined($target_db->{dbname})) {
    croak "You need to specify a database name in source and target URI";
  }

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
    croak "Failed to find data directory for source server at $source_db->{host}";
  }

  if ( !defined($target_dir) ) {
    croak "Failed to find data directory for target server at $target_db->{host}";
  }

  $logger->debug("Using source server datadir: $source_dir");
  $logger->debug("Using target server datadir: $target_dir");

  #Check that taget database name doesn't exceed MySQL limit of 64 char
  if (length($target_db->{dbname}) > 64){
    $logger->error("Target database name $target_db->{dbname} is exceeding MySQL limit of 64 characters");
    croak "Target database name $target_db->{dbname} is exceeding MySQL limit of 64 characters";
  }

  my $destination_dir = catdir( $target_dir, $target_db->{dbname} );
  my $staging_dir;
  my $force=0;
  my $target_db_exist = $target_dbh->selectall_arrayref("show databases like ?",{},$target_db->{dbname})->[0][0];
  #Check if database exist on target server
  if (defined($target_db_exist)) {
    # If option drop enabled, drop database on target server.
    if ($drop){
      $logger->info("Dropping database $target_db->{dbname} on $target_db->{host}");
      $target_dbh->do("DROP DATABASE IF EXISTS $target_db->{dbname};") or die $target_dbh->errstr;
    }
    # If we update or copy some tables, we need the target database on target server
    elsif ($update || $opt_only_tables){
      1;
    }
    # If drop not enabled, die
    else
    {
      $logger->error("Destination directory $destination_dir already exists");
      croak "Database destination directory $destination_dir exist. You can use the --drop option to drop the database on the target server";
    }
  }
  #Check if target database still exists on the target server
  $target_db_exist = $target_dbh->selectall_arrayref("show databases like ?",{},$target_db->{dbname})->[0][0];

  my @tables;
  my @views;
  my @tables_flush;

  my $table_sth = $source_dbh->prepare('SHOW TABLE STATUS') or die $source_dbh->errstr;

  $table_sth->execute() or die $source_dbh->errstr;

  my %row;
  # Fancy magic from DBI manual.
  $table_sth->bind_columns( \( @row{ @{ $table_sth->{'NAME_lc'} } } ) );
  my $innodb=0;

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
          $innodb=1;
        }
      }
      else {
        push( @views, $table );
        next TABLE;
      }
      push( @tables, $table );
      # If the table exist in target db, add it to the tables_flush array
      if (system("ssh $target_db->{host} ls ${destination_dir}/${table} >/dev/null 2>&1")==0){
        push( @tables_flush, $table );
      }
    } ## end while ( $table_sth->fetch...)

  my $copy_mysql_files=0;
  #Check if we have access to the server filesystem:
  if (system("ssh $source_db->{host} ls $source_dir >/dev/null 2>&1") == 0 and system("ssh $target_db->{host} ls $target_dir >/dev/null 2>&1") == 0 and !$innodb)  {
    $copy_mysql_files=1;
  }
  #Check if we have enough space on target server before starting the db copy and make sure that there is 20% free space left after copy
  check_space_before_copy($source_db,$source_dir,$target_db,$target_db_exist,$destination_dir,$copy_mysql_files,$source_dbh,$opt_only_tables,$opt_skip_tables,\%only_tables,\%skip_tables);
  if ($copy_mysql_files){
    if ($source_db->{dbname} !~ /mart/){
      #Flushing and locking source database
      $logger->info("Flushing and locking source database");

      ## Checking MySQL version on the server. For MySQL version 5.6 and above,  FLUSH TABLES is not permitted when there is an active READ LOCK.
      flush_with_read_lock($source_dbh,\@tables);

      #Flushing and locking target database
      if (defined($target_db_exist) and @tables_flush) {
        $logger->info("Flushing and locking target database");
        flush_with_read_lock($target_dbh,\@tables_flush);
      }
    }
    # Check executable
    $logger->debug("Checking myisamchk exist");
    check_executables("myisamchk",$target_db);
    $logger->debug("Checking rsync exist");
    check_executables("rsync",$target_db);
    # Create the temp directories on server filesystem
    ($force,$staging_dir) = create_temp_dir($target_db_exist,$update,$opt_only_tables,$staging_dir,$destination_dir,$force,$target_dbh,$target_db,$source_dbh);
    # Copying mysql database files
    copy_mysql_files($force,$update,$opt_only_tables,$opt_skip_tables,\%only_tables,\%skip_tables,$source_db,$target_db,$staging_dir,$source_dir,$verbose);
    if ($source_db->{dbname} !~ /mart/){
      # Unlock tables source and target
      $logger->info("Unlocking tables on source database");
      unlock_tables($source_dbh);
      # Diconnect from the source once the copy is complete
      $source_dbh->disconnect();

      if (defined($target_db_exist)){
        $logger->info("Unlocking tables on target database");
        unlock_tables($target_dbh);
      }
    }
  }
  #Using MySQL dump if the database is innodb or we don't have access to the MySQL server filesystem
  else{
    if ($update){
      croak "We don't have file system access on these server so we can't use the --update options";
    }
    else{
      # Diconnect from the source before doing a MySQL dump
      $source_dbh->disconnect();
      copy_mysql_dump($source_db,$target_db,$dump_path,$opt_only_tables,$opt_skip_tables,\%only_tables,\%skip_tables,$convert_innodb_to_myisam);
    }
  }

  if ($copy_mysql_files){
    # Repair views
    view_repair($source_db,$target_db,\@views,$staging_dir);
    $logger->info("Checking/repairing tables on target database");
    # Check target database
    myisamchk_db(\@tables,$staging_dir);
  }
  else{
    $logger->info("Checking/repairing tables on target database");
    # Check target database
    mysqlcheck_db($target_db);
  }
  #move database from tmp dir to data dir
  # Only move the database from the temp directory to live directory if
  # we are not using the update option
  if (!defined($target_db_exist) and $copy_mysql_files) {
      move_database($staging_dir, $destination_dir, \@tables, \@views, $target_db, $opt_only_tables, \%only_tables);
  }
 
  #Reconnect to target database after copy if it was not an update
  if (!defined($target_db_exist) and $copy_mysql_files){
    $target_dbh = create_dbh($target_dsn,$target_db);
  }
  #Flush tables
  $logger->info("Flushing tables on target database");
  flush_tables($target_dbh,\@tables,$target_db);

  if ($copy_mysql_files){
    # Re-connect to source dbh, then Copy functions and procedures if exists
    $source_dbh = create_dbh($source_dsn,$source_db);
    copy_functions_and_procedures($source_dbh,$target_dbh,$source_db,$target_db);
    $source_dbh->disconnect();
  }

  #Optimize target
  if (not $skip_optimize){
    $logger->info("Optimizing tables on target database");
    optimize_tables($target_dbh,\@tables,$target_db);
  }

  #disconnect from MySQL server
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
    croak "Cannot find the temporary directory $tmp_dir: $!";
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
      croak "Cannot create staging directory $staging_dir: $!";
    }
  }
  return ($force,$staging_dir);
}

sub create_temp_dir {
  my ($target_db_exist,$update,$opt_only_tables,$staging_dir,$destination_dir,$force,$target_dbh,$target_db,$source_dbh) = @_;
  #Check if database exist on target server
  if (defined($target_db_exist)) {
    # If we update the database, we don't need a tmp dir
    # We will use the dest dir instead of staging dir.
    if ($update || $opt_only_tables){
      $staging_dir=$destination_dir;
    }
    else{
      # Create the staging dir in server temp directory
      ($force,$staging_dir)=create_staging_db_tmp_dir($target_dbh,$target_db,$staging_dir,$force);
      $target_dbh->disconnect();
    }
  }
  # If database doesn't exist on target server
  else {
    # If option update is defined, the database need to exist on target server.
    if ($update){
      croak "The database need to exist on $target_db->{host} if you want to use the --update options"
    }
    else {
      # Create the staging dir in server temp directory
      ($force,$staging_dir)=create_staging_db_tmp_dir($target_dbh,$target_db,$staging_dir,$force);
      $target_dbh->disconnect();
    }
  }
  return ($force,$staging_dir);
}

sub create_dsn {
  my ($db,$db_uri) = @_;
  my $dsn;
  my $password = $db->{pass} // "";
  my $exist_db = `mysql -ss -r --host=$db->{host} --port=$db->{port} --user=$db->{user} --password=$password -e "show databases like '$db->{dbname}'"`;
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
    croak "Failed to connect to the server $dsn: $!";
  }
  
  return $dbh;
}

sub check_executables {
  my ($executable,$db) = @_;

  my $output = `ssh $db->{host} which $executable`;
  my $rc     = $? >> 8;

  if($rc != 0) {
    chomp $output;
    croak "Could not find $executable in PATH: $!";
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
  my ($source_db,$target_db,$views,$staging_dir) =@_;

  $logger->info("Processing views");

  if ( $source_db->{dbname} eq $target_db->{dbname} ) {
    $logger->info("Source and target names ($source_db->{dbname}) are the same. Views do not need repairing");
  }
  else {
    foreach my $current_view (@{$views}) {
      $logger->info("Processing $current_view");
      my $view_frm_loc = catfile( $staging_dir, "${current_view}.frm" );
      if ( system("ssh $target_db->{host} sed -i -e 's/$source_db->{dbname}/$target_db->{dbname}/g' $view_frm_loc >/dev/null 2>&1") != 0 ) {
        croak "Failed to repair view $current_view in $staging_dir: $!";
      }
    }
  }
  return;
}

sub myisamchk_db {
  my ($tables,$staging_dir) = @_;
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
        croak "Failed to check $table table: $!. Please clean up $staging_dir";
        last;
      }
    }
  } ## end foreach my $table (@tables)
  return;
}

sub mysqlcheck_db {
  my ($target_db) = @_;
  if ( system("mysqlcheck --auto-repair --host=$target_db->{host} --user=$target_db->{user} --password=$target_db->{pass} --port=$target_db->{port} $target_db->{dbname}") != 0 ) {
    croak "Issue when checking or repairing $target_db->{dbname} on $target_db->{host}: $!";
  }
  return;
}

sub move_database {
  my ($staging_dir, $destination_dir, $tables, $views, $target_db, $opt_only_tables, $only_tables)=@_;

  # Move table files into place in and remove the staging directory.  We already
  # know that the destination directory does not exist.

  $logger->info("Moving $staging_dir to $destination_dir");

  if ( system("ssh $target_db->{host} mkdir -p $destination_dir >/dev/null 2>&1") != 0 ) {
    croak "Failed to create destination directory $destination_dir: $! Please clean up $staging_dir.";
  }
  
  my @mv_db_opt = ('ssh', $target_db->{host},'mv',catfile( $staging_dir, 'db.opt' ), $destination_dir);
  if ( system(@mv_db_opt) != 0 ) {
    croak "Failed to move db.opt to $destination_dir: $! Please clean up $staging_dir.";
  }

  my @files;
  # Generating list of MYISAM tables
  if (defined($opt_only_tables)){
    foreach my $key (sort(keys %{$only_tables})) {
      foreach my $file_extention ("MYD", "MYI", "frm"){
        push @files, catfile( $staging_dir, sprintf( "%s.%s", $key, $file_extention));
      }
    }
  }
  else{
    foreach my $table (@{$tables}) {
      foreach my $file_extention ("MYD", "MYI", "frm"){
        push @files, catfile( $staging_dir, sprintf( "%s.%s", $table, $file_extention));
      }
    }
  }


  FILE:
    foreach my $file (@files) {
      #Moving tables
      $logger->debug( "Moving $file");
      if ( system('ssh', $target_db->{host}, 'mv', $file, $destination_dir) != 0 ) {
        croak "Failed to move $file: $! Please clean up $staging_dir and $destination_dir";
        next FILE;
      }
    }

  # Moving views
  foreach my $view (@{$views}) {
    my $file = catfile( $staging_dir, sprintf( "%s.%s", $view, "frm"));

    $logger->debug( "Moving $view");

    if ( system('ssh', $target_db->{host}, 'mv', $file, $destination_dir) != 0 ) {
      croak "Failed to move $file: $! Please clean up $staging_dir and $destination_dir";
    }
  }

  # Remove the now empty staging directory.
  if ( system("ssh $target_db->{host} rm -r  $staging_dir") != 0 ) {
    croak "Failed to unlink the staging directory $staging_dir: $! Clean this up manually.";
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

  # If we have a subset of tables to copy
  if ( defined($opt_only_tables) ) {
    push( @copy_cmd, '--include=db.opt' );
    push( @copy_cmd, '--ignore-times' );

    push( @copy_cmd,
          map { sprintf( '--include=%s.*', $_ ) } keys(%{$only_tables}) );

    # Partitioned tables:
    push( @copy_cmd,
          map { sprintf( '--include=%s#P#*.*', $_ ) }
            keys(%{$only_tables}) );

    push( @copy_cmd, "--exclude=*" );
  }
  # If we have a subset of tables to skip
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

  if ( system(@copy_cmd) != 0 ) {
     croak "Failed to copy database: $!, Please clean up $staging_dir (if needed).";
  }

  return;
} 

# Dump the database in /nfs/nobackup/ensembl/ensprod/copy_service
# Create database on target server
# Load the database to the target server
sub copy_mysql_dump {
  my ($source_db,$target_db,$dump_path,$opt_only_tables,$opt_skip_tables,$only_tables,$skip_tables,$convert_innodb_to_myisam) = @_;
  my $file=$dump_path.$source_db->{host}.'_'.$source_db->{dbname}.'_'.time().'.sql';
  $logger->info("Dumping $source_db->{dbname} from $source_db->{host} to file $file");
  my @dump_cmd = ("mysqldump", "--max_allowed_packet=1024M", "--host=$source_db->{host}", "--user=$source_db->{user}", "--port=$source_db->{port}");
  # If we are copying a mart database, skip the lock
  if ($source_db->{dbname} =~ /mart/){
    push (@dump_cmd, "--skip-lock-tables");
  }
  # IF we have specified a password
  if (defined $source_db->{pass}){
    push (@dump_cmd, "--password=$source_db->{pass}");
  }
  # If we have a list of tables to skip
  if ( defined($opt_skip_tables)){
    push( @dump_cmd, map { sprintf( "--ignore-table=%s.%s", $source_db->{dbname},$_ ) } keys(%{$skip_tables}) );
  }
  # Adding database name
  push (@dump_cmd, "$source_db->{dbname}");
  # If we have defined a list of table to copy
  if ( defined($opt_only_tables) ) {
    push( @dump_cmd, map { sprintf( "%s", $_ ) } keys(%{$only_tables}) );
  }
  if ( system("@dump_cmd > $file") != 0 ) {
    croak "Cannot dump $source_db->{dbname} from $source_db->{host} to file: $!";
  }
  # Convert InnoDB databases to MyISAM by changing the ENGINE in the dump file
  if ($convert_innodb_to_myisam){
    $logger->info("Converting database to MyISAM");
    my $updated_file = $dump_path.$source_db->{host}.'_'.$source_db->{dbname}.'_'.time().'.sql';
    if ( system("cat $file | sed 's/ENGINE=InnoDB/ENGINE=MyISAM/' > $updated_file") !=0 ){
      cleanup_file($file);
      cleanup_file($updated_file);
      croak "Failed to transform InnoDB database to MyISAM";
    }
    cleanup_file($file);
    $file = $updated_file;
  }
  $logger->info("Creating database $target_db->{dbname} on $target_db->{host}");
  if ( system("mysql --host=$target_db->{host} --user=$target_db->{user} --password=$target_db->{pass} --port=$target_db->{port} -e 'CREATE DATABASE $target_db->{dbname};'") !=0 ) {
    cleanup_file($file);
    croak "Cannot create database $target_db->{dbname} on $target_db->{host}: $!";
  }
  $logger->info("Loading file $file into $target_db->{dbname} on $target_db->{host}");
  if ( system("mysql --max_allowed_packet=1024M --host=$target_db->{host} --user=$target_db->{user} --password=$target_db->{pass} --port=$target_db->{port} $target_db->{dbname} < $file") != 0 ) {
    cleanup_file($file);
    croak "Cannot load file into $target_db->{dbname} on $target_db->{host}: $!";
  }
  cleanup_file($file);
  return;
}

# Subroutine to check source database size and target server space available.
# Added 20% of server space to the calculation to make sure we don't completely fill up the server.
sub check_space_before_copy {
  my ($source_db,$source_dir,$target_db,$target_db_exist,$destination_dir,$copy_mysql_files,$source_dbh,$opt_only_tables,$opt_skip_tables,$only_tables,$skip_tables) = @_;
  my $threshold = 20;
  my ($source_database_size,$source_database_dir);
  #Check if we can ssh to the server
  if (system("ssh $target_db->{host} ls /instances/ >/dev/null 2>&1") == 0){
    # If system file copy, get the database file size, else get an estimate of the database size.
    if ($copy_mysql_files){
      # If we have a list of tables to copy, check the size only for these tables
      if ($opt_only_tables){
        my @command = ("ssh $source_db->{host}", "du -c");
        push( @command, map { sprintf( "${source_dir}/$source_db->{dbname}/%s.*", $_ ) } keys(%{$only_tables}) );
        push ( @command, "| tail -1 | cut -f 1");
        $source_database_size = `@command`;
      }
      # If we have a list of tables to skip, exclude them from the space calculation
      elsif ($opt_skip_tables){
        my @command = ("ssh $source_db->{host}", "du -c", "${source_dir}/$source_db->{dbname}/*");
        push( @command, map { sprintf( "--exclude=${source_dir}/$source_db->{dbname}/%s.*", $_ ) } keys(%{$skip_tables}) );
        push ( @command, "| tail -1 | cut -f 1");
        $source_database_size = `@command`;
      }
      else{
        #Getting source database size
        ($source_database_size,$source_database_dir) = map { m!(\d+)\s+(.*)! } `ssh $source_db->{host} du ${source_dir}/$source_db->{dbname}`;
      }
      # Getting target database size if target db exist.
      if (defined($target_db_exist)){
        my ($target_database_size,$target_database_dir) = map { m!(\d+)\s+(.*)! } `ssh $target_db->{host} du ${destination_dir}`;
        $source_database_size = $source_database_size - $target_database_size;
      }
    }
    else{
      # If we have a list of tables to copy, check the size only for these tables
      if ($opt_only_tables){
        my @bind = ("$source_db->{dbname}");
        my $sql = "SELECT ROUND(SUM(data_length + index_length) / 1024) FROM information_schema.TABLES WHERE table_schema = ? and (";
        my $size = keys %$only_tables;
        my $count = 1;
        foreach my $table (keys %{$only_tables}){
          if ($count == $size){
            $sql = $sql."table_name = ?";
          }
          else{
            $sql = $sql."table_name = ? or ";
          }
          push (@bind,$table);
          $count ++;
        }
        $sql = $sql.");";
        $source_database_size = $source_dbh->selectall_arrayref($sql,{},@bind)->[0][0] or die $source_dbh->errstr;
      }
      # If we have a list of tables to skip, exclude them from the space calculation
      elsif ($opt_skip_tables){
        my @bind = ("$source_db->{dbname}");
        my $sql = "SELECT ROUND(SUM(data_length + index_length) / 1024) FROM information_schema.TABLES WHERE table_schema = ?";
        foreach my $table (keys %{$skip_tables}){
          $sql = $sql." and table_name != ?";
          push (@bind,$table);
        }
        $sql = $sql.";";
        $source_database_size = $source_dbh->selectall_arrayref($sql,{},@bind)->[0][0] or die $source_dbh->errstr;
      }
      else{
        $source_database_size = $source_dbh->selectall_arrayref("SELECT ROUND(SUM(data_length + index_length) / 1024) FROM information_schema.TABLES WHERE table_schema = ?",{},$source_db->{dbname})->[0][0] or die $source_dbh->errstr;
      }
    }
    #Getting target server space
    my @cmd = `ssh $target_db->{host} df -P /instances/`;
    my ($filesystem,$blocks,$used,$available,$used_percent,$mounted_on) = split('\s+',$cmd[1]);
    #Calculate extra space to make sure we don't fully fill up the server
    my $threshold_server = ($threshold * $available)/100;
    my $space_left_after_copy = $available - ($source_database_size + $threshold_server);

    if ( $space_left_after_copy == abs($space_left_after_copy) ) {
        $logger->debug("The database is ".scaledkbytes($source_database_size)." and there is ".scaledkbytes($available)." available on the $target_db->{host}, we can copy the database.")
    } else {
        croak("The database is ".scaledkbytes($source_database_size)." and there is ".scaledkbytes($available)." available on the $target_db->{host}, please clean up the server before copying this database.")
    }
  }
  else{
    $logger->debug("We can't ssh to the target MySQL server so skipping space check");
  }
  return;
}

#Subroutine to convert kilobytes in MB, GB, TB...
sub scaledkbytes {
   (sort { length $a <=> length $b }
   map { sprintf '%.3g%s', $_[0]/1024**$_->[1], $_->[0] }
   [KB => 0],[MB=>1],[GB=>2],[TB=>3],[PB=>4],[EB=>5])[0]
}

sub cleanup_file {
  my ($file) = @_;
  if ( system("rm -f $file") != 0 ) {
    croak "Cannot cleanup $file: $!";
  }
  return;
}


1;
