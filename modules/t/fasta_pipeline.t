use strict;
use warnings;

## run on empty production db

use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::RunPipeline;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Utils::CliHelper;
use Bio::EnsEMBL::ApiVersion;

use File::Path qw( remove_tree);
# options to hand through to eHive for pipeline execution
my $options = shift @ARGV;
$options ||= '-run_all 1';

my $reg = 'Bio::EnsEMBL::Registry';
$reg->no_version_check(1); ## version not relevant to production db

my $test_db = Bio::EnsEMBL::Test::MultiTestDB->new();

my $pipe_adap = $test_db->get_DBAdaptor("core");
ok($pipe_adap,"Pipeline database instantiated");

my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $web_adap = $multi_db->get_DBAdaptor("web");
ok($web_adap,"Test web database successfully contacted");

my $prod_adapt = $multi_db->get_DBAdaptor("production");
ok($prod_adapt,"Test production database successfully contacted");

$ENV{'PATH'} = $ENV{'PATH'}.":".$ENV{'ENSEMBL_CVS_ROOT_DIR'}."ensembl-production/modules/t/fake_fasta_binaries";
# can't find a nicer way to do this, based on the lack of knowledge of where a user invokes the test from.
my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($pipe_adap, 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::FASTA_conf',undef,$options);

ok($pipeline,"Pipeline ran to completion");

# check the outputs exist.

my $release = Bio::EnsEMBL::ApiVersion->software_version();

my @expected_files = qw(
    blat/dna/30001.Homo_sapiens.GRCh37.2bit
    fasta/homo_sapiens/cdna/CHECKSUMS
    fasta/homo_sapiens/cdna/Homo_sapiens.GRCh37.release.cdna.all.fa.gz
    fasta/homo_sapiens/cdna/README
    fasta/homo_sapiens/dna/CHECKSUMS
    fasta/homo_sapiens/dna/Homo_sapiens.GRCh37.release.dna.chromosome.6.fa.gz
    fasta/homo_sapiens/dna/Homo_sapiens.GRCh37.release.dna.chromosome.HG480_HG481_PATCH.fa.gz
    fasta/homo_sapiens/dna/Homo_sapiens.GRCh37.release.dna.chromosome.X.fa.gz
    fasta/homo_sapiens/dna/Homo_sapiens.GRCh37.release.dna.primary_assembly.fa.gz
    fasta/homo_sapiens/dna/Homo_sapiens.GRCh37.release.dna.toplevel.fa.gz
    fasta/homo_sapiens/dna/README
    fasta/homo_sapiens/ncrna/CHECKSUMS
    fasta/homo_sapiens/ncrna/Homo_sapiens.GRCh37.release.ncrna.fa.gz
    fasta/homo_sapiens/ncrna/README
    fasta/homo_sapiens/pep/CHECKSUMS
    fasta/homo_sapiens/pep/Homo_sapiens.GRCh37.release.pep.all.fa.gz
    fasta/homo_sapiens/pep/README
);

for (my $x=0; $x<scalar(@expected_files); $x++) {
    $expected_files[$x] =~ s/release/$release/;
};

foreach my $file (@expected_files) {
    ok(check_file($file),"$file is present and non-zero size");
}

remove_tree(qw(fasta blat blast ncbi_blast));
unlink("beekeeper.log");

done_testing();



sub check_file {
    my $path = shift;
    return -e $path && -s $path;
}