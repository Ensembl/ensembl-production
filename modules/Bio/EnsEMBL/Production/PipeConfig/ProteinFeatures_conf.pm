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

package Bio::EnsEMBL::EGPipeline::PipeConfig::ProteinFeatures_conf;

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

    pipeline_name => 'protein_features_'.$self->o('ensembl_release'),
    
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
    interproscan_version => '5.22-61.0',
    interproscan_exe     => 'interproscan.sh',
   	run_interproscan     => 1,
    
    # A file with md5 sums of translations that are in the lookup service
    md5_checksum_file => '/nfs/nobackup/interpro/ensembl_precalc/precalc_md5s',
    
    # Transitive GO annotation
    interpro2go_file => '/nfs/panda/ensembl/production/ensprod/interpro2go/interpro2go',
    
    # On gene tree pages you can highlight based on InterPro domain. If a
    # domain is only annotated on orthologs, and not on the current gene,
    # then the description will be missing, because it is retrieved from
    # the xref table. So, we can either load all InterPro records as xrefs
    # in every core database, or we can load all InterPro records that are
    # seen in that division.
    interpro_desc_source => 'file',  # or 'core_dbs', or undef
    
    # A file with a complete list of descriptions.
    interpro_desc_ebi_path => '/ebi/ftp/pub/databases/interpro/current',
    interpro_desc_ftp_uri  => 'ftp://ftp.ebi.ac.uk/pub/databases/interpro/current',
    interpro_desc_file     => 'names.dat',
    
    # Files for storing intermediate lists of InterPro descriptions.
    merged_file => catdir($self->o('pipeline_dir'), 'all.xrefs.txt'),
    unique_file => catdir($self->o('pipeline_dir'), 'unique.xrefs.txt'),
    
    analyses =>
    [
      {
        'logic_name'    => 'blastprodom',
        'db'            => 'ProDom',
        'db_version'    => '2006.1',
        'ipscan_name'   => 'ProDom',
        'ipscan_xml'    => 'PRODOM',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'cdd',
        'db'            => 'CDD',
        'db_version'    => '3.14',
        'ipscan_name'   => 'CDD',
        'ipscan_xml'    => 'CDD',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'gene3d',
        'db'            => 'Gene3D',
        'db_version'    => '3.5.0',
        'ipscan_name'   => 'Gene3D',
        'ipscan_xml'    => 'GENE3D',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'hamap',
        'db'            => 'HAMAP',
        'db_version'    => '201605.11',
        'ipscan_name'   => 'Hamap',
        'ipscan_xml'    => 'HAMAP',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'hmmpanther',
        'db'            => 'PANTHER',
        'db_version'    => '11.1',
        'ipscan_name'   => 'PANTHER',
        'ipscan_xml'    => 'PANTHER',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'pfam',
        'db'            => 'Pfam',
        'db_version'    => '30.0',
        'ipscan_name'   => 'Pfam',
        'ipscan_xml'    => 'PFAM',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'pfscan',
        'db'            => 'Prosite_profiles',
        'db_version'    => '20.119',
        'ipscan_name'   => 'ProSiteProfiles',
        'ipscan_xml'    => 'PROSITE_PROFILES',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'pirsf',
        'db'            => 'PIRSF',
        'db_version'    => '3.01',
        'ipscan_name'   => 'PIRSF',
        'ipscan_xml'    => 'PIRSF',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'prints',
        'db'            => 'PRINTS',
        'db_version'    => '42.0',
        'ipscan_name'   => 'PRINTS',
        'ipscan_xml'    => 'PRINTS',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'scanprosite',
        'db'            => 'Prosite_patterns',
        'db_version'    => '20.119',
        'ipscan_name'   => 'ProSitePatterns',
        'ipscan_xml'    => 'PROSITE_PATTERNS',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'sfld',
        'db'            => 'SFLD',
        'db_version'    => '2',
        'ipscan_name'   => 'SFLD',
        'ipscan_xml'    => 'SFLD',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'smart',
        'db'            => 'Smart',
        'db_version'    => '7.1',
        'ipscan_name'   => 'SMART',
        'ipscan_xml'    => 'SMART',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'superfamily',
        'db'            => 'SuperFamily',
        'db_version'    => '1.75',
        'ipscan_name'   => 'SUPERFAMILY',
        'ipscan_xml'    => 'SUPERFAMILY',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'tigrfam',
        'db'            => 'TIGRfam',
        'db_version'    => '15.0',
        'ipscan_name'   => 'TIGRFAM',
        'ipscan_xml'    => 'TIGRFAM',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'mobidblite',
        'db'            => 'MobiDBLite',
        'db_version'    => '1.0',
        'ipscan_name'   => 'MobiDBLite',
        'ipscan_xml'    => 'MOBIDB_LITE',
        'ipscan_lookup' => 0,
      },
      {
        'logic_name'    => 'ncoils',
        'db'            => 'ncoils',
        'db_version'    => '2.2.1',
        'ipscan_name'   => 'Coils',
        'ipscan_xml'    => 'COILS',
        'ipscan_lookup' => 0,
      },
      {
        'logic_name'    => 'signalp',
        'db'            => 'SignalP',
        'db_version'    => '4.1',
        'ipscan_name'   => 'SignalP_EUK',
        'ipscan_xml'    => 'SIGNALP_EUK',
        'ipscan_lookup' => 0,
      },
      {
        'logic_name'    => 'tmhmm',
        'db'            => 'TMHMM',
        'db_version'    => '2.0c',
        'ipscan_name'   => 'TMHMM',
        'ipscan_xml'    => 'TMHMM',
        'ipscan_lookup' => 0,
      },
      {
        'logic_name'    => 'seg',
        'db'            => 'Seg',
      },
      {
        'logic_name'    => 'interpro2go',
        'db'            => 'InterPro2GO',
      },
      {
        'logic_name'    => 'interpro2pathway',
        'db'            => 'InterPro2Pathway',
      },
    ],
    
    # Remove existing analyses; if =0 then existing analyses
    # will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,
    
    # Delete rows in tables connected to the existing analysis
    linked_tables => ['protein_feature', 'object_xref'],
    
    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,
    
    # Pathway data sources
    pathway_sources =>
    [
      'KEGG_Enzyme',
      'UniPathway',
    ],
    
    # seg analysis is not run as part of InterProScan, so is always run locally
    run_seg        => 1,
    seg_exe        => 'seg',
    seg_params     => '-l -n',
    
  };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  my $options = join(' ',
    $self->SUPER::beekeeper_extra_cmdline_options,
    "-reg_conf ".$self->o('registry'),
  );
  
  return $options;
}

# Ensures that species output parameter gets propagated implicitly.
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
   'interpro_desc_source' => $self->o('interpro_desc_source'),
   'run_seg'              => $self->o('run_seg'),
 };
}

sub pipeline_analyses {
  my $self = shift @_;
  
  return [
    {
      -logic_name        => 'LoadChecksums',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::LoadChecksums',
      -max_retry_count   => 1,
      -input_ids         => [ {} ],
      -parameters        => { 
                              md5_checksum_file => $self->o('md5_checksum_file'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['InterProScanPrograms'],
    },
    
    {
      -logic_name        => 'InterProScanPrograms',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::InterProScanPrograms',
      -max_retry_count   => 0,
      -parameters        => {
                              analyses => $self->o('analyses'),
                            },
      -flow_into 	       => {
                              '1->A' => ['SpeciesFactory'],
                              'A->1' => WHEN(
                                          '#interpro_desc_source# eq "file"' =>
                                            ['FetchInterPro'],
                                          '#interpro_desc_source# eq "core_dbs"' =>
                                            ['SpeciesFactoryForDumpingInterPro']
                                        ),
                            },
      -meadow_type       => 'LOCAL',
    },
    
    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              species         => $self->o('species'),
                              antispecies     => $self->o('antispecies'),
                              division        => $self->o('division'),
                              run_all         => $self->o('run_all'),
                              meta_filters    => $self->o('meta_filters'),
                              chromosome_flow => 0,
                              regulation_flow => 0,
                              variation_flow  => 0,
                            },
      -flow_into         => {
                              '2->A' => ['BackupTables'],
                              'A->2' => ['StoreGoXrefs'],
                            },
      -meadow_type       => 'LOCAL',
    },
    
    {
      -logic_name        => 'BackupTables',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -max_retry_count   => 1,
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
                              output_file => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1->A' => ['AnalysisFactory'],
                              'A->1' => ['DumpProteome'],
                            },
    },
    
    { -logic_name        => 'AnalysisFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::AnalysisFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              analyses => $self->o('analyses'),
                              run_seg  => $self->o('run_seg'),
                            },
      -flow_into         => {
                              '2->A' => ['AnalysisSetup'],
                              'A->1' => ['RemoveOrphans'],
                            },
      -meadow_type       => 'LOCAL',
    },
    
    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -parameters        => {
                              db_backup_required => 1,
                              db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                              delete_existing    => $self->o('delete_existing'),
                              linked_tables      => $self->o('linked_tables'),
                              production_lookup  => $self->o('production_lookup'),
                              production_db      => $self->o('production_db'),
                              program            => $self->o('interproscan_version'),
                            },
      -meadow_type       => 'LOCAL',
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
      -flow_into         => ['DeleteInterPro'],
      -meadow_type       => 'LOCAL',
    },
    
    {
      -logic_name        => 'DeleteInterPro',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -max_retry_count   => 0,
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
      -rc_name           => 'normal',
      -flow_into         => ['DeletePathwayXrefs'],
    },
  
    {
      -logic_name        => 'DeletePathwayXrefs',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::DeletePathwayXrefs',
      -max_retry_count   => 1,
      -parameters        => {
                              pathway_sources => $self->o('pathway_sources'),
                            },
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'DumpProteome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpProteome',
      -max_retry_count   => 0,
      -parameters        => {
                              proteome_dir => catdir($self->o('pipeline_dir'), '#species#'),
                              header_style => 'dbID',
                              overwrite    => 1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1' => WHEN('#run_seg#' =>
                                      ['SplitDumpFile', 'PartitionByChecksum'],
                                    ELSE
                                      ['PartitionByChecksum']
                                    ),
                            },
    },
    
    {
      -logic_name        => 'SplitDumpFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -max_retry_count   => 0,
      -parameters        => {
                              fasta_file              => '#proteome_file#',
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                            },
      -rc_name           => 'normal',
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
      -rc_name           => 'normal',
      -flow_into         => ['StoreSegFeatures'],
    },
    
    {
      -logic_name        => 'StoreSegFeatures',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::StoreSegFeatures',
      -analysis_capacity => 1,
      -batch_size        => 100,
      -max_retry_count   => 1,
      -parameters        => {
                              logic_name   => 'seg',
                              seg_out_file => '#split_file#.seg.txt',
                            },
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'PartitionByChecksum',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::PartitionByChecksum',
      -max_retry_count   => 0,
      -parameters        => {
                              fasta_file => '#proteome_file#',
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1' => ['SplitChecksumFile'],
                              '2' => ['SplitNoChecksumFile'],
                            },
    },
    
    {
      -logic_name        => 'SplitChecksumFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -max_retry_count   => 0,
      -parameters        => {
                              fasta_file              => '#checksum_file#',
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              delete_existing_files   => $self->o('run_interproscan'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['InterProScanLookup', 'InterProScanNoLookup'],
                            },
    },
    
    {
      -logic_name        => 'SplitNoChecksumFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -max_retry_count   => 0,
      -parameters        => {
                              fasta_file              => '#nochecksum_file#',
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              delete_existing_files   => $self->o('run_interproscan'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['InterProScanLocal'],
                            },
    },
    
    {
      -logic_name        => 'InterProScanLookup',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::InterProScan',
      -hive_capacity     => 50,
      -batch_size        => 10,
      -max_retry_count   => 1,
      -can_be_empty      => 1,
      -parameters        =>
      {
        input_file                => '#split_file#',
        run_mode                  => 'lookup',
        interproscan_exe          => $self->o('interproscan_exe'),
        interproscan_applications => '#interproscan_lookup_applications#',
        run_interproscan          => $self->o('run_interproscan'),
      },
      -rc_name           => '4Gb_mem_4Gb_tmp',
      -flow_into         => ['StoreProteinFeatures'],
    },
    
    {
      -logic_name        => 'InterProScanNoLookup',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::InterProScan',
      -hive_capacity     => 50,
      -batch_size        => 1,
      -max_retry_count   => 1,
      -can_be_empty      => 1,
      -parameters        =>
      {
        input_file                => '#split_file#',
        run_mode                  => 'nolookup',
        interproscan_exe          => $self->o('interproscan_exe'),
        interproscan_applications => '#interproscan_nolookup_applications#',
        run_interproscan          => $self->o('run_interproscan'),
      },
      -rc_name           => '4GB_4CPU',
      -flow_into         => ['StoreProteinFeatures'],
    },
    
    {
      -logic_name        => 'InterProScanLocal',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::InterProScan',
      -hive_capacity     => 50,
      -batch_size        => 1,
      -max_retry_count   => 1,
      -can_be_empty      => 1,
      -parameters        =>
      {
        input_file                => '#split_file#',
        run_mode                  => 'local',
        interproscan_exe          => $self->o('interproscan_exe'),
        interproscan_applications => '#interproscan_local_applications#',
        run_interproscan          => $self->o('run_interproscan'),
      },
      -rc_name           => '4GB_4CPU',
      -flow_into         => ['StoreProteinFeatures'],
    },
    
    {
      -logic_name        => 'StoreProteinFeatures',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::StoreProteinFeatures',
      -analysis_capacity => 1,
      -batch_size        => 250,
      -max_retry_count   => 1,
      -parameters        => {
                              analyses        => $self->o('analyses'),
                              pathway_sources => $self->o('pathway_sources'),
                            },
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'StoreGoXrefs',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::StoreGoXrefs',
      -hive_capacity     => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              interpro2go_file => $self->o('interpro2go_file'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['EmailReport'],
    },
    
    {
      -logic_name        => 'EmailReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::EmailReport',
      -hive_capacity     => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              email   => $self->o('email'),
                              subject => 'Protein features pipeline: report for #species#',
                            },
      -rc_name           => 'normal',
    },
    
    {
      -logic_name      => 'FetchInterPro',
      -module          => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::FetchInterPro',
      -hive_capacity   => 10,
      -max_retry_count => 1,
      -parameters      => {
                            interpro_desc_ebi_path => $self->o('interpro_desc_ebi_path'),
                            interpro_desc_ftp_uri  => $self->o('interpro_desc_ftp_uri'),
                            interpro_desc_file     => $self->o('interpro_desc_file'),
                            output_file            => $self->o('unique_file'),
                          },
      -rc_name         => 'normal',
      -flow_into       => ['SpeciesFactoryForStoringInterPro'],
    },
    
    {
      -logic_name      => 'SpeciesFactoryForDumpingInterPro',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -parameters      => {
                            species         => $self->o('species'),
                            antispecies     => $self->o('antispecies'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            chromosome_flow => 0,
                            regulation_flow => 0,
                            variation_flow  => 0,
                            meta_filters    => $self->o('meta_filters'),
                          },
      -max_retry_count => 1,
      -flow_into       => {
                            '2->A' => ['DumpInterProXrefs'],
                            'A->1' => ['AggregateInterProXrefs'],
                          },
      -meadow_type     => 'LOCAL',
    },
    
    {
      -logic_name      => 'DumpInterProXrefs',
      -module          => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::DumpInterProXrefs',
      -parameters      => {
                            filename => catdir($self->o('pipeline_dir'), '#species#.xrefs.txt'),
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -flow_into       => {
                            1 => [ '?accu_name=filename&accu_address=[]' ],
                          },
      -rc_name         => 'normal',
    },
    
    {
      -logic_name      => 'AggregateInterProXrefs',
      -module          => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::AggregateInterProXrefs',
      -parameters      => {
                            filenames   => '#filename#',
                            merged_file => $self->o('merged_file'),
                            unique_file => $self->o('unique_file'),
                          },
      -max_retry_count => 1,
      -rc_name         => 'normal',
      -flow_into       => ['SpeciesFactoryForStoringInterPro'],
    },
    
    {
      -logic_name      => 'SpeciesFactoryForStoringInterPro',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -parameters      => {
                            species         => $self->o('species'),
                            antispecies     => $self->o('antispecies'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            chromosome_flow => 0,
                            regulation_flow => 0,
                            variation_flow  => 0,
                            meta_filters    => $self->o('meta_filters'),
                          },
      -max_retry_count => 1,
      -flow_into       => {
                            '2' => ['StoreInterProXrefs'],
                          },
      -meadow_type     => 'LOCAL',
    },
    
    {
      -logic_name      => 'StoreInterProXrefs',
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

sub resource_classes {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::resource_classes},
    '4GB_4CPU' => {'LSF' => '-q production-rh7 -n 4 -M 4000 -R "rusage[mem=4000,tmp=4000]"'},
  }
}

1;
