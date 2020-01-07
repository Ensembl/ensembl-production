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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneAutoComplete_conf;

=head1 DESCRIPTION

This pipeline create and populate the gene_autocomplete table inside the ensembl_website database
This table is used on the ensembl website region in detail, when you type a gene name in the "gene" box

=head1 AUTHOR

 maurel@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneAutoComplete_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
  my ($self) = @_;

  return {
    %{$self->SUPER::default_options},
    species      => [],
    division     => [],
    run_all      => 0,
    antispecies  => [],
    meta_filters => {},
    db_url => $self->o('srv_url').$self->o('db_name'),
  }
}


sub pipeline_analyses {
    my ($self) = @_;

    return [
    {
        -logic_name => 'create_db',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
        -input_ids  => [ {} ] ,
        -parameters => {
            db_conn => $self->o('srv_url'),
            sql => [
                'CREATE DATABASE IF NOT EXISTS '.$self->o('db_name').';' ],
        },
        -rc_name    => 'default',
        -flow_into  => ['setup_db']
    },
    {
        -logic_name => 'setup_db',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
        -parameters => {
            db_conn => $self->o('db_url'),
            input_file  => $self->o('base_dir').'/ensembl-production/modules/Bio/EnsEMBL/Production/Pipeline/GeneAutocomplete/sql/table.sql',
        },
        -rc_name    => 'default',
        -flow_into  => ['job_factory']
    },
    { -logic_name  => 'job_factory',
       -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
       -parameters => {
                        species      => $self->o('species'),
                        antispecies  => $self->o('antispecies'),
                        division     => $self->o('division'),
                        run_all      => $self->o('run_all'),
                        meta_filters => $self->o('meta_filters'),
                      },
      -rc_name 	       => 'default',
      -max_retry_count => 1,
      -flow_into      => {'2->A' => ['gene_auto_complete_core'],
                          'A->1' => ['optimize'],
                         }
    },
    {
          -logic_name      => "gene_auto_complete_core",
          -module          => 'Bio::EnsEMBL::Production::Pipeline::GeneAutocomplete::CreateGeneAutoComplete',
          -max_retry_count => 1,
          -parameters      => {
            db_uri => $self->o('db_url')
          }
      },
      {
          -logic_name      => "optimize",
          -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
          -max_retry_count => 1,
          -parameters      => {
              db_conn => $self->o('db_url'),
                            sql => [
                  qq/OPTIMIZE TABLE gene_autocomplete;/
              ],
          }
      },

  ];
}


1;
