=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Production::Pipeline::Production::EmailSummaryCore;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub fetch_input {
  my ($self) = @_;

  $self->assert_executable('sendmail');

  my $percent_gc = $self->job_count('PercentGC');
  my $percent_repeat = $self->job_count('PercentRepeat');
  my $coding_density = $self->job_count('CodingDensity');
  my $pseudogene_density = $self->job_count('PseudogeneDensity');
  my $short_non_coding_density = $self->job_count('ShortNonCodingDensity');
  my $long_non_coding_density = $self->job_count('LongNonCodingDensity');
  my $gene_gc = $self->job_count('GeneGC');
  my $gene_count = $self->job_count('GeneCount');
  my $ct_exons = $self->job_count('ConstitutiveExons');
  my $pep_stats = $self->job_count('PepStats');
  my $genome_stats = $self->job_count('GenomeStats');

  my $msg = qq/
The Core Statistics pipeline has finished.

Job counts:
  * PercentGC: $percent_gc species
  * PercentRepeat: $percent_repeat species
  * CodingDensity: $coding_density species
  * PseudogeneDensity: $pseudogene_density species
  * ShortNonCodingDensity: $short_non_coding_density species
  * LongNonCodingDensity: $long_non_coding_density species
  * GeneGC: $gene_gc species
  * GeneCount: $gene_count species
  * ConstitutiveExons: $ct_exons species
  * PepStats:$pep_stats species
  * GenomeStats: $genome_stats species
/;
  $self->param('text', $msg)
}

sub job_count {
  my ($self, $logic_name) = @_;
  my $job_count = 0;

  my $aa = $self->db->get_AnalysisAdaptor();
  my $aja = $self->db->get_AnalysisJobAdaptor();
  my $analysis = $aa->fetch_by_logic_name($logic_name);
  
  if ($analysis) {
    my $id = $analysis->dbID();
    my @jobs = @{$aja->fetch_all_by_analysis_id($id)};
    $job_count = scalar(@jobs);
  }

  return $job_count;
}

1;
