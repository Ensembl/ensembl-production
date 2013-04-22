use strict;
use warnings;

## run on empty production db

use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::RunPipeline;
use Bio::EnsEMBL::Test::TestUtils;


use Data::Dumper;
use Bio::EnsEMBL::Utils::CliHelper;


my $reg = 'Bio::EnsEMBL::Registry';
$reg->no_version_check(1); ## version not relevant to production db

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new();


my $db = $multi->get_DBAdaptor("pipeline");
ok($db,"Pipeline database instantiated");

my $web = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $db2 = $web->get_DBAdaptor("web");
ok($db2,"Test web database made");

$| = 1;
$ENV{'PATH'} = $ENV{'PATH'}.":".$ENV{'ENSEMBL_CVS_ROOT_DIR'}."ensembl-production/modules/t/fake_fasta_binaries";
# use __FILE__ to find locality of this script  ----^
my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($db, 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::FASTA_conf');

done_testing();
