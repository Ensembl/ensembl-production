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
# User can set ENSEMBL_CVS_ROOT to the shell prior to execution or let the
# code select it. All init_pipeline.pl options can be specified. This is
# useful for dumping to another location (base_path is set to a tmp dir removed on cleanup)
# e.g. perl gtf_pipeline.t
# e.g. perl gtf_pipeline.t '-base_path ./'

use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::RunPipeline;
# use Bio::EnsEMBL::Utils::IO qw/gz_slurp_to_array/;
# use Bio::EnsEMBL::ApiVersion qw/software_version/;
# use File::Spec;

my $human = Bio::EnsEMBL::Test::MultiTestDB->new('saccharomyces_cerevisiae');
my $human_dba = $human->get_DBAdaptor('core');
ok($human_dba, 'Human is available');

my $dir = File::Temp->newdir();
$dir->unlink_on_destroy(1);

my $module = 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::Flatfile_conf';
my $options;
if(@ARGV) {
	$options = join(q{ }, @ARGV);
}
else {
	$options = '-base_path '.$dir;
}
my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($module, $options);
ok($pipeline, 'Pipeline has been created '.$module);

$pipeline->run();

if(! @ARGV) {
	# my $target_dir = File::Spec->catdir($dir, 'gtf', 'homo_sapiens');
	# #Expcting a file like Homo_sapiens.GRCh37.73.gtf.gz
	# my ($cs) = @{$human_dba->get_CoordSystemAdaptor->fetch_all('toplevel')};
	# my $schema = software_version();
	# my $gtf_file = sprintf('%s.%s.%d.gtf.gz', $human_dba->species(), $cs->version(), $schema);
	# $gtf_file = ucfirst($gtf_file);
	# dir_contains_ok(
 #    $target_dir,
 #    [qw/CHECKSUMS README/, $gtf_file],
 #  	"$target_dir has GTF, README and CHECKSUM files"
	# );
	# my $contents = gz_slurp_to_array(File::Spec->catfile($target_dir, $gtf_file));
	# cmp_ok(scalar(@{$contents}), '==', 1546, 'Expect 1546 rows in the GTF file');
}

done_testing();
