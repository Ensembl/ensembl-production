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
use Bio::EnsEMBL::Test::TestUtils qw/ok_directory_contents is_file_line_count/;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use File::Spec;

my $human = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');
my $human_dba = $human->get_DBAdaptor('core');
ok($human_dba, 'Human is available');

my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('multi');

my $dir = File::Temp->newdir();
$dir->unlink_on_destroy(1);

my $module = 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::GenesDump_conf';
my $options;
if(@ARGV) {
  $options = join(q{ }, @ARGV);
}
else {
  $options = "-base_path ". $dir . " -gff3_tidy 'cat >' -gff3_validate echo";
}
my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($module, $options);
ok($pipeline, 'Pipeline has been created '.$module);
$pipeline->add_fake_binaries('fake_gtf_binaries');
#$pipeline->add_fake_binaries('fake_gff_binaries');
$pipeline->run();

if(! @ARGV) {
  my $target_dir = File::Spec->catdir($dir, 'gtf', 'homo_sapiens');
  #Expecting a file like Homo_sapiens.GRCh37.73.gtf.gz
  my ($cs) = @{$human_dba->get_CoordSystemAdaptor->fetch_all('toplevel')};
  my $schema = software_version();
  my $gtf_file = sprintf('%s.%s.%d.gtf.gz', $human_dba->species(), $cs->version(), $schema);
  $gtf_file = ucfirst($gtf_file);
  $gtf_file =~ s/\.gtf/\.chr_patch_hapl_scaff\.gtf/;
  my $gtf_abinitio_file = sprintf('%s.%s.%d.abinitio.gtf.gz', $human_dba->species(), $cs->version(), $schema);
  $gtf_abinitio_file = ucfirst($gtf_abinitio_file);
  ok_directory_contents(
    $target_dir,
    [qw/CHECKSUMS README/, $gtf_file, $gtf_abinitio_file],
    "$target_dir has GTF, README and CHECKSUM files"
  );
  opendir (DIR, $target_dir);
  while (my $file = readdir(DIR)) {
    print "Looking at $file\n";
  } 
  my $gtf_loc = File::Spec->catfile($target_dir, $gtf_file);
  is_file_line_count($gtf_loc, 2094, 'Expect 2094 rows in the GTF file');
  my $gtf_abinitio_loc = File::Spec->catfile($target_dir, $gtf_abinitio_file);
  is_file_line_count($gtf_abinitio_loc, 5, 'Expect 5 rows in the GTF abinitio file');

  $target_dir = File::Spec->catdir($dir, 'gff3', 'homo_sapiens');
  #Expecting a file like Homo_sapiens.GRCh37.73.gff3.gz
  ($cs) = @{$human_dba->get_CoordSystemAdaptor->fetch_all('toplevel')};
  $schema = software_version();
  my $gff3_file = sprintf('%s.%s.%d.gff3.gz', $human_dba->species(), $cs->version(), $schema);
  $gff3_file = ucfirst($gff3_file);
  my $chr_gff3_file = $gff3_file;
  $chr_gff3_file =~ s/\.gff3/\.chr\.gff3/;
  my $alt_gff3_file = $gff3_file;
  $alt_gff3_file =~ s/\.gff3/\.chr_patch_hapl_scaff\.gff3/;
  my $gff3_abinitio_file = sprintf('%s.%s.%d.abinitio.gff3.gz', $human_dba->species(), $cs->version(), $schema);
  $gff3_abinitio_file = ucfirst($gff3_abinitio_file);
  ok_directory_contents(
    $target_dir,
    [qw/CHECKSUMS README/, $gff3_file, $gff3_abinitio_file],
    "$target_dir has GFF3, README and CHECKSUM files"
  );
  opendir (DIR, $target_dir);
  while (my $file = readdir(DIR)) {
    print "Looking at $file\n";
  }
  my $gff3_loc = File::Spec->catfile($target_dir, $gff3_file);
  my $chr_gff3_loc = File::Spec->catfile($target_dir, $chr_gff3_file);
  my $alt_gff3_loc = File::Spec->catfile($target_dir, $alt_gff3_file);
  # Less features in gff3 compared to gtf
  # Gtf contains dedicated start_codon and stop_codon features
  # These are included in CDS features in gff3 format
  is_file_line_count($gff3_loc, 1932, "Expect 1932 rows in the $gff3_loc file");
  is_file_line_count($chr_gff3_loc, 1932, "Expect 1932 rows in $chr_gff3_loc file");
  is_file_line_count($alt_gff3_loc, 1942, "Expect 1942 rows in $alt_gff3_loc file");
  is_file_line_count($alt_gff3_loc, 3, 'Expect 3 region lines', 'chromosome');
  is_file_line_count($alt_gff3_loc, 87, 'Expect 87 gene lines', 'ID=gene');
  is_file_line_count($alt_gff3_loc, 212, 'Expect 212 transcript lines', 'ID=transcript');
  is_file_line_count($alt_gff3_loc, 437, 'Expect 437 CDS lines', 'ID=CDS');
  is_file_line_count($alt_gff3_loc, 946, 'Expect 946 exon lines', 'exon_id');
  my $gff3_abinitio_loc = File::Spec->catfile($target_dir, $gff3_abinitio_file);
  # One additional line for the GFF3 header compared to GTF
  is_file_line_count($gff3_abinitio_loc, 9, 'Expect 9 rows in the GFF3 abinitio file');
}

done_testing();
