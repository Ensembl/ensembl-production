# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

# user specifies a base_path that tells the pipeline where the dump will occur.
# export CVS_ROOT and ENSEMBL_CVS_ROOT to the shell prior to execution
# e.g. perl ebeye_pipeline.t '-run_all 1 -base_path ./'

use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::RunPipeline;
use Bio::EnsEMBL::Test::TestUtils qw/ok_directory_contents/;
use File::Spec;
use File::Temp;

my $dir = File::Temp->newdir();
$dir->unlink_on_destroy(1);

my $options;
if(@ARGV) {
	$options = join(q{ }, @ARGV, '-release_date 31-08-2013');
}
else {
	$options = join(q{ }, '-base_path', $dir, '-release_date 31-08-2013');
}

ok(1, 'Startup test');

my $human = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');
my $human_dba = $human->get_DBAdaptor('core');
ok($human_dba, 'Human is available') or BAIL_OUT 'Cannot get human core DB. Do not continue';

my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $compara_adap = $multi_db->get_DBAdaptor("compara");
ok($compara_adap,"Test compara database successfully contacted") or BAIL_OUT 'Cannot get compara DB. Do not continue';
my $production_dba = $multi_db->get_DBAdaptor('production') or BAIL_OUT 'Cannot get production DB. Do not continue';

my $module = 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::EBeye_conf';
my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($module, $options);
$pipeline->add_fake_binaries('fake_ebeye_binaries');

$pipeline->run();

#
# NOTE
#
# Here we simply test that the expected files have been produced
#
my $core_dbname = $human_dba->dbc()->dbname();
ok_directory_contents(
  File::Spec->catdir($dir, 'ebeye'),
  [qw/CHECKSUMS release_note.txt/, "Gene_${core_dbname}.xml.gz"],
  "Dump dir has flatfile, release notes and CHECKSUM files"
);

done_testing();
