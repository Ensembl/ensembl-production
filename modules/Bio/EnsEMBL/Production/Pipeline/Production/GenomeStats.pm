package Bio::EnsEMBL::Production::Pipeline::Production::GenomeStats;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Production::StatsGenerator/;


sub run {
  my ($self) = @_;
  my $species    = $self->param('species');
  my $dba        = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');

  my %genome_counts = $self->get_attrib_codes();
  $self->delete_old_stats($dba, %genome_counts);
  my $count;
  my %stats_hash;

  foreach my $table (keys %genome_counts) {
    if ($table eq 'PredictionTranscript') {
      my $aa = $dba->get_adaptor('Analysis');
      my @analysis = @{ $aa->fetch_all_by_feature_class('PredictionTranscript') };
      foreach my $analysis (@analysis) {
        $count = $self->get_feature_count($table, $genome_counts{$table}, 'analysis_id = ' . $analysis->dbID);
        $self->store_statistics($species, $table, $count, $analysis->logic_name);
      }
    
    } else {
      $count = $self->get_feature_count($table, $genome_counts{$table});
      if ($count > 0) {
        $self->store_statistics($species, $table, $count, 'struct_var');
      }
    }
  }
}

sub get_attrib_codes {
  my ($self) = @_;
  my %genome_counts = (
    PredictionTranscript => 'core',
    StructuralVariationFeature => 'variation',
    
  );
  return %genome_counts;
}

sub get_feature_count {
  my ($self, $table, $dbtype, $condition) = @_;
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($self->param('species'), $dbtype);
  my $count = 0;
  if ($table =~ /Length/) {
    my $slice_adaptor = $dba->get_adaptor('slice');
    my $slices = $slice_adaptor->fetch_all('seqlevel');
    foreach my $slice (@$slices) {
      $count += $slice->length();
    }
  } elsif (defined $dba) {
    my $adaptor = $dba->get_adaptor($table);
    $count = $adaptor->generic_count($condition);
  }
  return $count;
}


sub store_statistics {
  my ($self, $species, $stats, $value, $attribute) = @_;
  my $genome_container = Bio::EnsEMBL::Registry->get_adaptor($self->param('species'), 'core', 'GenomeContainer');
  $genome_container->store($stats, $value, $attribute);
}




1;

