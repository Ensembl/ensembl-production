=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
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

Bio::EnsEMBL::EGPipeline::PipeConfig::InterProPan_conf

=head1 DESCRIPTION

Fetch InterPro xrefs from a set of databases, create a unique pan set,
then insert (ignore) into the original databases.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::InterProPan_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    
    pipeline_name => 'interpro_pan_'.$self->o('ensembl_release'),
    
    species         => [],
    division        => [],
    run_all         => 0,
    antispecies     => [],
    core_flow       => 2,
    meta_filters    => {},
    
    merged_file => catdir($self->o('pipeline_dir'), 'all.xrefs.txt'),
    unique_file => catdir($self->o('pipeline_dir'), 'unique.xrefs.txt'),
  };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my $self = shift;
  return "-reg_conf ".$self->o("registry");
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('pipeline_dir'),
  ];
}

sub pipeline_analyses {
  my ($self) = @_;
  
  return [
    {
      -logic_name      => 'SpeciesForSelect',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -input_ids       => [ {} ],
      -parameters      => {
                            species         => $self->o('species'),
                            antispecies     => $self->o('antispecies'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            core_flow       => $self->o('core_flow'),
                            chromosome_flow => 0,
                            regulation_flow => 0,
                            variation_flow  => 0,
                            meta_filters    => $self->o('meta_filters'),
                          },
      -max_retry_count => 1,
      -flow_into       => {
                            '2->A' => 'InterProXrefs',
                            'A->1' => 'Aggregate',
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'InterProXrefs',
      -module          => 'Bio::EnsEMBL::EGPipeline::InterProPan::InterProXrefs',
      -parameters      => {
                            filename => catdir($self->o('pipeline_dir'), '#species#.xrefs.txt'),
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -flow_into       => {
                            1 => [ ':////accu?filename=[]' ],
                          },
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'Aggregate',
      -module          => 'Bio::EnsEMBL::EGPipeline::InterProPan::Aggregate',
      -parameters      => {
                            filenames   => '#filename#',
                            merged_file => $self->o('merged_file'),
                            unique_file => $self->o('unique_file'),
                          },
      -max_retry_count => 1,
      -rc_name         => 'normal',
      -flow_into       => ['SpeciesForInsert'],
    },

    {
      -logic_name      => 'SpeciesForInsert',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -parameters      => {
                            species         => $self->o('species'),
                            antispecies     => $self->o('antispecies'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            core_flow       => $self->o('core_flow'),
                            chromosome_flow => 0,
                            regulation_flow => 0,
                            variation_flow  => 0,
                            meta_filters    => $self->o('meta_filters'),
                          },
      -max_retry_count => 1,
      -flow_into       => {
                            '2' => 'BackupXrefs',
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'BackupXrefs',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -parameters      => {
                            table_list  => ['xref'],
                            output_file => catdir($self->o('pipeline_dir'), 'backup', '#species#.xref.sql'),
                          },
      -max_retry_count => 1,
      -rc_name         => 'normal',
      -flow_into       => ['DeleteXrefs'],
    },

    {
      -logic_name      => 'DeleteXrefs',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -parameters      => {
                            sql =>
                            [
                              'DELETE x.* FROM xref x LEFT OUTER JOIN interpro i ON x.dbprimary_acc = i.interpro_ac INNER JOIN external_db edb ON x.external_db_id = edb.external_db_id WHERE edb.db_name = "Interpro" AND i.interpro_ac IS NULL',
                            ],
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -rc_name         => 'normal',
      -flow_into       => ['LoadXrefs'],
    },

    {
      -logic_name      => 'LoadXrefs',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -parameters      => {
                            sql =>
                            [
                              'CREATE TEMPORARY TABLE tmp_xref LIKE xref',
                              'ALTER TABLE tmp_xref DROP COLUMN xref_id',
                              "LOAD DATA LOCAL INFILE '".$self->o('unique_file')."' INTO TABLE tmp_xref;",
                              'INSERT IGNORE INTO xref (external_db_id, dbprimary_acc, display_label, version, description, info_type, info_text) SELECT * FROM tmp_xref',
                              'DROP TEMPORARY TABLE tmp_xref',
                            ],
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -rc_name         => 'normal',
    },

  ];
}

1;
