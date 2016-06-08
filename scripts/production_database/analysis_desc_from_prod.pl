#!/usr/bin/env/perl
use strict;
use warnings;

# Update a new database with analysis descriptions from the production
# database.

use Getopt::Long qw(:config no_ignore_case);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Production::Utils::ProductionDbUpdater;

use Log::Log4perl qw/:easy/;

my ($host, $port, $user, $pass, $dbname,
    $mhost, $mport, $muser, $mpass, $mdbname,
    $species, $type, @logic_names);

GetOptions(
  "host=s", \$host,
  "P|port=i", \$port,
  "user=s", \$user,
  "p|pass=s", \$pass,
  "dbname=s", \$dbname,
  "mhost=s", \$mhost,
  "mP|mport=i", \$mport,
  "muser=s", \$muser,
  "mp|mpass=s", \$mpass,
  "mdbname=s", \$mdbname,
  "species:s", \$species,
  "type:s", \$type,
  "logic_name:s", \@logic_names,
);

die "--host required" unless $host;
die "--port required" unless $port;
die "--user required" unless $user;
die "--pass required" unless $pass;
die "--dbname required" unless $dbname;
die "--mhost required" unless $mhost;
die "--mport required" unless $mport;
die "--muser required" unless $muser;
die "--species and --type are both required" if ( ($species && !$type) || (!$species && $type) );

$mdbname = "ensembl_production" unless $mdbname;
my $prod_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new
(
  -host   => $mhost,
  -port   => $mport,
  -user   => $muser,
  -pass   => $mpass,
  -dbname => $mdbname,
);

my $updater = Bio::EnsEMBL::Production::Utils::ProductionDbUpdater->new(
                      -PRODUCTION_DBA => $prod_dba);
                      
my $new_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new
(
  -host   => $host,
  -port   => $port,
  -user   => $user,
  -pass   => $pass,
  -dbname => $dbname,
);
                     
Log::Log4perl->easy_init($DEBUG);

$updater->update_analysis_description($new_dba->dbc(), $species, $type, \@logic_names);
