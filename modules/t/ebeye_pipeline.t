use strict;
use warnings;

# user specifies a base_path that tells the pipeline where the dump will occur.
# export CVS_ROOT and ENSEMBL_CVS_ROOT to the shell prior to execution
# e.g. perl flatfile_pipeline.t '-run_all 1 -base_path ./'

use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::RunPipeline;
use Bio::EnsEMBL::Test::TestUtils;

$ENV{'CVS_ROOT'} 
  or die "Variable CVS_ROOT must be set";
$ENV{'ENSEMBL_CVS_ROOT_DIR'} 
  or die "Variable ENSEMBL_CVS_ROOT_DIR must be set";

$ENV{'PATH'} = $ENV{'PATH'}.":".$ENV{'ENSEMBL_CVS_ROOT_DIR'}."/ensembl-production/modules/t/fake_ebeye_binaries";

my $options = shift @ARGV;
$options ||= '-run_all 1 -base_path ./'; 

my $reg = 'Bio::EnsEMBL::Registry';
$reg->no_version_check(1); ## version not relevant to production db

debug("Startup test");
ok(1);

# This is the configuration file used
# {
#   'port'   => '33067',
#   'driver' => 'mysql',
#   'user'   => 'ensadmin',
#   'pass'   => 'ensembl',
#   'host'   => '127.0.0.1',

#   # add a line with the dbname and module
#   'databases' => {
#     'homo_sapiens' => {
#       'core' => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
#       'variation' => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
#       'empty' => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
#       'pipeline' => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
#     },
#     'circ' => {
#       'core' => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
#     },
#     'multi' => {
#       'compara' => 'Bio::EnsEMBL::DBSQL::DBAdaptor'
#     },
#   },
# }

my $hs_db = Bio::EnsEMBL::Test::MultiTestDB->new();

my $core_adap = $hs_db->get_DBAdaptor("core");
# ok($core_adap,"Test core database successfully contacted");
my $core_dbname = $core_adap->dbc->dbname;
ok($core_dbname, "Test core database successfully contacted");

#
# Disable this check until we get an up-to-date variation DB test configuration
#
# my $variation_adap = $hs_db->get_DBAdaptor("variation");
# ok($variation_adap,"Test variation database successfully contacted");

my $db = $hs_db->get_DBAdaptor("pipeline");
debug("Pipeline database instantiated");
ok($db);

my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('multi');

my $compara_adap = $multi_db->get_DBAdaptor("compara");
ok($compara_adap,"Test compara database successfully contacted");

my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($db, 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::EBeye_conf',undef,$options);

#
# NOTE
#
# Here we simply test that some expected files have been produced
#
my @expected_files = ( 
   'ebeye/CHECKSUMS',
   "ebeye/Gene_${core_dbname}.xml.gz",
   "ebeye/release_note.txt"
   );

map { ok(check_file($_), "File $_ is present and non-zero size") } @expected_files;

# remove_tree('ebeye');
unlink("beekeeper.log");

done_testing();

sub check_file {
    my $path = shift;
    return -e $path && -s $path;
}