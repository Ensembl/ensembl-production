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

debug("Startup test");
ok(1);

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new();

my $db = $multi->get_DBAdaptor("pipeline");
debug("Pipeline database instatiated");
ok($db);

my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($db, 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::Flatfile_conf');


done_testing();
