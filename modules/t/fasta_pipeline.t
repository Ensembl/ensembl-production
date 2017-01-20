# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
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
use Bio::EnsEMBL::Test::TestUtils qw/ok_directory_contents compare_file_line is_file_line_count/;
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
    [[qw/blat dna/], ['Homo_sapiens.GRCh38.2bit']],
    [[qw/fasta homo_sapiens cdna/], [qw/
        CHECKSUMS README
        Homo_sapiens.GRCh38.cdna.all.fa.gz
    /]],
    [[qw/fasta homo_sapiens dna/], [qw/
        CHECKSUMS README 
        Homo_sapiens.GRCh38.dna.chromosome.6.fa.gz
        Homo_sapiens.GRCh38.dna.chromosome.X.fa.gz
        Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
        Homo_sapiens.GRCh38.dna.toplevel.fa.gz
    /]],
    [[qw/fasta homo_sapiens ncrna/], [qw/
        CHECKSUMS README
        Homo_sapiens.GRCh38.ncrna.fa.gz
    /]],
    [[qw/fasta homo_sapiens pep/], [qw/
        CHECKSUMS README
        Homo_sapiens.GRCh38.pep.all.fa.gz
    /]],
    [[qw/fasta homo_sapiens cds/], [qw/
        CHECKSUMS README
        Homo_sapiens.GRCh38.cds.all.fa.gz
    /]],
  );

  foreach my $setup (@expected_files) {
    my ($sub_dirs, $files) = @{$setup};
    $_ =~ s/release/$release/ for @{$files}; #replace release into it
    my $target_dir = File::Spec->catdir($dir, @{$sub_dirs});
    ok_directory_contents($target_dir, $files, "Checking that $target_dir has all required dump files");
  }

  my $sub_dir = $dir . "/fasta/homo_sapiens/";
  my $dna_file = File::Spec->catdir($sub_dir . "/dna/", 'Homo_sapiens.GRCh38.dna.chromosome.6.fa.gz');
  compare_file_line($dna_file, 1, '>6 dna:chromosome chromosome:GRCh38:6:1:171115067:1 REF', "DNA header is consistent");
  is_file_line_count($dna_file, 2851919, "Expect 2851919 lines in dna file");
  my $ncrna_file = File::Spec->catdir($sub_dir . "/ncrna/", 'Homo_sapiens.GRCh38.ncrna.fa.gz');
  compare_file_line($ncrna_file, 1, '>ENST00000364460.1 ncrna chromosome:GRCh38:6:29550026:29550109:1 gene:ENSG00000201330.1 gene_biotype:snoRNA transcript_biotype:snoRNA gene_symbol:SNORD32B description:small nucleolar RNA, C/D box 32B [Source:HGNC Symbol;Acc:32719]', "ncRNA header is consistent");
  is_file_line_count($ncrna_file, 668, "Expect 668 lines in ncrna file");
  my $pep_file = File::Spec->catdir($sub_dir . "/pep/", 'Homo_sapiens.GRCh38.pep.all.fa.gz');
  compare_file_line($pep_file, 1, '>ENSP00000475351.1 pep chromosome:GRCh38:6:29385057:29386003:1 gene:ENSG00000251608.1 transcript:ENST00000514827.1 gene_biotype:polymorphic_pseudogene transcript_biotype:polymorphic_pseudogene gene_symbol:OR12D1P description:olfactory receptor, family 12, subfamily D, member 1 pseudogene [Source:HGNC Symbol;Acc:8177]', "pep header is consistent");
  is_file_line_count($pep_file, 564, "Expect 564 lines in pep file");
  my $cdna_file = File::Spec->catdir($sub_dir . "/cdna/", 'Homo_sapiens.GRCh38.cdna.all.fa.gz');
  compare_file_line($cdna_file, 1, '>ENST00000514827.1 cdna chromosome:GRCh38:6:29385057:29386003:1 gene:ENSG00000251608.1 gene_biotype:polymorphic_pseudogene transcript_biotype:polymorphic_pseudogene gene_symbol:OR12D1P description:olfactory receptor, family 12, subfamily D, member 1 pseudogene [Source:HGNC Symbol;Acc:8177]', "cDNA header is consistent");
  is_file_line_count($cdna_file, 4282, "Expect 4282 lines in cdna file");
}

done_testing();
