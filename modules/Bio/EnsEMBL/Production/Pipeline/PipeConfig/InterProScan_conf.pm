=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Hive::PipeConfig::InterProScan_conf

=head1 DESCRIPTION

=head1 AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::InterProScan_conf; 

use strict;
use warnings;
use File::Spec::Functions qw(catdir);
use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub default_options {
  my ($self) = @_;

  return {
    ## inherit other stuff from the base class
    %{ $self->SUPER::default_options() },

    ## General parameters
    'pipeline_name' => $self->o('hive_dbname'),

    #  Set to '0' if want to skip this analysis
    #  default => ON (1)
    'flag_Interpro2GoLoader'  => '1',

    #  seg analysis is not run as part of InterProScan, so is always run locally
    #  Set to '0' if want to skip this analysis
    #  default => ON (1)
    'flag_Seg' => '1',

    ## 'job_factory' parameters
    'species'       => [],
    'antispecies'   => [],
    'division'      => [],
    'run_all'       => 0,
    'meta_filters'  => {},

    ## 'load_md5' parameters
    #   A file with md5 sums of translations that are in the lookup service.
    #   This file is provided and maintained by InterPro and helps us limit
    #   our queries to their public service.
    'md5_checksum_file' => '/nfs/nobackup/interpro/ensembl_precalc/precalc_md5s',

    ## 'backup_tables' parameters
    #   List of tables to be backed up
    'dump_tables' => ['analysis','analysis_description','interpro','protein_feature','xref','object_xref','ontology_xref','dependent_xref'],

    ## 'load_xrefs' parameters
    'oracle_home' => '/sw/arch/dbtools/oracle/product/11.1.0.6.2/client',

    ## 'cleanup_prot_feature' parameters
    #   Species exclusion list for Interpro2Go if the analysis is turn 'ON'
    'exclusion'  => [],

    ## 'analysis_setup' parameters
    #   Remove existing analyses;
    #   default => ON (1)
    #   if 'OFF' then existing analyses will remain,
    #   with the logic_name suffixed by '_bkp'.
    'delete_existing' => 1,
 
    #   Delete rows in tables connected to the existing analysis (via analysis_id)
    'linked_tables' => ['analysis_description', 'protein_feature', 'object_xref'],

    #   Retrieve analsysis descriptions from the production database;
    #   the supplied registry file will need the relevant server details.
    #   The Production database is also used to retrieve the list of
    #   coding biotypes in DumpProteome.
    'production_lookup' => 1,

    ## 'prepipeline_checks' parameters
    'required_externalDb' => [
      'KEGG_Enzyme',
      'MetaCyc',
      'UniPathWay',
    ],

    ## 'dump_proteome' parameters
    #   If set, dumped proteome (in pipeline_dir) will always be overwritten
    #   default => ON (1)
    'overwrite' => 1,

    ## 'meta_table_update' parameters
    #   Information to update 'meta' table
    'interproscan_version' => '5.19-58.0',
    'interproscan_date'    => '9-June-2016',
    'interpro_version'     => '58',

    ## 'split_fasta' & 'split_md5_fasta' & 'split_no_md5_fasta'  parameters
    #   Parameters for dumping and splitting Fasta protein files:
    #   Maximum number of sequences in a file
    'max_seqs_per_file'       => 100,
    #   Maximum sequence length in a file
    'max_seq_length_per_file' => undef,
    #   Maximum number of files in a directory
    'max_files_per_directory' => 1000,
    'max_dirs_per_directory'  => $self->o('max_files_per_directory'),

    ## 'run_Seg' & 'store_Seg_feat' parameters
    #   Flag -l shows only low-complexity segments (fasta format)
    #   Flag -n does not add complexity information to the header line
    'seg_exe'        => '/nfs/panda/ensemblgenomes/external/bin/seg',
    'seg_params'     => '-l -n',
    'seg_logic_name' => 'seg',

    ## 'run_InterProScan_lookup' & 'run_InterProScan_nolookup' & 'run_InterProScan_local' parameters
    # Release 9 June 2016, InterProScan 5:version 5.19-58 using InterPro version 58.0 data
	'interproscan_exe' => '/nfs/panda/ensemblgenomes/development/InterProScan/interproscan-5.19-58.0/interproscan.sh',

    # Unused applications:
    # SignalP-GRAM_POSITIVE-4.0 SignalP-GRAM_NEGATIVE-4.0
    'interproscan_lookup_applications' =>
    [
      'PrositePatterns', # scanprosite
      'ProDom',          # blastprodom
      'Gene3d',          # gene3d
      'Panther',         # hmmpanther
      'SMART',           # smart
      'PRINTS',          # prints
      'PFAM',            # pfam (previously PfamA)
      'TIGRFAM',         # tigrfam
      'PrositeProfiles', # pfscan
      'PIRSF',           # pirsf
      'SuperFamily',     # superfamily
      'Hamap',		     # hamap
    ],

    'interproscan_nolookup_applications' =>
    [
      'SignalP_EUK',     # signalp (previously SignalP-EUK)
      'Coils',           # ncoils
      'TMHMM',           # tmhmm
    ],

    'interproscan_local_applications' =>
    [
      'PrositePatterns', # scanprosite
      'ProDom',          # blastprodom
      'Gene3d',          # gene3d
      'Panther',         # hmmpanther
      'SMART',           # smart
      'PRINTS',          # prints
      'PFAM',            # pfam
      'TIGRFAM',         # tigrfam
      'PrositeProfiles', # pfscan
      'PIRSF',           # pirsf
      'SuperFamily',     # superfamily
      'SignalP_EUK',     # signalp
      'Coils',           # ncoils
      'TMHMM',           # tmhmm
      'Hamap',		     # hamap
    ],

    ## 'store_features' parameters
    #    Runs extra checks when parsing the tsv files.
    #    ?? Not used in the module ??
    'validating_parser' => 1,

    ## 'load_InterPro2Go' parameters
    #   Release 4 June 2016 (http://www.geneontology.org/external2go/interpro2go)
    'interpro2go' =>  '/nfs/panda/ensemblgenomes/development/InterProScan/interpro2go/2016_June_4/interpro2go',

    #   Check if GO annotation exists from other sources before loading
    #   default => OFF (0)
    'flag_check_annot_exists' => '0',

    ## 'pipeline_cleanup' parameters
    #   If set, the pipeline_dir directory will be deleted.
    #   NOTE that all the table backups are stored here, so will be deleted as well
    #   ! For job seeding, better leave the option as default
    #   default => OFF (0)
    'delete_pipeline_dir_at_cleanup' => 0,

    ## 'analysis_setup_factory' & 'prepipeline_checks' parameters
    #  This Array of hashes is supplied to the 'AnalysisSetup' Runnable to
    #  update analysis & analysis_description table
    #
    #  The PrePipelineCheck stage will check, if the analysis table has
    #  analyses with these logic names in it. If not, the pipeline will not run.
    #
    #  A list of all analyses can be found by running interproscan.sh
    #  without parameters or experimentally by running:
    #
    #  Warning! Protein features attached to these analyses are deleted
    #  from the protein_feature tables and replaced by the results of the i5 runs.
    'required_analysis' =>
    [
      {
        'logic_name'    => 'cdd',
        'db'            => 'CDD',
        'db_version'    => '3.14',
      },
      {
        'logic_name'    => 'blastprodom',
        'db'            => 'ProDom',
        'db_version'    => '2006.1',
      },
      {
        'logic_name'    => 'gene3d',
        'db'            => 'Gene3D',
        'db_version'    => '3.5.0',
      },
      {
        'logic_name'    => 'hamap',
        'db'            => 'HAMAP',
        'db_version'    => '201605.11',
      },
      {
        'logic_name'    => 'hmmpanther',
        'db'            => 'PANTHER',
        'db_version'    => '10.0',
      },
      {
        'logic_name'    => 'pfam',
        'db'            => 'Pfam',
        'db_version'    => '29.0',
      },
      {
        'logic_name'    => 'pfscan',
        'db'            => 'Prosite_profiles',
        'db_version'    => '20.119',
      },
      {
        'logic_name'    => 'pirsf',
        'db'            => 'PIRSF',
        'db_version'    => '3.01',
      },
      {
        'logic_name'    => 'prints',
        'db'            => 'PRINTS',
        'db_version'    => '42.0',
      },
      {
        'logic_name'    => 'scanprosite',
        'db'            => 'Prosite_patterns',
        'db_version'    => '20.119',
      },
      {
        'logic_name'    => 'smart',
        'db'            => 'Smart',
        'db_version'    => '7.1',
      },
      {
        'logic_name'    => 'superfamily',
        'db'            => 'Superfamily',
        'db_version'    => '1.75',
      },
      {
        'logic_name'    => 'tigrfam',
        'db'            => 'TIGRfam',
        'db_version'    => '15.0',
      },
      {
        'logic_name'    => 'ncoils',
        'db'            => 'ncoils',
        'db_version'    => undef,
      },
      {
        'logic_name'    => 'signalp',
        'db'            => 'SignalP',
        'db_version'    => undef,
      },
      {
        'logic_name'    => 'tmhmm',
        'db'            => 'Tmhmm',
        'db_version'    => undef,
      },
      {
        'logic_name'    => 'seg',
        'db'            => 'Seg',
        'db_version'    => undef,
      },
      {
        'logic_name'    => 'interpro2go',
        'db'            => 'InterPro2GO',
        'db_version'    => undef,
      },
      {
        'logic_name'    => 'interpro2pathway',
        'db'            => 'InterPro2Pathway',
        'db_version'    => undef,
      },
    ],

    #  Access to the prod db is sometimes useful, and since the location/name
    #  doesn't change we might as well have a default.
    'production_db' => {
      -driver => $self->o('hive_driver'),
      -host   => 'mysql-eg-pan-prod.ebi.ac.uk',
      -port   => 4276,
      -user   => 'ensro',
      -pass   => '',
      -group  => 'production',
      -dbname => 'ensembl_production',
    },      

    # Don't fall over if someone uses 'hive_pass' instead of 'hive_password'
    hive_password => $self->o('hive_pass'),

    'pipeline_db' => {
        -host   => $self->o('hive_host'),
        -port   => $self->o('hive_port'),
        -user   => $self->o('hive_user'),
        -pass   => $self->o('hive_password'),
        -dbname => $self->o('hive_dbname'),
        -driver => 'mysql',
      },      
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('pipeline_dir'),

  ];
}

# Ensures species output parameter gets propagated implicitly
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  return
    ' -reg_conf ' . $self->o('registry')
  ;
}

sub pipeline_analyses {
  my $self = shift @_;

  my $flow_dump_proteome;
  my $flow_cleanup_prot_feat;
  my $waitfor_cleanup_prot_feat;
  my $waitfor_pipeline_cleanup;

  if ($self->o('flag_Interpro2GoLoader') && $self->o('flag_Seg')) {
     $flow_dump_proteome             = ['split_fasta', 'split_fasta_by_md5'];
     $flow_cleanup_prot_feat         = ['load_InterPro2Go'];
     $waitfor_cleanup_prot_feat      = ['dump_proteome', 'store_Seg_feat', 'store_features', 'run_InterProScan_lookup', 'run_InterProScan_nolookup', 'run_InterProScan_local'];
     $waitfor_pipeline_cleanup       = ['load_InterPro2Go', 'cleanup_prot_feat'];
  }
  elsif ($self->o('flag_Interpro2GoLoader')) {
     $flow_dump_proteome             = ['split_fasta_by_md5'];
     $flow_cleanup_prot_feat         = ['load_InterPro2Go'];
     $waitfor_cleanup_prot_feat      = ['dump_proteome', 'store_features', 'run_InterProScan_lookup', 'run_InterProScan_nolookup', 'run_InterProScan_local'];
     $waitfor_pipeline_cleanup       = ['load_InterPro2Go', 'cleanup_prot_feat'];
  }
  elsif ($self->o('flag_Seg')) {
     $flow_dump_proteome             = ['split_fasta', 'split_fasta_by_md5'];
     $waitfor_cleanup_prot_feat      = ['dump_proteome', 'store_Seg_feat', 'store_features', 'run_InterProScan_lookup', 'run_InterProScan_nolookup', 'run_InterProScan_local'];
     $waitfor_pipeline_cleanup       = ['cleanup_prot_feat'];
  }
  else {
     $flow_dump_proteome             = ['split_fasta_by_md5'];
     $waitfor_cleanup_prot_feat      = ['dump_proteome', 'store_features', 'run_InterProScan_lookup', 'run_InterProScan_nolookup', 'run_InterProScan_local'];
     $waitfor_pipeline_cleanup       = ['cleanup_prot_feat'];
  }

  return [
    { -logic_name      => 'load_md5',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::LoadMd5',
      -parameters      => { md5_checksum_file => $self->o('md5_checksum_file'), },
      -input_ids       => [ {} ],
      -wait_for 	   => ['prepipeline_checks'],
      -rc_name         => 'default',
    },

    { -logic_name      => 'job_factory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::BaseSpeciesFactory',
      -parameters      => {
                            species      => $self->o('species'),
                            antispecies  => $self->o('antispecies'),
                            division     => $self->o('division'),
                            run_all      => $self->o('run_all'),
 			    meta_filters => $self->o('meta_filters'),
                          },
      -input_ids       => [ {} ],
      -max_retry_count => 1,
      -rc_name         => 'default',
      -flow_into       => { 
                            '2->A' => ['analysis_setup_factory'],
                            'A->2' => ['cleanup_prot_feat'],
                               '2' => ['backup_tables', 'load_InterPro_xrefs'], 
                          },
    },

    { -logic_name      => 'backup_tables',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::BackupTables',
      -hive_capacity   => 50,
      -parameters      => { pipeline_dir => $self->o('pipeline_dir'),
                            dump_tables  => $self->o('dump_tables'),
                          },
      -rc_name         => 'default',
    },

    { -logic_name      => 'load_InterPro_xrefs',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::LoadInterProXrefs',
      -hive_capacity   => 50,
      -parameters      => { oracle_home => $self->o('oracle_home'), },
      -rc_name         => 'default',
    },

    { -logic_name      => 'analysis_setup_factory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::AnalysisSetupFactory',
      -parameters      => { required_analysis  => $self->o('required_analysis'),},
      -rc_name         => 'default',
      -flow_into  	   => {
                       		'2->A' => ['analysis_setup'],
                       		'A->1' => ['prepipeline_checks'],
                     	  },
      -wait_for        => ['backup_tables'],
    },

    { -logic_name      => 'analysis_setup',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::AnalysisSetup',
      -hive_capacity   => 50,
      -batch_size      => 20,
      -max_retry_count => 0,
      -parameters      => {
                            db_backup_required => 0,
                            delete_existing    => $self->o('delete_existing'),
							linked_tables      => $self->o('linked_tables'),
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                          },
      -rc_name         => 'default',
    },

    { -logic_name      => 'prepipeline_checks',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::PrePipelineChecks',
      -hive_capacity   => 50,
      -max_retry_count => 0,
      -parameters      => {
                            required_analysis   => $self->o('required_analysis'),
                            required_externalDb => $self->o('required_externalDb'),
                          },
      -rc_name         => 'default',
      -flow_into       => {
                       		'1->A' => [ 'table_cleanup' ],
                       		'A->1' => [ 'dump_proteome' ],
					  	  },
    },

    { -logic_name      => 'table_cleanup',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::TblCleanup',
      -hive_capacity   => 50,
      -parameters      => { 
      required_externalDb => $self->o('required_externalDb'), },
      -rc_name         => 'default',
      -flow_into       => ['meta_table_update'],
    },

    { -logic_name      => 'meta_table_update',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::UpdateMetaTbl',
      -hive_capacity   => 50,
      -parameters      => {
                            interproscan_version => $self->o('interproscan_version'),
                            interproscan_date    => $self->o('interproscan_date'),
                            interpro_version     => $self->o('interpro_version'),
                          },
      -rc_name         => 'default',
    },

    { -logic_name 	   => 'dump_proteome',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::DumpProteome',
      -parameters 	   => {
                       		proteome_dir => catdir($self->o('pipeline_dir'), '#species#'),
                       		header_style => 'dbID',
                       		overwrite    => $self->o('overwrite'),
                                production_lookup  => $self->o('production_lookup'),
                                production_db      => $self->o('production_db'),
                     	  },
      -rc_name    	   => 'default',
      -flow_into  	   => $flow_dump_proteome,
	},

    ## start: Seg Analysis 
    { -logic_name 	   => 'split_fasta',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::FastaSplit',    
      -parameters 	   => {
                       		fasta_file              => '#proteome_file#',
                       		max_seqs_per_file       => $self->o('max_seqs_per_file'),
                       		max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                       		max_files_per_directory => $self->o('max_files_per_directory'),
                       		max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                     	   },
      -rc_name    	   => 'default',
      -flow_into  	   => {'2' => ['run_Seg']},
    },

    { -logic_name      => 'run_Seg',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::RunSeg',    
      -hive_capacity   => 50,
      -batch_size      => 1,
      -parameters      => {
                          	file       => '#split_file#',
                          	seg_exe    => $self->o('seg_exe'),
                          	seg_params => $self->o('seg_params'),
                           },
      -rc_name         => 'default',
      -flow_into       => ['store_Seg_feat'],
    },

    { -logic_name      => 'store_Seg_feat',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreSegFeat',    
      -hive_capacity   => 50,
      -batch_size      => 50,
      -parameters      => { seg_logic_name => $self->o('seg_logic_name'), },
      -rc_name         => 'default',
    },
    ## end: Seg Analysis

    { -logic_name      => 'split_fasta_by_md5',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::SplitByMd5sum',    
      -parameters      => { fasta_file => '#proteome_file#', },
      -wait_for        => ['load_md5'],
      -rc_name         => 'default',
      -flow_into       => {
                           '1' => ['split_md5_fasta'],
                           '2' => ['split_no_md5_fasta'],
                          },
    },

    ## start: InterproScan Analysis 
    { -logic_name      => 'split_md5_fasta',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::FastaSplit',    
      -parameters      => {
                            fasta_file              => '#checksum_file#',
                       		max_seqs_per_file       => $self->o('max_seqs_per_file'),
                       		max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                       		max_files_per_directory => $self->o('max_files_per_directory'),
                       		max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                      	   },
      -rc_name    	   => 'default',
      -flow_into  	   => {'2' => ['run_InterProScan_lookup', 'run_InterProScan_nolookup']},
    },

    { -logic_name 	   => 'split_no_md5_fasta',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::FastaSplit',    
      -parameters 	   => {
                       		fasta_file              => '#nochecksum_file#',
                       		max_seqs_per_file       => $self->o('max_seqs_per_file'),
                       		max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                       		max_files_per_directory => $self->o('max_files_per_directory'),
                       		max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                     	   },
      -rc_name    	   => 'default',
      -flow_into  	   => {'2' => ['run_InterProScan_local']},
    },
    
    { -logic_name      => 'run_InterProScan_lookup',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::RunI5',    
      -hive_capacity   => 50,
      -batch_size      => 10,
      -can_be_empty    => 1,
      -parameters      => {
					         protein_file              => '#split_file#',
					         run_mode                  => 'lookup',
					         interproscan_exe          => $self->o('interproscan_exe'),
				             interproscan_applications => $self->o('interproscan_lookup_applications'),
      					   },
      -rc_name         => 'default',
      -flow_into       => ['store_features'],
    },

    { -logic_name      => 'run_InterProScan_nolookup',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::RunI5',    
      -hive_capacity   => 50,
      -batch_size      => 1,
      -can_be_empty    => 1,
      -parameters      => {
					          protein_file              => '#split_file#',
					          run_mode                  => 'nolookup',
					          interproscan_exe          => $self->o('interproscan_exe'),
					          interproscan_applications => $self->o('interproscan_nolookup_applications'),
      					  },
      -rc_name         => 'i5_local_computation',
      -flow_into       => ['store_features'],
    },

    { -logic_name      => 'run_InterProScan_local',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::RunI5',    
      -hive_capacity   => 50,
      -max_retry_count => 10,
      -batch_size      => 1,
      -can_be_empty    => 1,
      -parameters      => {
					          protein_file              => '#split_file#',
					          run_mode                  => 'local',
					          interproscan_exe          => $self->o('interproscan_exe'),
					          interproscan_applications => $self->o('interproscan_local_applications'),
					       },
      -rc_name         => 'i5_local_computation',
      -flow_into       => ['store_features'],
    },
    ## end: InterproScan Analysis 

    { -logic_name      => 'store_features',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreFeatures',    
      -hive_capacity   => 50,
      -max_retry_count => 10,
      -parameters      => {
                            required_externalDb => $self->o('required_externalDb'),
                          },
      -wait_for        => ['load_InterPro_xrefs'],
      -rc_name         => 'default',
    },

    { -logic_name      => 'cleanup_prot_feat',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::CleanupProteinFeatures',
      -hive_capacity   => 50,
      -max_retry_count => 0,
      -parameters      => { exclusion => $self->o('exclusion'), },
      -wait_for        => $waitfor_cleanup_prot_feat,
      -rc_name         => 'default',
      -flow_into       => $flow_cleanup_prot_feat,
    },

    { -logic_name      => 'load_InterPro2Go',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::Interpro2GoLoader',
      -hive_capacity   => 30,
      -max_retry_count => 0,
      -parameters      => {
                            interpro2go             => $self->o('interpro2go'),
                            flag_check_annot_exists => $self->o('flag_check_annot_exists'),
                          },
      -rc_name         => 'default',
    },

    { -logic_name => 'pipeline_cleanup',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::InterProScan::Cleanup',
      -parameters => {
                       pipeline_dir 				  => $self->o('pipeline_dir'),
                       delete_pipeline_dir_at_cleanup => $self->o('delete_pipeline_dir_at_cleanup'),
                      },
      -input_ids  => [ {} ],
	  -wait_for   => $waitfor_pipeline_cleanup,
      -rc_name    => 'default',
    },

  ];
}

sub resource_classes {
  my ($self) = @_;

  return {
#    'i5_local_computation' => {'LSF' => '-q production-rh6 -n 4 -R "select[gpfs]"' },
    'default' 			   => {'LSF' => '-q production-rh6' },
    'i5_local_computation' => {'LSF' => '-q production-rh6 -n 4' },
  };
}

1;

