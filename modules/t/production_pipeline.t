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

## run on empty production db

use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::RunPipeline;

my $options;
if(@ARGV) {
  $options = join(q{ }, @ARGV);
}
else {
  $options = '-run_all 1';
}

ok(1, 'Startup test');

my $human = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');
my $human_dba = $human->get_DBAdaptor('core');
ok($human_dba, 'Human is available') or BAIL_OUT 'Cannot get human core DB. Do not continue';

my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $production = $multi_db->get_DBAdaptor('production') or BAIL_OUT 'Cannot get production DB. Do not continue';

my $module = 'Bio::EnsEMBL::Production::Pipeline::PipeConfig::Core_handover_conf';
my $pipeline = Bio::EnsEMBL::Test::RunPipeline->new($module, $options);
$pipeline->run();

my $dfa  = $human_dba->get_DensityFeatureAdaptor();
my $sa = $human_dba->get_SliceAdaptor();
my $aa = $human_dba->get_AttributeAdaptor();
my $ga = $human_dba->get_GeneAdaptor();
my $ta = $human_dba->get_TranscriptAdaptor();
my $tla = $human_dba->get_TranslationAdaptor();
my $ea = $human_dba->get_ExonAdaptor();
my $genome_container = $human_dba->get_GenomeContainer();
my $sql_helper = $human_dba->dbc->sql_helper();

my $slice = $sa->fetch_by_region('chromosome', '6');
my $gene = $ga->fetch_by_stable_id('ENSG00000167393');
my $transcript = $ta->fetch_by_stable_id('ENST00000376806');
my $translation = $tla->fetch_by_stable_id('ENSP00000334263');
my $exon = $ea->fetch_by_stable_id('ENSE00001654835');
my $exon2 = $ea->fetch_by_stable_id('ENSE00001730680');


# Check coding density for chromosome 6
my @coding_density = @{ $dfa->fetch_all_by_Slice($slice, 'codingdensity') };
my $coding_density = 0;
foreach my $c (@coding_density) {
   $coding_density+= $c->density_value;
}
is($coding_density, 22, "Coding density on chromosome 6");

# Check coding density for all chromosomes
@coding_density = @{ $dfa->fetch_all('codingdensity') };
$coding_density = 0;
foreach my $c (@coding_density) {
   $coding_density+= $c->density_value;
}
is($coding_density, $genome_container->get_coding_count, "Coding density on all chromosomes");

# Check coding count for chromosome 6
my @coding_count = @{ $aa->fetch_all_by_Slice($slice, 'coding_cnt') };
my $coding_count = 0;
foreach my $c (@coding_count) {
   $coding_count += $c->value;
}
is($coding_count, 22, "Coding count on chromosome 6");

# Check coding count for all reference chromosomes
@coding_count = @{ $aa->fetch_all_by_Slice(undef, 'coding_cnt') };
$coding_count = 0;
foreach my $c (@coding_count) {
   $coding_count += $c->value;
}
is($coding_count, $genome_container->get_coding_count, "Coding count on all reference chromosomes");

# Check coding count for all alternate sequences
my @coding_acount = @{ $aa->fetch_all_by_Slice(undef, 'coding_acnt') };
my $coding_acount = 0;
foreach my $c (@coding_acount) {
   $coding_acount += $c->value;
}
is($coding_acount, $genome_container->get_alt_coding_count, "Coding count on all alternate sequences");


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
is($pseudo_density, $genome_container->get_pseudogene_count, "Pseudogene density on all reference chromosomes");

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
is($pseudo_count, $genome_container->get_pseudogene_count, "Pseudogene count on all reference chromosomes");

# Check pseudogene count for all alternate sequences
my @pseudo_acount = @{ $aa->fetch_all_by_Slice(undef, 'pseudogene_acnt') };
my $pseudo_acount = 0;
foreach my $c (@pseudo_acount) {
   $pseudo_acount += $c->value;
}
is($pseudo_acount, $genome_container->get_alt_pseudogene_count, "Pseudogene count on all alternate sequences");


# Check long noncoding density for chromosome 6
my @long_noncoding_density = @{ $dfa->fetch_all_by_Slice($slice, 'longnoncodingdensity') };
my $long_noncoding_density = 0;
foreach my $n (@long_noncoding_density) {
   $long_noncoding_density += $n->density_value;
}
is($long_noncoding_density, 7, "LongNonCoding density on chromosome 6");

# Check long noncoding density for all chromosomes
@long_noncoding_density = @{ $dfa->fetch_all('longnoncodingdensity') };
$long_noncoding_density = 0;
foreach my $n (@long_noncoding_density) {
   $long_noncoding_density += $n->density_value;
}
is($long_noncoding_density, $genome_container->get_lnoncoding_count, "Long non coding density on all reference chromosomes");

# Check long noncoding count for chromosome 6
my @long_noncoding_count = @{ $aa->fetch_all_by_Slice($slice, 'noncoding_cnt_l') };
my $long_noncoding_count = 0;
foreach my $c (@long_noncoding_count) {
   $long_noncoding_count += $c->value;
}
is($long_noncoding_count, 7, "Long non coding count on chromosome 6");

# Check long noncoding count for all reference chromosomes
@long_noncoding_count = @{ $aa->fetch_all_by_Slice(undef, 'noncoding_cnt_l') };
$long_noncoding_count = 0;
foreach my $c (@long_noncoding_count) {
   $long_noncoding_count += $c->value;
}
is($long_noncoding_count, $genome_container->get_lnoncoding_count, "Long non coding count on all reference chromosomes");

# Check long noncoding count for all alternate sequences
my @long_noncoding_acount = @{ $aa->fetch_all_by_Slice(undef, 'noncoding_acnt_l') };
my $long_noncoding_acount = 0;
foreach my $c (@long_noncoding_acount) {
   $long_noncoding_acount += $c->value;
}
is($long_noncoding_acount, $genome_container->get_alt_lnoncoding_count, "Long non coding count on all alternate sequences");

# Check short noncoding density for chromosome 6
my @short_noncoding_density = @{ $dfa->fetch_all_by_Slice($slice, 'shortnoncodingdensity') };
my $short_noncoding_density = 0;
foreach my $n (@short_noncoding_density) {
   $short_noncoding_density += $n->density_value;
}
is($short_noncoding_density, 1, "ShortNonCoding density on chromosome 6");

# Check short noncoding density for all chromosomes
@short_noncoding_density = @{ $dfa->fetch_all('shortnoncodingdensity') };
$short_noncoding_density = 0;
foreach my $n (@short_noncoding_density) {
   $short_noncoding_density += $n->density_value;
}
is($short_noncoding_density, $genome_container->get_snoncoding_count, "Short non coding density on all reference chromosomes");

# Check short noncoding count for chromosome 6
my @short_noncoding_count = @{ $aa->fetch_all_by_Slice($slice, 'noncoding_cnt_s') };
my $short_noncoding_count = 0;
foreach my $c (@short_noncoding_count) {
   $short_noncoding_count += $c->value;
}
is($short_noncoding_count, 1, "Short non coding count on chromosome 6");

# Check short noncoding count for all reference chromosomes
@short_noncoding_count = @{ $aa->fetch_all_by_Slice(undef, 'noncoding_cnt_s') };
$short_noncoding_count = 0;
foreach my $c (@short_noncoding_count) {
   $short_noncoding_count += $c->value;
}
is($short_noncoding_count, $genome_container->get_snoncoding_count, "Short non coding count on all reference chromosomes");

# Check short noncoding count for all alternate sequences
my @short_noncoding_acount = @{ $aa->fetch_all_by_Slice(undef, 'noncoding_acnt_s') };
my $short_noncoding_acount = 0;
foreach my $c (@short_noncoding_acount) {
   $short_noncoding_acount += $c->value;
}
is($short_noncoding_acount, $genome_container->get_alt_snoncoding_count, "Short non coding count on all alternate sequences");


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

# Check total length and reference length
my $ref_sql = "select sum(length) from seq_region sr, seq_region_attrib sra, coord_system cs
where sr.seq_region_id = sra.seq_region_id
and sra.attrib_type_id = 6
and sr.coord_system_id = cs.coord_system_id
and cs.species_id = 1 and cs.name != 'lrg'
and sr.seq_region_id not in (select distinct seq_region_id from assembly_exception ae where ae.exc_type != 'par')";
my $ref_length = $sql_helper->execute_single_result(-SQL => $ref_sql);
is($ref_length, $genome_container->get_ref_length(), "Ref length is correct");
my $total_sql = "select sum(length(sequence)) from dna
join seq_region using (seq_region_id) join coord_system using (coord_system_id)
where species_id = 1";
my $total_length = $sql_helper->execute_single_result(-SQL => $total_sql);
is($total_length, $genome_container->get_total_length(), "Total length is correct");

# Check transcript counts
my $transcript_sql = "select count(*) from transcript t, seq_region s
where t.seq_region_id = s.seq_region_id
and t.seq_region_id not in (
select sa.seq_region_id from seq_region_attrib sa, attrib_type at
where at.attrib_type_id = sa.attrib_type_id
and at.code = 'non_ref')";
my $transcript_count = $sql_helper->execute_single_result(-SQL => $transcript_sql);
is($transcript_count, $genome_container->get_transcript_count(), "Number of transcripts is correct");
my $alt_transcript_sql = "select count(*) from transcript t, seq_region s, seq_region_attrib sa, attrib_type at
where s.seq_region_id = t.seq_region_id
and s.seq_region_id = sa.seq_region_id
and sa.attrib_type_id = at.attrib_type_id
and at.code = 'non_ref'
and biotype not in ('LRG_gene')";
my $alt_transcript_count = $sql_helper->execute_single_result(-SQL => $alt_transcript_sql);
is($alt_transcript_count, $genome_container->get_alt_transcript_count(), "Number of alt transcripts is correct");


# Check pepstat counts for ENSP00000334263
my @pep_count = @{ $aa->fetch_all_by_Translation($translation) };
foreach my $p (@pep_count) {
   if ($p->code eq "Charge") {
      is($p->value, "-7.0", "Charge for ENSP00000334263");
   } elsif ($p->code eq "IsoPoint") {
      is($p->value, "5.2743", "IsoPoint for ENSP00000334263");
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


done_testing();
