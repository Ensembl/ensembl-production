use strict;
use warnings;

# user specifies a base_path that tells the pipeline where the dump will occur.
# export CVS_ROOT and ENSEMBL_CVS_ROOT to the shell prior to execution
# e.g. perl flatfile_pipeline.t '-run_all 1 -base_path ./'

use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::RunPipeline;
use Bio::EnsEMBL::Test::TestUtils;

my $options = shift @ARGV;
$options ||= '-run_all 1'; 

my $reg = 'Bio::EnsEMBL::Registry';
$reg->no_version_check(1); ## version not relevant to production db

debug("Startup test");
ok(1);

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new();

my $db = $multi->get_DBAdaptor("pipeline");
debug("Pipeline database instantiated");
ok($db);

my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($db, 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::Flatfile_conf',undef,$options);


done_testing();
