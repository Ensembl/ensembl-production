=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::EGPipeline::PipeConfig::STARAlignment_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::ShortReadAlignment_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{ $self->SUPER::default_options() },

    db_type         => 'otherfeatures',
    reformat_header => 1,
    trim_est        => 1,
    trimest_exe     => '/nfs/panda/ensemblgenomes/external/EMBOSS/bin/trimest',
    insdc_ids       => 1,

  };
}

sub modify_analyses {
  my ($self, $analyses) = @_;
  
  my $species_factory_flow;
  if ($self->o('db_type') eq 'core') {
    $species_factory_flow = {
      '2->A' => ['CheckCoreDatabase'],
      'A->2' => ['DNASequenceAlignment'],
    };
  } else {
    $species_factory_flow = {
      '2->A' => ['CheckOFDatabase'],
      'A->2' => ['DNASequenceAlignment'],
    };
  }
  
  my $email_report_flow = ['LoadAlignments'];
  
  foreach my $analysis (@$analyses) {
    if ($analysis->{'-logic_name'} eq 'SpeciesFactory') {
      $analysis->{'-flow_into'} = $species_factory_flow;
    }
    if ($analysis->{'-logic_name'} eq 'EmailReport') {
      $analysis->{'-flow_into'} = $email_report_flow;
    }
    if ($analysis->{'-logic_name'} eq 'SequenceFactory') {
      $analysis->{'-parameters'}->{'reformat_header'} = $self->o('reformat_header');
      $analysis->{'-parameters'}->{'trim_est'} = $self->o('trim_est');
      $analysis->{'-parameters'}->{'trimest_exe'} = $self->o('trimest_exe');
    }
  }
  
  push(@$analyses, @{$self->db_related_analyses()});
}
     
sub db_related_analyses {
  my ($self) = @_;
  
  return 
  [
    {
      -logic_name        => 'CheckCoreDatabase',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 1,
      -can_be_empty      => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['PreAlignmentBackup'],
                              'A->1' => ['AnalysisSetup'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'CheckOFDatabase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::CheckOFDatabase',
      -max_retry_count   => 1,
      -can_be_empty      => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['PreAlignmentBackup'],
                              '3->A' => ['CreateOFDatabase'],
                              'A->1' => ['AnalysisSetup'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'PreAlignmentBackup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type     => $self->o('db_type'),
                              output_file => catdir($self->o('pipeline_dir'), '#species#', 'pre_alignment_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'CreateOFDatabase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::CreateOFDatabase',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -parameters        => {
                              logic_name         => $self->o('logic_name'),
                              program            => $self->o('aligner'),
                              db_type            => $self->o('db_type'),
                              linked_tables      => ['dna_align_feature'],
                              db_backup_required => '#db_exists#',
                              delete_existing    => $self->o('delete_existing'),
                              production_lookup  => $self->o('production_lookup'),
                              production_db      => $self->o('production_db'),
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'DNASequenceAlignment',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -parameters        => {},
      -flow_into         => {
                              '1->A' => ['DumpGenome'],
                              'A->1' => ['PostAlignmentBackup'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'LoadAlignments',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::LoadAlignments',
      -analysis_capacity => 25,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type      => $self->o('db_type'),
                              logic_name   => $self->o('logic_name'),
                              insdc_ids    => $self->o('insdc_ids'),
                              samtools_dir => $self->o('samtools_dir'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'PostAlignmentBackup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type     => $self->o('db_type'),
                              output_file => catdir($self->o('pipeline_dir'), '#species#', 'post_alignment_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['MetaCoords'],
    },

    {
      -logic_name        => 'MetaCoords',
      -module            => 'Bio::EnsEMBL::EGPipeline::CoreStatistics::MetaCoords',
      -max_retry_count   => 1,
      -parameters        => {
                              db_type => $self->o('db_type'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['MetaLevels'],
    },

    {
      -logic_name        => 'MetaLevels',
      -module            => 'Bio::EnsEMBL::EGPipeline::CoreStatistics::MetaLevels',
      -max_retry_count   => 1,
      -parameters        => {
                              db_type => $self->o('db_type'),
                            },
      -rc_name           => 'normal',
    },

  ];
}

1;
