# Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
# export CVS_ROOT and ENSEMBL_CVS_ROOT_DIR to the shell prior to execution
# e.g. perl fasta_pipeline.t '-run_all 1 -base_path ./'

use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::RunPipeline;
use Bio::EnsEMBL::Test::TestUtils qw/ok_directory_contents/;
use Bio::EnsEMBL::ApiVersion;
use File::Temp;

ok(1, 'Startup test');

my $dir = File::Temp->newdir();
$dir->unlink_on_destroy(1);

my $options;
if(@ARGV) {
  $options = join(q{ }, @ARGV);
}
else {
  $options = '-base_path '.$dir;
}

my $human = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');
my $human_dba = $human->get_DBAdaptor('core');
ok($human_dba, 'Human is available') or BAIL_OUT 'Cannot get human core DB. Do not continue';

my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $web = $multi_db->get_DBAdaptor('web') or BAIL_OUT 'Cannot get web DB. Do not continue';
my $production = $multi_db->get_DBAdaptor('production') or BAIL_OUT 'Cannot get production DB. Do not continue';

my $module = 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::FASTA_conf';
my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($module, $options);
$pipeline->add_fake_binaries('fake_fasta_binaries');

$pipeline->run();


# check the outputs exist.

my $release = Bio::EnsEMBL::ApiVersion->software_version();

if(! @ARGV) {
  my @expected_files = (
    [[qw/blat dna/], ['30001.Homo_sapiens.GRCh38.2bit']],
    [[qw/fasta homo_sapiens cdna/], [qw/
        CHECKSUMS README
        Homo_sapiens.GRCh38.release.cdna.all.fa.gz
    /]],
    [[qw/fasta homo_sapiens dna/], [qw/
        CHECKSUMS README 
        Homo_sapiens.GRCh38.release.dna.chromosome.6.fa.gz
        Homo_sapiens.GRCh38.release.dna.chromosome.6.fa.gz
        Homo_sapiens.GRCh38.release.dna.chromosome.HG480_HG481_PATCH.fa.gz
        Homo_sapiens.GRCh38.release.dna.chromosome.X.fa.gz
        Homo_sapiens.GRCh38.release.dna.primary_assembly.fa.gz
        Homo_sapiens.GRCh38.release.dna.toplevel.fa.gz
    /]],
    [[qw/fasta homo_sapiens ncrna/], [qw/
        CHECKSUMS README
        Homo_sapiens.GRCh38.release.ncrna.fa.gz
    /]],
    [[qw/fasta homo_sapiens pep/], [qw/
        CHECKSUMS README
        Homo_sapiens.GRCh38.release.pep.all.fa.gz
    /]],
    [[qw/fasta homo_sapiens cds/], [qw/
        CHECKSUMS README
        Homo_sapiens.GRCh38.release.cds.all.fa.gz
    /]],
  );

  foreach my $setup (@expected_files) {
    my ($sub_dirs, $files) = @{$setup};
    $_ =~ s/release/$release/ for @{$files}; #replace release into it
    my $target_dir = File::Spec->catdir($dir, @{$sub_dirs});
    ok_directory_contents($target_dir, $files, "Checking that $target_dir has all required dump files");
  }
}

done_testing();
