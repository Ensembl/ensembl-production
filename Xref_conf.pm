
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

Bio::EnsEMBL::EGPipeline::PipeConfig::Xref_conf

=head1 DESCRIPTION

Assign UniParc and UniParc-derived xrefs.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::Xref_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'xref_' . $self->o('ensembl_release'),

    species      => [],
    division     => [],
    run_all      => 0,
    antispecies  => [],
    meta_filters => {},
    db_type      => 'core',

    local_uniparc_db => {
      -driver => 'mysql',
      -host   => 'mysql-eg-pan-prod.ebi.ac.uk',
      -port   => 4276,
      -user   => 'ensrw',
      -pass   => 'writ3rpan1',
      -dbname => 'uniparc',
    },

    remote_uniparc_db => {
      -driver => 'Oracle',
      -host   => 'ora-vm-004.ebi.ac.uk',
      -port   => 1551,
      -user   => 'uniparc_read',
      -pass   => 'uniparc',
      -dbname => 'UAPRO',
    },

    remote_uniprot_db => {
      -driver => 'Oracle',
      -host   => 'ora-dlvm5-026.ebi.ac.uk',
      -port   => 1521,
      -user   => 'spselect',
      -pass   => 'spselect',
      -dbname => 'SWPREAD',
    },

    replace_all           => 0,
    description_source    => [],
    overwrite_description => 0,
    gene_name_source      => [],
    overwrite_gene_name   => 0,

    load_uniprot        => 1,
    load_uniprot_go     => 1,
    load_uniprot_xrefs  => 1,

    uniparc_external_db   => 'UniParc',
    uniprot_external_dbs  => {
      'reviewed'   => 'Uniprot/SWISSPROT',
      'unreviewed' => 'Uniprot/SPTREMBL',
    },
    uniprot_gn_external_db => 'Uniprot_gn',
    uniprot_go_external_db => 'GO',
    uniprot_xref_external_dbs => {
      'ArrayExpress' => 'ArrayExpress',
      'ChEMBL'       => 'ChEMBL',
      'EMBL'         => 'EMBL',
      'MEROPS'       => 'MEROPS',
      'PDB'          => 'PDB',
    },

    checksum_logic_name => 'xrefchecksum',
    checksum_module     => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniParc',

    uniparc_transitive_logic_name => 'xrefuniparc',
    uniparc_transitive_module     => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProt',

    uniprot_transitive_logic_name  => 'xrefuniprot',
    uniprot_transitive_go_module   => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProtGO',
    uniprot_transitive_xref_module => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProtXrefs',

    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,

    # By default, an email is sent for each species when the pipeline
    # is complete, showing the breakdown of xrefs assigned.
    email_xref_report => 1,
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
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    'db_type'            => $self->o('db_type'),
    'load_uniprot'       => $self->o('load_uniprot'),
    'load_uniprot_go'    => $self->o('load_uniprot_go'),
    'load_uniprot_xrefs' => $self->o('load_uniprot_xrefs'),
    'email_xref_report'  => $self->o('email_xref_report'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -parameters      => {
                            species         => $self->o('species'),
                            antispecies     => $self->o('antispecies'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            meta_filters    => $self->o('meta_filters'),
                            chromosome_flow => 0,
                            regulation_flow => 0,
                            variation_flow  => 0,
                          },
      -input_ids       => [ {} ],
      -max_retry_count => 1,
      -flow_into       => {
                            '2->A' => ['BackupTables'],
                            'A->2' => WHEN('#email_xref_report#' => ['EmailXrefReport']),
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name        => 'BackupTables',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -analysis_capacity => 5,
      -max_retry_count   => 1,
      -parameters        => {
                             table_list => [
                               'analysis',
                               'analysis_description',
                               'dependent_xref',
                               'gene',
                               'identity_xref',
                               'interpro',
                               'object_xref',
                               'ontology_xref',
                               'xref',
                             ],
                              output_file => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['ImportUniParc'],
    },

    {
      -logic_name      => 'ImportUniParc',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::ImportUniParc',
      -parameters      => {
                            uniparc_db => $self->o('local_uniparc_db'),
                          },
      -max_retry_count => 1,
      -rc_name         => '4Gb_mem_4Gb_tmp-rh7',
      -flow_into       => ['SetupUniParc'],
    },

    {
      -logic_name      => 'SetupUniParc',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count => 0,
      -parameters      => {
                            logic_name         => $self->o('checksum_logic_name'),
                            module             => $self->o('checksum_module'),
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                            db_backup_required => 1,
                            db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            delete_existing    => 1,
                            linked_tables      => ['object_xref'],
                          },
      -meadow_type     => 'LOCAL',
      -flow_into       => {
                            '1->A' => ['RemoveOrphans'],
                            'A->1' => ['LoadUniParc'],
                          },
    },

    {
      -logic_name        => 'RemoveOrphans',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -max_retry_count   => 0,
      -parameters        => {
                               sql => [
                                 'DELETE dx.* FROM '.
                                   'dependent_xref dx LEFT OUTER JOIN '.
                                   'object_xref ox USING (object_xref_id) '.
                                   'WHERE ox.object_xref_id IS NULL',
                                 'DELETE onx.* FROM '.
                                   'ontology_xref onx LEFT OUTER JOIN '.
                                   'object_xref ox USING (object_xref_id) '.
                                   'WHERE ox.object_xref_id IS NULL',
                               ]
                             },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name      => 'LoadUniParc',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniParc',
      -parameters      => {
                            uniparc_db  => $self->o('local_uniparc_db'),
                            logic_name  => $self->o('checksum_logic_name'),
                            external_db => $self->o('uniparc_external_db'),
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -rc_name         => 'normal-rh7',
      -flow_into       => WHEN('#load_uniprot#' => ['SetupUniProt']),
    },

    {
      -logic_name      => 'SetupUniProt',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count => 0,
      -parameters      => {
                            logic_name         => $self->o('uniparc_transitive_logic_name'),
                            module             => $self->o('uniparc_transitive_module'),
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                            db_backup_required => 1,
                            db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            delete_existing    => 1,
                            linked_tables      => ['object_xref'],
                          },
      -meadow_type     => 'LOCAL',
      -flow_into       => {
                            '1->A' => ['RemoveOrphans'],
                            'A->1' => ['LoadUniProt'],
                          },
    },

    {
      -logic_name      => 'LoadUniProt',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProt',
      -parameters      => {
                            uniparc_db            => $self->o('remote_uniparc_db'),
                            uniprot_db            => $self->o('remote_uniprot_db'),
                            replace_all           => $self->o('replace_all'),
                            description_source    => $self->o('description_source'),
                            overwrite_description => $self->o('overwrite_description'),
                            gene_name_source      => $self->o('gene_name_source'),
                            overwrite_gene_name   => $self->o('overwrite_gene_name'),
                            logic_name            => $self->o('uniparc_transitive_logic_name'),
                            external_dbs          => $self->o('uniprot_external_dbs'),
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -rc_name         => 'normal-rh7',
      -flow_into       => [
                            WHEN('#load_uniprot_go#'    => ['SetupUniProtGO']),
                            WHEN('#load_uniprot_xrefs#' => ['SetupUniProtXrefs']),
                          ],
    },

    {
      -logic_name      => 'SetupUniProtGO',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count => 0,
      -parameters      => {
                            logic_name         => $self->o('uniprot_transitive_logic_name'),
                            module             => $self->o('uniprot_transitive_go_module'),
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                            db_backup_required => 1,
                            db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            delete_existing    => 1,
                            linked_tables      => ['object_xref'],
                          },
      -meadow_type     => 'LOCAL',
      -flow_into       => {
                            '1->A' => ['RemoveOrphans'],
                            'A->1' => ['LoadUniProtGO'],
                          },
    },

    {
      -logic_name      => 'LoadUniProtGO',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProtGO',
      -parameters      => {
                            uniprot_db           => $self->o('remote_uniprot_db'),
                            replace_all          => $self->o('replace_all'),
                            logic_name           => $self->o('uniprot_transitive_logic_name'),
                            external_db          => $self->o('uniprot_go_external_db'),
                            uniprot_external_dbs => $self->o('uniprot_external_dbs'),
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -rc_name         => 'normal-rh7',
    },

    {
      -logic_name      => 'SetupUniProtXrefs',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count => 0,
      -parameters      => {
                            logic_name         => $self->o('uniprot_transitive_logic_name'),
                            module             => $self->o('uniprot_transitive_xref_module'),
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                            db_backup_required => 1,
                            db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            delete_existing    => 1,
                            linked_tables      => ['object_xref'],
                          },
      -meadow_type     => 'LOCAL',
      -flow_into       => {
                            '1->A' => ['RemoveOrphans'],
                            'A->1' => ['LoadUniProtXrefs'],
                          },
    },

    {
      -logic_name      => 'LoadUniProtXrefs',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProtXrefs',
      -parameters      => {
                            uniprot_db           => $self->o('remote_uniprot_db'),
                            replace_all          => $self->o('replace_all'),
                            logic_name           => $self->o('uniprot_transitive_logic_name'),
                            external_dbs         => $self->o('uniprot_xref_external_dbs'),
                            uniprot_external_dbs => $self->o('uniprot_external_dbs'),
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -rc_name         => 'normal-rh7',
    },

    {
      -logic_name      => 'EmailXrefReport',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::EmailXrefReport',
      -parameters      => {
                            email              => $self->o('email'),
                            subject            => 'Xref pipeline report for #species#',
                            db_type            => $self->o('db_type'),
                            load_uniprot       => $self->o('load_uniprot'),
                            load_uniprot_go    => $self->o('load_uniprot_go'),
                            load_uniprot_xrefs => $self->o('load_uniprot_xrefs'),
                          },
      -max_retry_count => 1,
      -rc_name         => 'normal-rh7',
    },

 ];
}

1;
