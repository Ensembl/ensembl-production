
=head1 LICENSE

Copyright [1999-2015] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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

=pod

=head1 NAME

Bio::EnsEMBL::EGPipeline::PipeConfig::AllXref_conf

=head1 DESCRIPTION

Do checksum and alignment xrefs within one pipeline.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::AllXref_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

use Bio::EnsEMBL::EGPipeline::PipeConfig::AlignmentXref_conf;
use Bio::EnsEMBL::EGPipeline::PipeConfig::Xref_conf;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    %{Bio::EnsEMBL::EGPipeline::PipeConfig::AlignmentXref_conf::default_options($self)},
    
    %{Bio::EnsEMBL::EGPipeline::PipeConfig::Xref_conf::default_options($self)},

    pipeline_name => 'all_xref_' . $self->o('ensembl_release'),
  }
}

sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  my $options = join(' ',
    $self->SUPER::beekeeper_extra_cmdline_options,
    "-reg_conf ".$self->o('registry')
  );

  return $options;
}

sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('pipeline_dir'),
    $self->db_cmd("CREATE TABLE split_proteome      (species varchar(100) NOT NULL, split_file varchar(255) NOT NULL)"),
    $self->db_cmd("CREATE TABLE split_transcriptome (species varchar(100) NOT NULL, split_file varchar(255) NOT NULL)"),
    $self->db_cmd("CREATE TABLE gene_descriptions   (species varchar(100) NOT NULL, db_name varchar(100) NOT NULL, total int NOT NULL, timing varchar(10))"),
    $self->db_cmd("CREATE TABLE gene_names          (species varchar(100) NOT NULL, db_name varchar(100) NOT NULL, total int NOT NULL, timing varchar(10))"),
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    %{Bio::EnsEMBL::EGPipeline::PipeConfig::AlignmentXref_conf::pipeline_wide_parameters($self)},
    %{Bio::EnsEMBL::EGPipeline::PipeConfig::Xref_conf::pipeline_wide_parameters($self)},
  };
}

sub pipeline_analyses {
  my ($self) = @_;
  
  my $ax_analyses = Bio::EnsEMBL::EGPipeline::PipeConfig::AlignmentXref_conf::pipeline_analyses($self);
  my $cx_analyses = Bio::EnsEMBL::EGPipeline::PipeConfig::Xref_conf::pipeline_analyses($self);
  
  foreach my $analysis (@$ax_analyses) {
    delete $$analysis{'-input_ids'} if exists $$analysis{'-input_ids'};
  }
  
  my @pruned_cx_analyses;
  foreach my $analysis (@$cx_analyses) {
    delete $$analysis{'-input_ids'} if exists $$analysis{'-input_ids'};
    
    if ($$analysis{'-logic_name'} ne 'DeleteUnattachedXref') {
      push @pruned_cx_analyses, $analysis;
    }
  }
  
  return [
    {
      -logic_name      => 'AllXref',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids       => [ {} ],
      -max_retry_count => 0,
      -flow_into       => {
                            '1->A' => ['InitialiseXref'],
                            'A->1' => ['InitialiseAlignmentXref'],
                          },
      -meadow_type     => 'LOCAL',
    },
    
    @$ax_analyses,
    
    @pruned_cx_analyses,
 ];
}

sub resource_classes {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::resource_classes},
    %{Bio::EnsEMBL::EGPipeline::PipeConfig::AlignmentXref_conf::resource_classes($self)},
  };
}

1;
