
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

Bio::EnsEMBL::EGPipeline::PipeConfig::Xref_VB_conf

=head1 DESCRIPTION

Load VectorBase community-submitted xrefs.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::Xref_VB_conf;

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

    pipeline_name => 'xref_vb_' . $self->o('ensembl_release'),

    species      => [],
    division     => [],
    run_all      => 0,
    antispecies  => [],
    meta_filters => {},
    db_type      => 'core',

    sheet_url    => 'https://docs.google.com/spreadsheets/d',
    sheet_format => 'export?exportFormat=tsv',
    sheet_keys   => {
      'aedes_aegypti'             => '1D6Ax2HJyWcnukIkPu2Zio7hZ_ajQiZbvzfb1DfINLwo',
      'aedes_albopictus'          => '1T8nVia4ATqIZKNi8FbMR9ikvEb9JDxGTppgkTUfLw3Q',
      'anopheles_albimanus'       => '1IkszmWkEzJ5lTHw6ugOSGFV_0soguBIoTPOh7-CE51o',
      'anopheles_arabiensis'      => '1a5OtCuDUGxbrg_0rMcbDQHUHXtwbzO_g9vTm_K896UY',
      'anopheles_atroparvus'      => '1oxUeyJVjzrq4oe5LlVqHzEGB1Hd2_7_75sCGuWxEkT0',
      'anopheles_christyi'        => '1QqhBJB4vlArR9jwaQvYSbxVGnljPRuBWQvUqLmibr7U',
      'anopheles_coluzzii'        => '1Qc7GVQO4OXIPBuiIzITDPzjbKffsnobBg7s2NmeCr7Q',
      'anopheles_culicifacies'    => '1Y9FjfL5bYHHSgDx26sRLLCMNVIlqqyT6T_ny9n0XKwQ',
      'anopheles_darlingi'        => '1dcOTVBAAtfV1Vksekr1BOZ0NKxUl8zqWiz12ULmQ2hQ',
      'anopheles_dirus'           => '1haqU3Z0pctX3G1sMhVb8lk0GDtEvGObmODEcFwqMJwE',
      'anopheles_epiroticus'      => '1US2FOLzgg1lXVkcmvFItp-wrQJ63FAISNfv63cMFdvc',
      'anopheles_farauti'         => '1haKWlsjUJrKq9wsHnbMD72NwSlFsw1J_aeYsDBf-NpA',
      'anopheles_funestus'        => '1u8cMMKSvwAn7Hm6NW6iELDHbxUc38K41buAySCtqdRo',
      'anopheles_gambiae'         => '1YbJ0JbFWnXhnDqGy63NQJIbkvjjg3Uuq1MoL5xF2_Oc',
      'anopheles_maculatus'       => '10m31MlBGhlSysA8vsrKxjz_2PcSuCUt4FdWVJ8myHP8',
      'anopheles_melas'           => '1_p3WGzyH6Q0XW6c-POXqvGrALPUxGILqTR3qmovQXEg',
      'anopheles_merus'           => '17qjOAt7UwqZkL3QOvYnNBUzYAeKS5pVTbc8wIycUjGE',
      'anopheles_minimus'         => '1JhOKWHOAcAVkCzjkT_yDK8FNslBu5wiiadIle_jGu40',
      'anopheles_quadriannulatus' => '1jWDRiITV3_XP14CKfNogbDzADQCf3nctZzJKKMNmqUg',
      'anopheles_sinensis'        => '1NQL-9mmykZ0fWls6405mhCKSxIVfE2kvxaFRogb1tXY',
      'anopheles_stephensi'       => '1ZVMIQ_tr3zJBMuk-KdUcEXSIqVOjL8jANc_SKqQAlkU',
      'biomphalaria_glabrata'     => '1PPSMgx2-z6CPa4Cit5Kh1IUCa9i7Z6Rpnv4H5ks38UA',
      'culex_quinquefasciatus'    => '1_6KHioJdjHYroDooP48FavcclKs1D2vqxPZvJzcTq_U',
      'glossina_austeni'          => '1VWQ8g_JXkz8L4XLvJJ5AVGwjhr4NP5am25-DUtJcjc0',
      'glossina_brevipalpis'      => '1n8LzP0VOEUbgsFtkr2rX6FJNUEfr9CGCfKikrI0WdVo',
      'glossina_fuscipes'         => '131u1wnBlJaIlbLbmih2zu2q1lCZhPFK3oNfo9LD5gY0',
      'glossina_morsitans'        => '1OytW4SzLunXCphzrX_mz6CwIsfn-zIzrt8eYmy6nbBk',
      'glossina_pallidipes'       => '1qh1tGOHr21wKHSq6r6JwNNLE-x1K4x7kDxSEXULpaus',
      'glossina_palpalis'         => '1hRRFAQC6YJTxJAPDe5SuF0-I7se4jgicfPkcXPVU86E',
      'ixodes_scapularis'         => '10hoIT-Zhsk1byeB5nissrbPeKXGKO5ODt0rPwTzk8fY',
      'lutzomyia_longipalpis'     => '1COtYQkfRVbbAzKKNDuJgiQuebivOZbmf_z2RJJSoCJE',
      'musca_domestica'           => '1ZNXGtXI_6L_qJjz8iMt02vNCFVdlD4Z0iisSqM2hw1A',
      'pediculus_humanus'         => '1WeBgVThFg8mW8-xrqtfMSWmSEGk9iwKi-8RWZDTucEg',
      'phlebotomus_papatasi'      => '1qH5OdX08naKPWK21Eow7_l3K7CkoTy8MgtLX835rFPM',
      'rhodnius_prolixus'         => '1ZDgS4pOzhKIwtS8h5Ho-Yxot1iZGu_9RWi-EWrJdWA4',
      'sarcoptes_scabiei'         => '1pUcRMAx2Ua21j87owwrowN9S5JMcZvAdrmfaY2piKEo',
      'stomoxys_calcitrans'       => '1xIVpy1SH4r7eyx4QB9gtQm091AEp2UBbKrWVG6N_qsc',
    },

    logic_name => 'vb_community_annotation',
    module     => 'Bio::EnsEMBL::EGPipeline::Xref::LoadVBCommunityAnnotations',

    vb_external_db       => 'VB_Community_Annotation',
    citation_external_db => 'PUBMED',

    # Exclude genes which come from sources with names and descriptions already
    exclude_logic_name => [
      'mirbase_gene',
      'rfam_12.1_gene',
      'trnascan_gene',
    ],
    
    description_blacklist => ['Uncharacterized protein', 'AGAP\d.*', 'AAEL\d.*'],
    
    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,

    # Entries in the xref table that are not linked to other tables
    # via a foreign key relationship are deleted by default.
    delete_unattached_xref => 1,

    # By default, an email is sent for each species when the pipeline
    # is complete, showing the breakdown of xrefs assigned.
    email_xref_report => 1,

    # Default capacity is low, to limit strain on our db servers.
    hive_capacity => 10,
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
    $self->db_cmd("CREATE TABLE gene_descriptions (species varchar(100) NOT NULL, db_name varchar(100) NOT NULL, total int NOT NULL, timing varchar(10))"),
    $self->db_cmd("CREATE TABLE gene_names (species varchar(100) NOT NULL, db_name varchar(100) NOT NULL, total int NOT NULL, timing varchar(10))"),
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    'db_type'                => $self->o('db_type'),
    'delete_unattached_xref' => $self->o('delete_unattached_xref'),
    'email_xref_report'      => $self->o('email_xref_report'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -input_ids       => [ {} ],
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
      -max_retry_count => 1,
      -flow_into       => {
                            '2->A' => ['RunPipeline'],
                            'A->2' => ['FinishingTouches'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'RunPipeline',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -flow_into       => {
                            '1->A' => WHEN('#email_xref_report#' => ['NamesAndDescriptionsBefore']),
                            'A->1' => ['BackupTables'],
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
      -flow_into         => ['AnalysisSetup']
    },

    {
      -logic_name      => 'AnalysisSetup',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count => 0,
      -parameters      => {
                            logic_name         => $self->o('logic_name'),
                            module             => $self->o('module'),
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
                            'A->1' => ['LoadVBCommunityAnnotations'],
                          },
    },

    {
      -logic_name      => 'LoadVBCommunityAnnotations',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::LoadVBCommunityAnnotations',
      -max_retry_count => 0,
      -parameters      => {
                            sheet_url            => $self->o('sheet_url'),
                            sheet_format         => $self->o('sheet_format'),
                            sheet_keys           => $self->o('sheet_keys'),
                            pipeline_dir         => $self->o('pipeline_dir'),
                            logic_name           => $self->o('logic_name'),
                            vb_external_db       => $self->o('vb_external_db'),
                            citation_external_db => $self->o('citation_external_db'),
                            exclude_logic_name   => $self->o('exclude_logic_name'),
                          },
      -max_retry_count => 1,
      -hive_capacity   => $self->o('hive_capacity'),
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'RemoveOrphans',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -max_retry_count => 0,
      -parameters      => {
                             sql => [
                               'DELETE dx.* FROM '.
                                 'dependent_xref dx LEFT OUTER JOIN '.
                                 'object_xref ox USING (object_xref_id) '.
                                 'WHERE ox.object_xref_id IS NULL',
                               'DELETE onx.* FROM '.
                                 'ontology_xref onx LEFT OUTER JOIN '.
                                 'object_xref ox USING (object_xref_id) '.
                                 'WHERE ox.object_xref_id IS NULL',
                               'UPDATE gene g LEFT OUTER JOIN '.
                                 'xref x ON g.display_xref_id = x.xref_id '.
                                 'SET g.display_xref_id = NULL '.
                                 'WHERE x.xref_id IS NULL',
                             ]
                           },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'FinishingTouches',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -flow_into       => {
                            '1->A' => WHEN('#delete_unattached_xref#' => ['DeleteUnattachedXref']),
                            'A->1' => ['SetupXrefReport'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'DeleteUnattachedXref',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::DeleteUnattachedXref',
      -max_retry_count => 0,
      -parameters      => {},
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'SetupXrefReport',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -flow_into       => {
                            '1->A' => WHEN('#email_xref_report#' => ['NamesAndDescriptionsAfter']),
                            'A->1' => WHEN('#email_xref_report#' => ['EmailXrefReport']),
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'NamesAndDescriptionsBefore',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::NamesAndDescriptions',
      -max_retry_count => 0,
      -parameters      => {
                            timing => 'before',
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2' => ['?table_name=gene_descriptions'],
                            '3' => ['?table_name=gene_names'],
                          }
    },

    {
      -logic_name      => 'NamesAndDescriptionsAfter',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::NamesAndDescriptions',
      -max_retry_count => 0,
      -parameters      => {
                            timing => 'after',
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2' => ['?table_name=gene_descriptions'],
                            '3' => ['?table_name=gene_names'],
                          }
    },

    {
      -logic_name      => 'EmailXrefReport',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::EmailXrefVBReport',
      -parameters      => {
                            email                => $self->o('email'),
                            subject              => 'Xref (VB) pipeline report for #species#',
                            db_type              => $self->o('db_type'),
                            logic_name           => $self->o('logic_name'),
                            vb_external_db       => $self->o('vb_external_db'),
                            citation_external_db => $self->o('citation_external_db'),
                          },
      -max_retry_count => 1,
      -rc_name         => 'normal',
    },
 ];
}

1;
