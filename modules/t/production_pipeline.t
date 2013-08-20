use strict;
use warnings;

## run on empty production db

use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::RunPipeline;

ok(1, 'Startup test');

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new();

my $human = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');
my $human_dba = $human->get_DBAdaptor('core');
ok($human_dba, 'Human is available') or BAIL_OUT 'Cannot get human core DB. Do not continue';

my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $production = $multi_db->get_DBAdaptor('production') or BAIL_OUT 'Cannot get production DB. Do not continue';

my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Core_handover_conf');
$pipeline->run();

my $dfa  = $human_dba->get_DensityFeatureAdaptor();
my $sa = $human_dba->get_SliceAdaptor();
my $aa = $human_dba->get_AttributeAdaptor();
my $ga = $human_dba->get_GeneAdaptor();
my $ta = $human_dba->get_TranscriptAdaptor();
my $tla = $human_dba->get_TranslationAdaptor();
my $ea = $human_dba->get_ExonAdaptor();

my $slice = $sa->fetch_by_region('chromosome', '6');
my $gene = $ga->fetch_by_stable_id('ENSG00000167393');
my $transcript = $ta->fetch_by_stable_id('ENST00000376806');
my $translation = $tla->fetch_by_stable_id('ENSP00000334263');
my $exon = $ea->fetch_by_stable_id('ENSE00001654835');
my $exon2 = $ea->fetch_by_stable_id('ENSE00001612438');


# Check coding density for chromosome 6
my @coding_density = @{ $dfa->fetch_all_by_Slice($slice, 'codingdensity') };
my $coding_density = 0;
foreach my $c (@coding_density) {
   $coding_density+= $c->density_value;
}
is($coding_density, 21, "Coding density on chromosome 6");

# Check coding density for all chromosomes
@coding_density = @{ $dfa->fetch_all('codingdensity') };
$coding_density = 0;
foreach my $c (@coding_density) {
   $coding_density+= $c->density_value;
}
is($coding_density, 24, "Coding density on all chromosomes");

# Check coding count for chromosome 6
my @coding_count = @{ $aa->fetch_all_by_Slice($slice, 'coding_cnt') };
my $coding_count = 0;
foreach my $c (@coding_count) {
   $coding_count += $c->value;
}
is($coding_count, 21, "Coding count on chromosome 6");

# Check coding count for all reference chromosomes
@coding_count = @{ $aa->fetch_all_by_Slice(undef, 'coding_cnt') };
$coding_count = 0;
foreach my $c (@coding_count) {
   $coding_count += $c->value;
}
is($coding_count, 24, "Coding count on all reference chromosomes");

# Check coding count for all alternate sequences
my @coding_acount = @{ $aa->fetch_all_by_Slice(undef, 'coding_acnt') };
my $coding_acount = 0;
foreach my $c (@coding_acount) {
   $coding_acount += $c->value;
}
is($coding_acount, 0, "Coding count on all alternate sequences");


# Check pseudogene density for chromosome 6
my @pseudo_density = @{ $dfa->fetch_all_by_Slice($slice, 'pseudogenedensity') };
my $pseudo_density = 0;
foreach my $p (@pseudo_density) {
   $pseudo_density += $p->density_value;
}
is($pseudo_density, 49, "Pseudogene density on chromosome 6");

# Check pseudogene density for all chromosomes
@pseudo_density = @{ $dfa->fetch_all('pseudogenedensity') };
$pseudo_density = 0;
foreach my $p (@pseudo_density) {
   $pseudo_density += $p->density_value;
}
is($pseudo_density, 50, "Pseudogene density on all reference chromosomes");

# Check pseudogene count for chromosome 6
my @pseudo_count = @{ $aa->fetch_all_by_Slice($slice, 'pseudogene_cnt') };
my $pseudo_count = 0;
foreach my $c (@pseudo_count) {
   $pseudo_count += $c->value;
}
is($pseudo_count, 49, "Pseudogene count on chromosome 6");

# Check pseudogene count for all reference chromosomes
@pseudo_count = @{ $aa->fetch_all_by_Slice(undef, 'pseudogene_cnt') };
$pseudo_count = 0;
foreach my $c (@pseudo_count) {
   $pseudo_count += $c->value;
}
is($pseudo_count, 50, "Pseudogene count on all reference chromosomes");

# Check pseudogene count for all alternate sequences
my @pseudo_acount = @{ $aa->fetch_all_by_Slice(undef, 'pseudogene_acnt') };
my $pseudo_acount = 0;
foreach my $c (@pseudo_acount) {
   $pseudo_acount += $c->value;
}
is($pseudo_acount, 1, "Pseudogene count on all alternate sequences");


# Check noncoding density for chromosome 6
my @noncoding_density = @{ $dfa->fetch_all_by_Slice($slice, 'noncodingdensity') };
my $noncoding_density = 0;
foreach my $n (@noncoding_density) {
   $noncoding_density += $n->density_value;
}
is($noncoding_density, 9, "NonCoding density on chromosome 6");

# Check noncoding density for all chromosomes
@noncoding_density = @{ $dfa->fetch_all('noncodingdensity') };
$noncoding_density = 0;
foreach my $n (@noncoding_density) {
   $noncoding_density += $n->density_value;
}
is($noncoding_density, 10, "Non coding density on all reference chromosomes");

# Check noncoding count for chromosome 6
my @noncoding_count = @{ $aa->fetch_all_by_Slice($slice, 'noncoding_cnt') };
my $noncoding_count = 0;
foreach my $c (@noncoding_count) {
   $noncoding_count += $c->value;
}
is($noncoding_count, 9, "Non coding count on chromosome 6");

# Check noncoding count for all reference chromosomes
@noncoding_count = @{ $aa->fetch_all_by_Slice(undef, 'noncoding_cnt') };
$noncoding_count = 0;
foreach my $c (@noncoding_count) {
   $noncoding_count += $c->value;
}
is($noncoding_count, 10, "Non coding count on all reference chromosomes");

# Check noncoding count for all alternate sequences
my @noncoding_acount = @{ $aa->fetch_all_by_Slice(undef, 'noncoding_acnt') };
my $noncoding_acount = 0;
foreach my $c (@noncoding_acount) {
   $noncoding_acount += $c->value;
}
is($noncoding_acount, 1, "Non coding count on all alternate sequences");


# Check snp density for chromosome 6
#my @snp_density = @{ $dfa->fetch_all_by_Slice($slice, 'snpdensity') };
my $snp_density = 0;
#foreach my $s (@snp_density) {
#   $snp_density += $s->density_value;
#}
#is($snp_density, 3399247, "SNP density on chromosome 6");

# Check snp density for all chromosomes
#@snp_density = @{ $dfa->fetch_all('snpdensity') };
$snp_density = 0;
#foreach my $s (@snp_density) {
#   $snp_density += $s->density_value;
#}
#is($snp_density, 5668790, "SNP density on all reference chromosomes");

# Check snp count for chromosome 6
my @snp_count =@{  $aa->fetch_all_by_Slice($slice, 'SNPCount') };
my $snp_count = 0;
foreach my $c (@snp_count) {
   $snp_count += $c->value;
}
#is($snp_count, 3399247, "SNP count on chromosome 6");

# Check snp count for all reference chromosomes
@snp_count =@{  $aa->fetch_all_by_Slice(undef, 'SNPCount') };
$snp_count = 0;
foreach my $c (@snp_count) {
   $snp_count += $c->value;
}
#is($snp_count, 5668790, "SNP count on all reference chromosomes");


# Check repeat density for chromosome 6
my @repeat_density = @{ $dfa->fetch_all_by_Slice($slice, 'percentagerepeat') };
my $repeat_density = 0;
foreach my $r (@repeat_density) {
   $repeat_density += $r->density_value;
}
is($repeat_density, '49.3626', "Repeat density for chromosome 6");


# Check gc density for chromosome 6
my @gc_density = @{ $dfa->fetch_all_by_Slice($slice, 'percentgc') };
my $gc_density = 0;
foreach my $gc (@gc_density) {
   $gc_density += $gc->density_value;
}
is($gc_density, '85.02', "GC density for chromosome 6");


# Check gc count for ENSG00000167393
my @gc_count = @{ $aa->fetch_all_by_Gene($gene, 'GeneGC') };
my $gc_count = 0;
foreach my $c (@gc_count) {
   $gc_count += $c->value;
}
is($gc_count, 58.29, "GC count for ENSG00000167393");


# Check pepstat counts for ENSP00000334263
my @pep_count = @{ $aa->fetch_all_by_Translation($translation) };
foreach my $p (@pep_count) {
   if ($p->code eq "Charge") {
      is($p->value, "-7.0", "Charge for ENSP00000334263");
   } elsif ($p->code eq "IsoPoint") {
      is($p->value, "5.2750", "IsoPoint for ENSP00000334263");
   } elsif ($p->code eq "NumResidues") {
      is($p->value, "346", "Number of residues for ENSP00000334263");
   } elsif ($p->code eq "MolecularWeight") {
      is($p->value, "39061.68", "Molecular weight for ENSP00000334263");
   } elsif ($p->code eq "AvgResWeight") {
      is($p->value, "112.895", "Average residual weight for ENSP00000334263");
   }
}


# Check constitutive state for exons
my $is_constitutive = $exon->is_constitutive();
is($is_constitutive, 1, "ENSE00001654835 is constitutive");
$is_constitutive = $exon2->is_constitutive();
is($is_constitutive, 0, "ENSE00001612438 is not constitutive");


# Check non sense attributes
my @nonsense = @{ $aa->fetch_all_by_Transcript($transcript, 'StopGained') };
my $rs;
foreach my $n (@nonsense) {
   if ($n->value =~ /(rs[0-9]*)/) {
      $rs = $1;
   }
}
is($rs, "rs9260156", "ENST00000376806 has stop gained attribute");

done_testing();
