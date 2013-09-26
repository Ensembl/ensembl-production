use strict;
use warnings;

use Test::More;
use Test::Exception;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::ApiVersion qw/software_version/;

use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Transcript;
use Bio::EnsEMBL::Exon; 

my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $production = $multi_db->get_DBAdaptor('production');

ok($production, "Production database has been created");

my $manager = 'ORM::EnsEMBL::DB::Production::Manager::Biotype';

my $gene = Bio::EnsEMBL::Gene->new(-biotype => 'protein_coding');
my $transcript = Bio::EnsEMBL::Transcript->new(-biotype => 'processed_transcript');
my $exon = Bio::EnsEMBL::Exon->new();

is($manager->fetch_biotype($gene)->biotype_group, 'coding', 'gene biotype group');
is($manager->fetch_biotype($transcript)->biotype_group, 'lnoncoding', 'transcript biotype group');
throws_ok { $manager->fetch_biotype($exon)->biotype_group }
  qr /not a gene or transcript/, 'fetch biotype for exon throws exception';

done_testing();
