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
    interproscan_version => '5.20-59.0',
    interproscan_dir     => '/nfs/panda/ensemblgenomes/development/InterProScan',
    interproscan_exe     => catdir(
                               $self->o('interproscan_dir'),
                               $self->o('interproscan_version'),
                               'interproscan.sh'
                            ),
   	run_interproscan     => 1,
    
    # A file with md5 sums of translations that are in the lookup service
    md5_checksum_file => '/nfs/nobackup/interpro/ensembl_precalc/precalc_md5s',
    
    # Transitive GO annotation
    interpro2go_file => catdir($self->o('interproscan_dir'), 'interpro2go/2016_Sept_17/interpro2go'),
    
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
        'db_version'    => '10.0',
        'ipscan_name'   => 'PANTHER',
        'ipscan_xml'    => 'PANTHER',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'pfam',
        'db'            => 'Pfam',
        'db_version'    => '29.0',
        'ipscan_name'   => 'Pfam',
        'ipscan_xml'    => 'PFAM',
        'ipscan_lookup' => 1,
      },
      {
        'logic_name'    => 'pfscan',
        'db'            => 'Prosite_profiles',
        'db_version'    => '20.113',
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
    seg_exe        => '/nfs/panda/ensemblgenomes/external/bin/seg',
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

sub pipeline_analyses {
  my $self = shift @_;
  
  my $dump_proteome_flow;
  if ($self->o('run_seg')) {
    $dump_proteome_flow  = ['SplitDumpFile', 'PartitionByChecksum'];
  } else {
    $dump_proteome_flow  = ['PartitionByChecksum'];
  }
  
  return [
    {
      -logic_name        => 'LoadChecksums',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::LoadChecksums',
      -max_retry_count   => 1,
      -input_ids         => [ {} ],
      -parameters        => { 
                              md5_checksum_file => $self->o('md5_checksum_file'),
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => ['InterProScanPrograms'],
    },
    
    {
      -logic_name        => 'InterProScanPrograms',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::InterProScanPrograms',
      -max_retry_count   => 0,
      -parameters        => {
                              analyses => $self->o('analyses'),
                            },
      -flow_into 	       => ['SpeciesFactory'],
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
      -rc_name           => 'normal-rh7',
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
                              run_seg           => $self->o('run_seg'),
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
                                'DELETE i.*, x.* FROM '.
                                  'interpro i LEFT OUTER JOIN '.
                                  'xref x ON interpro_ac = dbprimary_acc',
                              ]
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => ['DeletePathwayXrefs'],
    },
    
    {
      -logic_name        => 'DeletePathwayXrefs',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::DeletePathwayXrefs',
      -max_retry_count   => 1,
      -parameters        => {
                              pathway_sources => $self->o('pathway_sources'),
                            },
      -rc_name           => 'normal-rh7',
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
      -rc_name           => 'normal-rh7',
      -flow_into         => $dump_proteome_flow,
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
      -rc_name           => 'normal-rh7',
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
      -rc_name           => 'normal-rh7',
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
      -rc_name           => 'normal-rh7',
    },
    
    {
      -logic_name        => 'PartitionByChecksum',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::PartitionByChecksum',
      -max_retry_count   => 0,
      -parameters        => {
                              fasta_file => '#proteome_file#',
                            },
      -rc_name           => 'normal-rh7',
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
      -rc_name           => 'normal-rh7',
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
      -rc_name           => 'normal-rh7',
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
      -rc_name           => '4Gb_mem_4Gb_tmp-rh7',
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
      -rc_name           => '4GB_4CPU-rh7',
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
      -rc_name           => '4GB_4CPU-rh7',
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
      -rc_name           => 'normal-rh7',
    },
    
    {
      -logic_name        => 'StoreGoXrefs',
      -module            => 'Bio::EnsEMBL::EGPipeline::ProteinFeatures::StoreGoXrefs',
      -hive_capacity     => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              interpro2go_file => $self->o('interpro2go_file'),
                            },
      -rc_name           => 'normal-rh7',
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
      -rc_name           => 'normal-rh7',
    },
    
  ];
}

sub resource_classes {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::resource_classes},
    '4GB_4CPU-rh7' => {'LSF' => '-q production-rh7 -n 4 -M 4000 -R "rusage[mem=4000,tmp=4000] span[hosts=1]"'},
  }
}

1;
