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

=head1 NAME
Bio::EnsEMBL::Production::Pipeline::PipeConfig::DataChecksNonCore_conf

=head1 DESCRIPTION
A pipeline for executing datachecks across non-core databases,
to test whether they are synchronised with associated core databases.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DataChecksNonCore_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::DataCheck::Pipeline::DbDataChecks_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'noncore_datachecks',

    db_types => ['cdna', 'otherfeatures', 'rnaseq', 'compara', 'funcgen', 'variation'],

    datacheck_groups => ['core_sync'],
    datacheck_types  => ['critical'],

    registry_file => $self->o('registry'),

    email => $ENV{'USER'}.'@ebi.ac.uk',
  };
}

sub pipeline_analyses {
  my $self = shift @_;

  my @analyses = @{$self->SUPER::pipeline_analyses};

  foreach my $analysis (@analyses) {
    if ($$analysis{'-logic_name'} eq 'DataCheckSubmission') {
      $$analysis{'-parameters'}{'tag'} = 'Core synchronisation for #expr(join(", ", @{#division#}))expr# #db_type# dbs';
    }
    if ($$analysis{'-logic_name'} eq 'DbFactory') {
      if ($self->o('parallelize_datachecks')) {
        $$analysis{'-flow_into'}{'5->A'} = ['DataCheckFactory'];
      } else {
        $$analysis{'-flow_into'}{'5->A'} = ['RunDataChecks'];
      }
    }
  }

  unshift @analyses,
    {
      -logic_name        => 'NonCoreDbTypeFactory',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -max_retry_count   => 1,
      -analysis_capacity => 1,
      -input_ids         => [ {} ],
      -parameters        => {
                              inputlist    => $self->o('db_types'),
                              column_names => ['db_type']
                            },
      -flow_into         => {
                              '2' => ['DataCheckSubmission'],
                            }
    }
  ;

  return \@analyses;
}

1;
