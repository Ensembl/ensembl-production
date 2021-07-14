=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::ProteinFeatures_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    species      => [],
    antispecies  => [],
    division     => [],
    run_all      => 0,
    meta_filters => {},

    # Parameters for dumping and splitting Fasta protein files
    max_seqs_per_file       => 100,
    max_seq_length_per_file => undef,
    max_files_per_directory => 100,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),

    # InterPro settings
    interproscan_version      => '5.51-85.0',
    interproscan_exe          => 'interproscan.sh',
   	run_interproscan          => 1,
    local_computation         => 0,
    check_interpro_db_version => 0,

    # Load UniParc/UniProt xrefs.
    uniparc_xrefs => 0,
    uniprot_xrefs => 0,

    # We need some data files, all of which we should be able to get from the
    # local file system, because they are created by other groups at the EBI.
    # If not, the code falls back on externally-available routes.
    # From UniParc, we get a list of protein sequence md5sums, which will
    # be in the InterProScan lookup service. From InterPro, we get: a list of
    # all the entries with descriptions, which are loaded as xrefs; and a
    # mapping between InterPro and GO terms, so that we can transitively
    # annotate GO xrefs. Optionally, we may also want a mapping between
    # UniParc and UniProt IDs, in order to create UniProt xrefs.
    interpro_ebi_path => '/nfs/ftp/public/databases/interpro/current',
    interpro_ftp_uri  => 'ftp://ftp.ebi.ac.uk/pub/databases/interpro/current',
    uniparc_ebi_path  => '/nfs/ftp/public/contrib/uniparc',
    uniparc_ftp_uri   => 'ftp://ftp.ebi.ac.uk/pub/contrib/uniparc',
    uniprot_ebi_path  => '/nfs/ftp/public/databases/uniprot/current_release/knowledgebase/idmapping',
    uniprot_ftp_uri   => 'ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/idmapping',

    interpro_file    => 'names.dat',
    interpro2go_file => 'interpro2go',
    uniparc_file     => 'upidump.lis',
    mapping_file     => 'idmapping_selected.tab.gz',

    # Files are retrieved and stored locally with the same name.
    interpro_file_local    => catdir($self->o('pipeline_dir'), $self->o('interpro_file')),
    interpro2go_file_local => catdir($self->o('pipeline_dir'), $self->o('interpro2go_file')),
    uniparc_file_local     => catdir($self->o('pipeline_dir'), $self->o('uniparc_file')),
    mapping_file_local     => catdir($self->o('pipeline_dir'), $self->o('mapping_file')),
    uniprot_file_local     => catdir($self->o('pipeline_dir'), 'uniprot.txt'),

    interpro2go_logic_name => 'interpro2go',
    uniparc_logic_name     => 'uniparc_checksum',
    uniprot_logic_name     => 'uniprot_checksum',

    protein_feature_analyses =>
    [
      {
        logic_name      => 'cdd',
        db              => 'CDD',
        db_version      => '3.18',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'CDD',
        ipscan_xml      => 'CDD',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'gene3d',
        db              => 'Gene3D',
        db_version      => '4.3.0',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'Gene3D',
        ipscan_xml      => 'GENE3D',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'hamap',
        db              => 'HAMAP',
        db_version      => '2020_05',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'Hamap',
        ipscan_xml      => 'HAMAP',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'hmmpanther',
        db              => 'PANTHER',
        db_version      => '15.0',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'PANTHER',
        ipscan_xml      => 'PANTHER',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'pfam',
        db              => 'Pfam',
        db_version      => '33.1',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'Pfam',
        ipscan_xml      => 'PFAM',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'pfscan',
        db              => 'Prosite_profiles',
        db_version      => '2019_11',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'ProSiteProfiles',
        ipscan_xml      => 'PROSITE_PROFILES',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'pirsf',
        db              => 'PIRSF',
        db_version      => '3.10',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'PIRSF',
        ipscan_xml      => 'PIRSF',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'prints',
        db              => 'PRINTS',
        db_version      => '42.0',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'PRINTS',
        ipscan_xml      => 'PRINTS',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'scanprosite',
        db              => 'Prosite_patterns',
        db_version      => '2019_11',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'ProSitePatterns',
        ipscan_xml      => 'PROSITE_PATTERNS',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'sfld',
        db              => 'SFLD',
        db_version      => '4',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'SFLD',
        ipscan_xml      => 'SFLD',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'smart',
        db              => 'Smart',
        db_version      => '7.1',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'SMART',
        ipscan_xml      => 'SMART',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'superfamily',
        db              => 'SuperFamily',
        db_version      => '1.75',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'SUPERFAMILY',
        ipscan_xml      => 'SUPERFAMILY',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'tigrfam',
        db              => 'TIGRfam',
        db_version      => '15.0',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'TIGRFAM',
        ipscan_xml      => 'TIGRFAM',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'mobidblite',
        db              => 'MobiDBLite',
        db_version      => '2.0',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'MobiDBLite',
        ipscan_xml      => 'MOBIDB_LITE',
        ipscan_lookup   => 0,
      },
      {
        logic_name      => 'ncoils',
        db              => 'ncoils',
        db_version      => '2.2.1',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'Coils',
        ipscan_xml      => 'COILS',
        ipscan_lookup   => 0,
      },
      {
        logic_name      => 'signalp',
        db              => 'SignalP',
        db_version      => '4.1',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'SignalP_EUK',
        ipscan_xml      => 'SIGNALP_EUK',
        ipscan_lookup   => 0,
      },
      {
        logic_name      => 'tmhmm',
        db              => 'TMHMM',
        db_version      => '2.0c',
        program         => 'InterProScan',
        program_version => $self->o('interproscan_version'),
        ipscan_name     => 'TMHMM',
        ipscan_xml      => 'TMHMM',
        ipscan_lookup   => 0,
      },
      {
        logic_name      => 'seg',
        db              => 'Seg',
      },
    ],

    xref_analyses =>
    [
      {
        logic_name => $self->o('interpro2go_logic_name'),
        db         => 'InterPro2GO',
        annotate   => 1,
        local_file => $self->o('interpro2go_file_local'),
      },
      {
        logic_name => $self->o('uniparc_logic_name'),
        db         => 'UniParc',
        annotate   => $self->o('uniparc_xrefs'),
        local_file => $self->o('uniparc_file_local'),
      },
      {
        logic_name => $self->o('uniprot_logic_name'),
        db         => 'UniProt',
        annotate   => $self->o('uniprot_xrefs'),
        local_file => $self->o('mapping_file_local'),
      },
    ],

    # Remove existing analyses; if =0 then existing analyses
    # will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,

    # seg analysis is not part of InterProScan, so is always run locally.
    run_seg    => 1,
    seg_exe    => 'seg',
    seg_params => '-l -n',

    # Config/history files for storing record of datacheck run.
    config_file  => undef,
    history_file => undef,

    # By default the pipeline won't email with a summary of the results.
    # If this is switched on, you get one email per species.
    email_report => 0,
  };
}

# Ensures that species output parameter gets propagated implicitly.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  my $uniparc_table_sql = q/
    CREATE TABLE uniparc (
      upi VARCHAR(13) NOT NULL,
      md5sum VARCHAR(32) NOT NULL COLLATE latin1_swedish_ci
    );
  /;

  my $uniprot_table_sql = q/
    CREATE TABLE uniprot (
      acc VARCHAR(10) NOT NULL,
      upi VARCHAR(13) NOT NULL,
      tax_id INT NOT NULL
    );
  /;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('pipeline_dir'),
    $self->db_cmd($uniparc_table_sql),
    $self->db_cmd($uniprot_table_sql),
  ];
}

sub pipeline_wide_parameters {
 my ($self) = @_;

 return {
   %{$self->SUPER::pipeline_wide_parameters},
   'email_report' => $self->o('email_report'),
 };
}

sub pipeline_analyses {
  my $self = shift @_;

  return [
    {
      -logic_name      => 'InterProScanVersionCheck',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScanVersionCheck',
      -max_retry_count => 0,
      -input_ids       => [ {} ],
      -parameters      => {
                            interproscan_version => $self->o('interproscan_version'),
                            interproscan_exe     => $self->o('interproscan_exe'),
                            local_computation    => $self->o('local_computation'),
                          },
      -flow_into       => {
                            '1->A' => ['FetchFiles'],
                            'A->1' => ['DbFactory'],
                          },
    },

    {
      -logic_name      => 'FetchFiles',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -parameters      => {
                            local_computation => $self->o('local_computation'),
                          },
      -flow_into       => WHEN('#local_computation#' =>
                            ['FetchInterPro', 'FetchInterPro2GO'],
                          ELSE
                            ['FetchUniParc', 'FetchInterPro', 'FetchInterPro2GO']
                          ),
    },

    {
      -logic_name      => 'FetchInterPro',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::FetchFile',
      -max_retry_count => 1,
      -parameters      => {
                            ebi_path    => $self->o('interpro_ebi_path'),
                            ftp_uri     => $self->o('interpro_ftp_uri'),
                            remote_file => $self->o('interpro_file'),
                            local_file  => $self->o('interpro_file_local'),
                          },
      -rc_name         => 'dm',
    },

    {
      -logic_name      => 'FetchInterPro2GO',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::FetchFile',
      -max_retry_count => 1,
      -parameters      => {
                            ebi_path    => $self->o('interpro_ebi_path'),
                            ftp_uri     => $self->o('interpro_ftp_uri'),
                            remote_file => $self->o('interpro2go_file'),
                            local_file  => $self->o('interpro2go_file_local'),
                          },
      -rc_name         => 'dm',
    },

    {
      -logic_name      => 'FetchUniParc',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::FetchFile',
      -max_retry_count => 1,
      -parameters      => {
                            ebi_path      => $self->o('uniparc_ebi_path'),
                            ftp_uri       => $self->o('uniparc_ftp_uri'),
                            remote_file   => $self->o('uniparc_file'),
                            local_file    => $self->o('uniparc_file_local'),
                            uniprot_xrefs => $self->o('uniprot_xrefs'),
                          },
      -flow_into       => WHEN('#uniprot_xrefs#' =>
                            ['FetchUniProt', 'LoadUniParc'],
                          ELSE
                            ['LoadUniParc']
                          ),
      -rc_name         => 'dm',
    },

    {
      -logic_name      => 'FetchUniProt',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::FetchFile',
      -max_retry_count => 1,
      -parameters      => {
                            ebi_path    => $self->o('uniprot_ebi_path'),
                            ftp_uri     => $self->o('uniprot_ftp_uri'),
                            remote_file => $self->o('mapping_file'),
                            local_file  => $self->o('mapping_file_local'),
                          },
      -flow_into       => ['LoadUniProt'],
      -rc_name         => 'dm',
    },

    {
      -logic_name      => 'LoadUniParc',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::LoadUniParc',
      -max_retry_count => 1,
      -parameters      => {
                            uniparc_file_local => $self->o('uniparc_file_local'),
                          },
    },

    {
      -logic_name      => 'LoadUniProt',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::LoadUniProt',
      -max_retry_count => 1,
      -parameters      => {
                            mapping_file_local => $self->o('mapping_file_local'),
                            uniprot_file_local => $self->o('uniprot_file_local'),
                          },
    },

    {
      -logic_name      => 'DbFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -max_retry_count => 1,
      -parameters      => {
                            species         => $self->o('species'),
                            antispecies     => $self->o('antispecies'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            meta_filters    => $self->o('meta_filters'),
                          },
      -flow_into       => {
                            '2->A' => ['BackupTables'],
                            'A->2' => ['RunDatachecks'],
                          }
    },

    {
      -logic_name        => 'BackupTables',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DatabaseDumper',
      -max_retry_count   => 1,
      -analysis_capacity => 20,
      -parameters        => {
                              table_list  => [
                                'analysis',
                                'analysis_description',
                                'dependent_xref',
                                'interpro',
                                'object_xref',
                                'ontology_xref',
                                'protein_feature',
                                'xref',
                              ],
                              output_file => catdir($self->o('pipeline_dir'), '#dbname#', 'pre_pipeline_bkp.sql.gz'),
                            },
      -flow_into         => ['AnalysisConfiguration'],
    },

    {
      -logic_name        => 'AnalysisConfiguration',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::AnalysisConfiguration',
      -max_retry_count   => 0,
      -parameters        => {
                              protein_feature_analyses  => $self->o('protein_feature_analyses'),
                              interproscan_version      => $self->o('interproscan_version'),
                              check_interpro_db_version => $self->o('check_interpro_db_version'),
                              run_seg                   => $self->o('run_seg'),
                              xref_analyses             => $self->o('xref_analyses'),
                            },
      -flow_into 	       => {
                              '2->A' => ['AnalysisSetup'],
                              'A->3' => ['RemoveOrphans'],
                            }
    },

    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::AnalysisSetup',
      -max_retry_count   => 0,
      -analysis_capacity => 20,
      -parameters        => {
                              db_backup_required => 1,
                              db_backup_file     => catdir($self->o('pipeline_dir'), '#dbname#', 'pre_pipeline_bkp.sql.gz'),
                              delete_existing    => $self->o('delete_existing'),
                              linked_tables      => ['protein_feature', 'object_xref'],
                              production_lookup  => 1,
                            }
    },

    {
      -logic_name        => 'RemoveOrphans',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::SqlCmd',
      -max_retry_count   => 0,
      -analysis_capacity => 20,
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
      -flow_into         => ['DeleteInterPro']
    },

    {
      -logic_name        => 'DeleteInterPro',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::SqlCmd',
      -max_retry_count   => 0,
      -analysis_capacity => 20,
      -parameters        => {
                              sql => [
                                'DELETE i.* FROM interpro i '.
                                  'LEFT OUTER JOIN protein_feature pf ON i.id = pf.hit_name '.
                                  'WHERE pf.hit_name IS NULL ',
                                'DELETE x.* FROM xref x '.
                                  'INNER JOIN external_db edb USING (external_db_id) '.
                                  'LEFT OUTER JOIN interpro i ON x.dbprimary_acc = i.interpro_ac '.
                                  'WHERE edb.db_name = "Interpro" '.
                                  'AND i.interpro_ac IS NULL ',
                              ]
                            },
      -flow_into         => {
                              '1->A' => ['SpeciesFactory'],
                              'A->1' => ['StoreGoXrefs'],
                            },
    },

    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbAwareSpeciesFactory',
      -max_retry_count   => 1,
      -analysis_capacity => 20,
      -parameters        => {},
      -flow_into         => {
                              '2' => ['DumpProteome'],
                            }
    },

    {
      -logic_name        => 'DumpProteome',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DumpProteome',
      -max_retry_count   => 0,
      -analysis_capacity => 20,
      -parameters        => {
                              proteome_dir => catdir($self->o('pipeline_dir'), '#species#'),
                              header_style => 'dbID',
                              overwrite    => 1,
                            },
      -rc_name           => '4GB',
      -flow_into         => {
                             '-1' => ['DumpProteome_HighMem'],
                              '1' => WHEN('#run_seg#' =>
                                      ['SplitDumpFile', 'ChecksumProteins'],
                                    ELSE
                                      ['ChecksumProteins']
                                    ),
                            },
    },

    {
      -logic_name        => 'DumpProteome_HighMem',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DumpProteome',
      -max_retry_count   => 0,
      -analysis_capacity => 20,
      -parameters        => {
                              proteome_dir => catdir($self->o('pipeline_dir'), '#species#'),
                              header_style => 'dbID',
                              overwrite    => 1,
                            },
      -rc_name           => '8GB',
      -flow_into         => {
                              '1' => WHEN('#run_seg#' =>
                                      ['SplitDumpFile', 'ChecksumProteins'],
                                    ELSE
                                      ['ChecksumProteins']
                                    ),
                            },
    },

    {
      -logic_name        => 'SplitDumpFile',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::FastaSplit',
      -max_retry_count   => 0,
      -analysis_capacity => 50,
      -parameters        => {
                              fasta_file              => '#proteome_file#',
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                            },
      -flow_into         => {
                              '2' => ['RunSeg'],
                            },
    },

    {
      -logic_name        => 'RunSeg',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -max_retry_count   => 1,
      -parameters        =>
      {
        cmd => $self->o('seg_exe').' #split_file# '.$self->o('seg_params').' > #split_file#.seg.txt',
      },
      -flow_into         => ['StoreSegFeatures'],
    },

    {
      -logic_name        => 'StoreSegFeatures',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::StoreSegFeatures',
      -analysis_capacity => 1,
      -batch_size        => 100,
      -max_retry_count   => 1,
      -parameters        => {
                              logic_name   => 'seg',
                              seg_out_file => '#split_file#.seg.txt',
                            },
    },

    {
      -logic_name        => 'ChecksumProteins',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::ChecksumProteins',
      -analysis_capacity => 50,
      -max_retry_count   => 0,
      -parameters        => {
                              fasta_file         => '#proteome_file#',
                              uniparc_xrefs      => $self->o('uniparc_xrefs'),
                              uniprot_xrefs      => $self->o('uniprot_xrefs'),
                              uniparc_logic_name => $self->o('uniparc_logic_name'),
                              uniprot_logic_name => $self->o('uniprot_logic_name'),
                            },
      -flow_into         => {
                              '3' => ['SplitChecksumFile'],
                              '4' => ['SplitNoChecksumFile'],
                            },
    },

    {
      -logic_name        => 'SplitChecksumFile',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::FastaSplit',
      -analysis_capacity => 50,
      -max_retry_count   => 0,
      -parameters        => {
                              fasta_file              => '#checksum_file#',
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              delete_existing_files   => $self->o('run_interproscan'),
                            },
      -flow_into         => {
                              '2' => ['InterProScanLookup', 'InterProScanNoLookup'],
                            },
    },

    {
      -logic_name        => 'SplitNoChecksumFile',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::FastaSplit',
      -analysis_capacity => 50,
      -max_retry_count   => 0,
      -parameters        => {
                              fasta_file              => '#nochecksum_file#',
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              delete_existing_files   => $self->o('run_interproscan'),
                            },
      -flow_into         => {
                              '2' => ['InterProScanLocal'],
                            },
    },

    {
      -logic_name        => 'InterProScanLookup',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
      -hive_capacity     => 200,
      -max_retry_count   => 1,
      -parameters        =>
      {
        input_file                => '#split_file#',
        run_mode                  => 'lookup',
        interproscan_exe          => $self->o('interproscan_exe'),
        interproscan_applications => '#interproscan_lookup_applications#',
        run_interproscan          => $self->o('run_interproscan'),
      },
      -rc_name           => '4GB',
      -flow_into         => {
                               '3' => ['StoreProteinFeatures'],
                              '-1' => ['InterProScanLookup_HighMem'],
                            },
    },

    {
      -logic_name        => 'InterProScanLookup_HighMem',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
      -hive_capacity     => 200,
      -max_retry_count   => 1,
      -parameters        =>
      {
        input_file                => '#split_file#',
        run_mode                  => 'lookup',
        interproscan_exe          => $self->o('interproscan_exe'),
        interproscan_applications => '#interproscan_lookup_applications#',
        run_interproscan          => $self->o('run_interproscan'),
      },
      -rc_name           => '16GB',
      -flow_into         => {
                               '3' => ['StoreProteinFeatures'],
                            },
    },

    {
      -logic_name        => 'InterProScanNoLookup',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
      -hive_capacity     => 200,
      -max_retry_count   => 1,
      -parameters        =>
      {
        input_file                => '#split_file#',
        run_mode                  => 'nolookup',
        interproscan_exe          => $self->o('interproscan_exe'),
        interproscan_applications => '#interproscan_nolookup_applications#',
        run_interproscan          => $self->o('run_interproscan'),
      },
      -rc_name           => '4GB_4CPU',
      -flow_into         => {
                               '3' => ['StoreProteinFeatures'],
                              '-1' => ['InterProScanNoLookup_HighMem'],
                            },
    },

    {
      -logic_name        => 'InterProScanNoLookup_HighMem',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
      -hive_capacity     => 200,
      -max_retry_count   => 1,
      -parameters        =>
      {
        input_file                => '#split_file#',
        run_mode                  => 'nolookup',
        interproscan_exe          => $self->o('interproscan_exe'),
        interproscan_applications => '#interproscan_nolookup_applications#',
        run_interproscan          => $self->o('run_interproscan'),
      },
      -rc_name           => '16GB_4CPU',
      -flow_into         => {
                               '3' => ['StoreProteinFeatures'],
                            },
    },

    {
      -logic_name        => 'InterProScanLocal',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
      -hive_capacity     => 200,
      -max_retry_count   => 1,
      -parameters        =>
      {
        input_file                => '#split_file#',
        run_mode                  => 'local',
        interproscan_exe          => $self->o('interproscan_exe'),
        interproscan_applications => '#interproscan_local_applications#',
        run_interproscan          => $self->o('run_interproscan'),
      },
      -rc_name           => '4GB_4CPU',
      -flow_into         => {
                               '3' => ['StoreProteinFeatures'],
                               '0' => ['InterProScanLocal_HighMem'],
                            },
    },

    {
      -logic_name        => 'InterProScanLocal_HighMem',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
      -hive_capacity     => 200,
      -max_retry_count   => 1,
      -parameters        =>
      {
        input_file                => '#split_file#',
        run_mode                  => 'local',
        interproscan_exe          => $self->o('interproscan_exe'),
        interproscan_applications => '#interproscan_local_applications#',
        run_interproscan          => $self->o('run_interproscan'),
      },
      -rc_name           => '32GB_4CPU',
      -flow_into         => {
                               '3' => ['StoreProteinFeatures'],
                            },
    },

    {
      -logic_name        => 'StoreProteinFeatures',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::StoreProteinFeatures',
      -analysis_capacity => 10,
      -batch_size        => 50,
      -max_retry_count   => 1,
      -parameters        => {
                              analyses => $self->o('protein_feature_analyses')
                            },
      -flow_into         => {
                              '-1' => ['StoreProteinFeatures_HighMem'],
                            },
    },
    
    {
      -logic_name        => 'StoreProteinFeatures_HighMem',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::StoreProteinFeatures',
      -analysis_capacity => 10,
      -batch_size        => 50,
      -max_retry_count   => 1,
      -parameters        => {
                              analyses => $self->o('protein_feature_analyses')
                            },
      -rc_name           => '4GB',
    },

    {
      -logic_name        => 'StoreGoXrefs',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::StoreGoXrefs',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              interpro2go_file => $self->o('interpro2go_file_local'),
                              logic_name       => $self->o('interpro2go_logic_name')
                            },
      -flow_into         => ['StoreInterProXrefs'],
    },

    {
      -logic_name        => 'StoreInterProXrefs',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::SqlCmd',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              sql =>
                              [
                                'CREATE TEMPORARY TABLE tmp_xref (acc VARCHAR(255), description VARCHAR(255))',
                                "LOAD DATA LOCAL INFILE '".$self->o('interpro_file_local')."' INTO TABLE tmp_xref",
                                'INSERT IGNORE INTO xref (external_db_id, dbprimary_acc, display_label, version, description, info_type) SELECT external_db_id, acc, acc, 0, tmp_xref.description, "DIRECT" FROM tmp_xref, external_db WHERE db_name = "Interpro"',
                                'DROP TEMPORARY TABLE tmp_xref',
                              ],
                            },
    },

    {
      -logic_name        => 'RunDatachecks',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              datacheck_names  => ['ForeignKeys', 'PepstatsAttributes'],
                              datacheck_groups => ['protein_features'],
                              config_file      => $self->o('config_file'),
                              history_file     => $self->o('history_file'),
                              failures_fatal   => 1,
                            },
      -flow_into         => WHEN('#email_report#' => ['EmailReport']),
    },

    {
      -logic_name        => 'EmailReport',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::EmailReport',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              email   => $self->o('email'),
                              subject => 'Protein features pipeline: report for #dbname#',
                            },
    },
  ];
}

sub resource_classes {
  my ($self) = @_;

  return {
    %{$self->SUPER::resource_classes},
     '4GB_4CPU' => {'LSF' => '-q '.$self->o('production_queue').' -n 4 -M  4000 -R "rusage[mem=4000]"'},
    '16GB_4CPU' => {'LSF' => '-q '.$self->o('production_queue').' -n 4 -M 16000 -R "rusage[mem=16000]"'},
    '32GB_4CPU' => {'LSF' => '-q '.$self->o('production_queue').' -n 4 -M 32000 -R "rusage[mem=32000]"'},
  }
}

1;
