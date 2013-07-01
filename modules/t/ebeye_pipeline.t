use strict;
use warnings;

# user specifies a base_path that tells the pipeline where the dump will occur.
# export CVS_ROOT and ENSEMBL_CVS_ROOT to the shell prior to execution
# e.g. perl flatfile_pipeline.t '-run_all 1 -base_path ./'

use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::RunPipeline;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;

use File::Path qw( remove_tree );

$ENV{'CVS_ROOT'} 
  or die "Variable CVS_ROOT must be set";
$ENV{'ENSEMBL_CVS_ROOT_DIR'} 
  or die "Variable ENSEMBL_CVS_ROOT_DIR must be set";

$ENV{'PATH'} = $ENV{'PATH'}.":".$ENV{'ENSEMBL_CVS_ROOT_DIR'}."/ensembl-production/modules/t/fake_ebeye_binaries";

my $options = shift @ARGV;
$options ||= '-run_all 1 -base_path ./ -release_date ' . `date '+%d-%b-%Y'`;
$options =~ /base_path\s+(.+?)\s/;
my $base_path = $1;

my $reg = 'Bio::EnsEMBL::Registry';
$reg->no_version_check(1); ## version not relevant to production db

debug("Startup test");
ok(1);

create_multi_test_db_conf();
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

my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('multi');

my $compara_adap = $multi_db->get_DBAdaptor("compara");
ok($compara_adap,"Test compara database successfully contacted");

my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($db, 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::EBeye_conf',undef,$options);

#
# NOTE
#
# Here we simply test that the expected files have been produced
#
my @dump_dirs = ($base_path, 'ebeye');
my @expected_files = ( 
   File::Spec->catfile(@dump_dirs, 'CHECKSUMS'),
   File::Spec->catfile(@dump_dirs, "Gene_${core_dbname}.xml.gz"),
   File::Spec->catfile(@dump_dirs, 'release_note.txt')
   );

map { ok(check_file($_), "File $_ is present and non-zero size") } @expected_files;

remove_tree($base_path . 'ebeye');
unlink('MultiTestDB.conf');
unlink('beekeeper.log');
unlink('hive_registry');

done_testing();

#
# NOTE
# This requires whoever runs the test to have the set up
# to forward to ens-research through 33067
#
sub create_multi_test_db_conf {
  my ($self) = @_;
  
  my $conf = <<CONF;
{
  'port'   => '33067',
  'driver' => 'mysql',
  'user'   => 'ensadmin',
  'pass'   => 'ensembl',
  'host'   => '127.0.0.1',

  # add a line with the dbname and module
  'databases' => {
    'homo_sapiens' => {
      'core' => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
      'variation' => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
      'empty' => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
      'pipeline' => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    },
    'multi' => {
      'compara' => 'Bio::EnsEMBL::DBSQL::DBAdaptor'
    },
  },

}
CONF
  
  my $conf_file = 'MultiTestDB.conf';
  unless (-e $conf_file) {
    work_with_file($conf_file, 'w', sub {
		     my ($fh) = @_;
		     print $fh $conf;
		     return;
		   });
  }

}

sub check_file {
    my $path = shift;
    return -e $path && -s $path;
}