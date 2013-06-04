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

$ENV{'PATH'} = $ENV{'PATH'}.":".$ENV{'ENSEMBL_CVS_ROOT_DIR'}."/ensembl-production/modules/t/fake_gtf_binaries";

my $options = shift @ARGV;
$options ||= '-run_all 1 -base_path ./'; 

my $reg = 'Bio::EnsEMBL::Registry';
$reg->no_version_check(1); ## version not relevant to production db

debug("Startup test");
ok(1);

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new();

my $db = $multi->get_DBAdaptor("pipeline");
debug("Pipeline database instantiated");
ok($db);

my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($db, 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::GTF_conf',undef,$options);


done_testing();
