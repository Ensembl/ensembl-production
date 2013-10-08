use strict;
use warnings;

use Test::More;
use Test::Exception;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::ApiVersion qw/software_version/;

use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Transcript;
use Bio::EnsEMBL::Exon; 

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $production_dba = $multi->get_DBAdaptor('production');
ok($production_dba, "Production database has been created");

my $manager = $production_dba->get_biotype_manager(); 

# test for the set of groups in the production db
is_deeply($manager->fetch_all_biotype_groups, 
	  [ qw/coding pseudogene undefined snoncoding lnoncoding/ ], 
	  'fetch all biotype groups');

my @got = sort @{$manager->group_members('lnoncoding')};
my @expected = sort qw /ambiguous_orf antisense lincRNA non_coding processed_transcript retained_intron ncrna_host 3prime_overlapping_ncrna antisense_RNA sense_intronic sense_overlapping/;
is_deeply(\@got, \@expected, 'long non-coding biotype group members');
throws_ok { $manager->group_members('dummy_group') }
  qr /Invalid biotype group/, 'request for group members with non existant group throws exception';


my $human = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');
my $human_dba = $human->get_DBAdaptor('core');
ok($human_dba, 'Human database is available');

my $gene_adaptor = $human_dba->get_GeneAdaptor;
my $transcript_adaptor = $human_dba->get_TranscriptAdaptor;
my $exon_adaptor = $human_dba->get_ExonAdaptor;

# gene: biotype = protein_coding, group = coding
my $gene = $gene_adaptor->fetch_by_stable_id('ENSG00000204704'); 
is($manager->fetch_biotype($gene)->biotype_group, 'coding', 'gene biotype group');
ok($manager->is_member_of_group($gene, 'coding'), 'gene biotype belongs to coding');
ok(!$manager->is_member_of_group($gene, 'pseudogene'), 'gene biotype does not belong to pseudogene');
throws_ok { $manager->is_member_of_group($gene, 'dummy_group') }
  qr /Invalid biotype group/, 'call to is_member_of_group with non-existant group throws exception';

# transcript: biotype = lincRNA, biotype = lnoncoding
my $transcript = $transcript_adaptor->fetch_by_stable_id('ENST00000436804');
is($manager->fetch_biotype($transcript)->biotype_group, 'lnoncoding', 'transcript biotype group');
ok($manager->is_member_of_group($transcript, 'lnoncoding'), 'transcript biotype belongs to lnoncoding');
ok(!$manager->is_member_of_group($transcript, 'coding'), 'transcript biotype does not belong to coding');

# exon -> error querying for biotype (not a gene or transcript)
my $exon = $exon_adaptor->fetch_by_stable_id('ENSE00001691220');
throws_ok { $manager->fetch_biotype($exon)->biotype_group }
  qr /not a gene or transcript/, 'fetch biotype for exon throws exception';

done_testing();
