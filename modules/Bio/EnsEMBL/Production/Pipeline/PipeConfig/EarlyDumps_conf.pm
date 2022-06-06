=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::EarlyDumps_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');
use Bio::EnsEMBL::Production::Pipeline::PipeConfig::FileDumpMySQL_conf;
use Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;
use File::Spec::Functions qw(catdir);


sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    
    #load default from mysql dumps
    %{Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf::default_options($self)},
    #load defaults from core dumps
    %{Bio::EnsEMBL::Production::Pipeline::PipeConfig::FileDumpMySQL_conf::default_options($self)},

    # Copy service
    copy_service_uri  => "http://production-services.ensembl.org/api/dbcopy/requestjob",
    username          => $self->o('ENV', 'USER'),
    skip_convert_fasta => 1,
    #registry 
    registry          => $self->o('registry'),
    # Metadata Report Script
    species           => [],
    metadata_db_host  => 'mysql-ens-meta-prod-1',
    base_dir          => $self->o('ENV', 'BASE_DIR'),
    ensembl_version   => $self->o('ENV', 'ENS_VERSION'),
    eg_version        => $self->o('ENV', 'EG_VERSION'),
    metadata_base_dir => catdir($self->o('ENV', 'NOBACKUP_DIR'), $self->o('username'), 'genome_reports_'.$self->o('ensembl_version')),
    metadata_script   => catdir($self->o('base_dir'), '/ensembl-metadata/misc_scripts/report_genomes.pl'),
    division_pattern_nonvert  => '.fungi,.metazoa,.plants,.protists',
    early_dump_base_path      => catdir($self->o('ENV', 'NOBACKUP_DIR'), '/release_dumps/'),
    nfs_early_dump_path       => '/nfs/production/flicek/ensembl/production/ensemblftp/',
    early_dumps_private_ftp   => catdir('/nfs/ftp/private/ensembl/pre-releases','/release-'.$self->o('ensembl_version').'_'.$self->o('eg_version')),
    #flags to restrict division
    division_list     => ['vertebrates','fungi','metazoa','plants','protists'],  #'bacteria'  
    #FTP Dump 
    ens_ftp_dir       => catdir($self->o('ENV', 'NOBACKUP_DIR'), '/release_dumps/release-'.$self->o('ensembl_version')),
    eg_ftp_dir        => catdir($self->o('ENV', 'NOBACKUP_DIR'), '/release_dumps/release-'.$self->o('eg_version')),
    db_type           => 'core',


    ## fasta parameters
    # types to emit
    dna_sequence_type_list => [ 'dna' ],
    pep_sequence_type_list => [ 'cdna', 'ncrna' ],
    prev_rel_dir           => '/nfs/ftp/ensemblftp/ensembl/PUBLIC/pub/',

    #Mysql Dumps Params
    # Database type factory
    group => ['core'],

    # By default, files are not written if the parent directory
    # (which is the database name) exists.
    overwrite => 0,
    server_url_vert => $self->get_server_url('gp1'),
    server_url_nonvert => $self->get_server_url('gp3'),

  };
}

# Implicit parameter propagation throughout the pipeline.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
     username        => $self->o('username'),
     dump_subdir     => $self->o('dump_subdir') 
  };
}

sub get_server_url {
	my ($self, $host_name) = @_ ; 
	return `$host_name details url`;
}	

sub pipeline_analyses {
  my $self = shift @_;

  return [
   {
      -logic_name        => 'EarlyDumpsDummy',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids         => [ {} ],
      -flow_into         => {
                              '1->A' => WHEN('scalar #species# > 0' => ['SpeciesFactory'], ELSE ['MetaDataReport']),
                              'A->1' => ['CopyToNfs'],
                            },

    },
    {
      -logic_name        => 'CopyToNfs',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              early_dump_path_vert             => catdir($self->o('early_dump_base_path'), '/release-'.$self->o('ensembl_version')),
			      nfs_early_dump_path_vert         => catdir($self->o('nfs_early_dump_path'), '/release-'.$self->o('ensembl_version')), 
			      early_dump_path_nonvert          => catdir($self->o('early_dump_base_path'), '/release-'.$self->o('eg_version')),	
			      nfs_early_dump_path_nonvert      => catdir($self->o('nfs_early_dump_path'), '/release-'.$self->o('eg_version')), 
                              cmd              => q{ 
			      				rsync -avW #early_dump_path_vert# #nfs_early_dump_path_vert# 	
							rsync -avW #early_dump_path_nonvert# #nfs_early_dump_path_nonvert#
			      				
                                                   },
                            },
      -flow_into         => { '1' => 'CopyToPublicFtp' },			    
     			    

    },
    {
      -logic_name        => 'CopyToPublicFtp',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              nfs_early_dump_path_vert         => catdir($self->o('nfs_early_dump_path'), '/release-'.$self->o('ensembl_version')),     
                              nfs_early_dump_path_nonvert      => catdir($self->o('nfs_early_dump_path'), '/release-'.$self->o('eg_version')),
		              early_dumps_private_ftp          => $self->o('early_dumps_private_ftp'),	      
                              cmd              => q{ 
                                                        rsync -avW  #nfs_early_dump_path_vert#/verterates/ #early_dumps_private_ftp#   
                                                        rsync -avW  #nfs_early_dump_path_nonvert#/ #early_dumps_private_ftp# 
                                                        
                                                   },
                            },

     -flow_into         => { '1' => 'Email' }, 			    
      
    },
    {
      -logic_name        => 'MetaDataReport',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::EarlyDumps::MetadataReport',
      -max_retry_count   => 1,
      -parameters        => {
                              server_url_vert    => $self->o('server_url_vert'),
	      	              server_url_nonvert => $self->o('server_url_nonvert'),
	                      base_path          => $self->o('early_dump_base_path'),
	                      dump_dir           => $self->o('early_dump_base_path'),
	                      eg_version         => $self->o('eg_version'),
	      		      ens_ftp_dir        => $self->o('ens_ftp_dir'), 
      	                      ens_version        => $self->o('ensembl_version'),
      			      metadata_host      => $self->o('metadata_db_host'),
      	      		      dump_script        => $self->o('metadata_script'),
      		              dump_path          => $self->o('metadata_base_dir'),
      		              division_pattern_nonvert  => $self->o('division_pattern_nonvert'),
      		              division_list             => $self->o('division_list'), 	      
			    },
      -flow_into         => {
                              '1' => ['SpeciesFactory'],
                              '2' => ['SpeciesFactory'],
                              '3' => ['SpeciesFactory'],
                            },

			    
    },
    
    { 
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -flow_into         => { '2' => 'Dumps', },
    },
    { 
      -logic_name        => 'Dumps',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -flow_into         => { '1->A' => ['gtf', 'gff3', 'fasta_pep', 'fasta_dna', 'DumpMySQL'], 'A->1' => 'checksum_generator' },
    },
    {
      -logic_name        => 'Email',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailNotify',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -parameters        => {
           email         => $self->o('email'),
           pipeline_name => $self->o('pipeline_name'),
      },
    },

    {
       -logic_name      => 'checksum_generator',
       -module        => 'Bio::EnsEMBL::Production::Pipeline::Common::ChksumGenerator',
       -parameters    => {
                dumps              => ['gtf', 'gff3', 'fasta_pep', 'fasta_dna'],
                skip_convert_fasta => '#expr( #dump_division# eq "vertebrates" ? 1 : 0 )expr#',  
       },
       -hive_capacity => 10,
    },
    { 
     -logic_name         => 'gtf',
     -module             => 'Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile',
     -parameters         => {
        gtf_to_genepred  => $self->o('gtftogenepred_exe'),
        gene_pred_check  => $self->o('genepredcheck_exe'),
        abinitio         => $self->o('abinitio'),
        gene             => $self->o('gene'),
	base_path        => '#base_path#',
     },
    -hive_capacity => 50,
    -rc_name       => '2GB',
   },
   { 
    -logic_name      => 'gff3',
    -module          => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
    -parameters      => {
                         feature_type     => $self->o('feature_type'),
                         per_chromosome   => $self->o('per_chromosome'),
                         include_scaffold => $self->o('include_scaffold'),
                         logic_name       => $self->o('logic_name'),
                         db_type          => $self->o('db_type'),
                         abinitio         => $self->o('abinitio'),
                         gene             => $self->o('gene'),
                         out_file_stem    => $self->o('out_file_stem'),
                         xrefs            => $self->o('xrefs'),
			 base_path        => '#base_path#',
                       },
     -hive_capacity => 50,
     -rc_name       => '2GB',
     -flow_into     => { '1' => 'tidy_gff3', },
    },
         { -logic_name      => 'tidy_gff3',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => { cmd => $self->o('gff3_tidy') . ' -gzip -o #out_file#.sorted.gz #out_file#', },
            -hive_capacity => 10,
            -batch_size    => 10,
            -flow_into     => 'move_gff3',
        },

        {
            -logic_name    => 'move_gff3',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => { cmd => 'mv #out_file#.sorted.gz #out_file#', },
            -hive_capacity => 10,
            -flow_into     => 'validate_gff3',
        },

        {
            -logic_name    => 'validate_gff3',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => { cmd => $self->o('gff3_validate') . ' #out_file#', },
            -hive_capacity => 10,
            -batch_size    => 10,
        },
	{
	   -logic_name        => 'fasta_pep',
           -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::DumpFile',
           -parameters      => {
                sequence_type_list  => $self->o('pep_sequence_type_list'),
                process_logic_names => $self->o('process_logic_names'),
                skip_logic_names    => $self->o('skip_logic_names'),
		base_path           => '#base_path#',
            },
            -can_be_empty    => 1,
            -max_retry_count => 1,
            -hive_capacity   => 20,
            -priority        => 5,
            -rc_name         => '2GB',
        },
        { 
            -logic_name      => 'fasta_dna',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::DumpFile',
            -parameters      => {
                sequence_type_list  => $self->o('dna_sequence_type_list'),
                process_logic_names => $self->o('process_logic_names'),
                skip_logic_names    => $self->o('skip_logic_names'),
            },
            -can_be_empty    => 1,
            -flow_into       => { 1 => 'concat_fasta' },
            -max_retry_count => 1,
            -hive_capacity   => 20,
            -priority        => 5,
            -rc_name         => '4GB',
        },

        { 
	    -logic_name      => 'concat_fasta',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::ConcatFiles',
            -can_be_empty    => 1,
            -parameters      => {
                blat_species => $self->o('blat_species'),
            },
            -max_retry_count => 5,
            -priority        => 5,
	    -flow_into         => WHEN('#dump_division# eq "vertebrates"' => ['primary_assembly'])
        },
        {
           -logic_name      => 'primary_assembly',
           -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::CreatePrimaryAssembly',
           -can_be_empty    => 1,
           -max_retry_count => 5,
           -priority        => 5,
        },	
            
	#mysql Dumps
        {
          -logic_name        => 'DumpMySQL',
          -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
          -max_retry_count   => 1,
	  -flow_into         => ['GroupFactory',],
        },

	grep($_->{'-logic_name'} !~ /(DumpMySQL|NamedDbFactory|MultiDbFactory|MySQL_Multi_TXT)/  , @{Bio::EnsEMBL::Production::Pipeline::PipeConfig::FileDumpMySQL_conf::pipeline_analyses($self)})



  ];
} 

1;
