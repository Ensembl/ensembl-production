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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpVariation_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpVariation_conf;

use strict;
use warnings;
use File::Spec;
use Data::Dumper;
use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  

sub default_options {
	my ($self) = @_;
	return {
       ## inherit other stuff from the base class
       %{ $self->SUPER::default_options() },

	  'hive_use_triggers' => 0,

	   ## General parameters
       'registry'      => $self->o('registry'),   
       'release'       => $self->o('release'),
       'eg_version'    => $self->o('release'),
       'pipeline_name' => $self->o('hive_dbname'),       
	   'email'         => $self->o('ENV', 'USER').'@ebi.ac.uk',
       'ftp_dir'       => '/nfs/nobackup/ensemblgenomes/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name').'/ftp_site/release-'.$self->o('release'),
       'temp_dir'      => '/nfs/nobackup/ensemblgenomes/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name').'/temp_dir/release-'.$self->o('release'),
       'dumps'     	   => [],

	   ## 'job_factory' parameters
	   'species'     => [], 
	   'antispecies' => [],
       'division' 	 => '', 
	   'run_all'     => 0,	

       ##
	   'ftp_gvf_file_dir' => File::Spec->catfile(
		    $self->o('ftp_dir'),
		    $self->directory_name_for_compara($self->o('division')),
		    'gvf',
		),
		
	   'ftp_vcf_file_dir' => File::Spec->catfile(
		    $self->o('ftp_dir'),
		    $self->directory_name_for_compara($self->o('division')),
		    'vcf',
		),

	   'temp_gvf_file_dir' => File::Spec->catfile(
		    $self->o('temp_dir'),
		    $self->directory_name_for_compara($self->o('division')),
		    'gvf',
		),

		'ensembl_gvf2vcf_script' => File::Spec->catfile(
		    $self->o('ensembl_cvs_root_dir'),
		    '/ensembl-variation/scripts/misc/gvf2vcf.pl'
		),

       'pipeline_db' => {  
 	      -host   => $self->o('hive_host'),
       	  -port   => $self->o('hive_port'),
          -user   => $self->o('hive_user'),
          -pass   => $self->o('hive_password'),
	      -dbname => $self->o('hive_dbname'),
          -driver => 'mysql',
       },

       'prod_db'  =>  {
          -host     => 'mysql-eg-pan-prod.ebi.ac.uk',
          -port     => '4276',
          -user     => 'ensro',
          -group    => 'production',
          -dbname   => 'ensembl_production',
       }

	};
}

sub this_pipelines_sub_dir {
    return 'gvf'
}

sub directory_name_for_compara {

    my $self    = shift;
    my $compara = shift;

    return 'pan_ensembl'
        if ($compara eq 'pan_homology');

return $compara;
}


# these parameter values are visible to all analyses, 
# can be overridden by parameters{} and input_id{}
sub pipeline_wide_parameters {  
    my ($self) = @_;
    return {
            %{$self->SUPER::pipeline_wide_parameters},  # here we inherit anything from the base class
		    'pipeline_name'    => $self->o('pipeline_name'), #This must be defined for the beekeeper to work properly
            'registry'         => $self->o('registry'),
            'release'          => $self->o('release'),

            'ftp_gvf_file_dir' => $self->o('ftp_gvf_file_dir'),
            'ftp_vcf_file_dir' => $self->o('ftp_vcf_file_dir'),           
            'temp_gvf_file_dir'=> $self->o('temp_gvf_file_dir'),
    };
}

sub pipeline_analyses {
	my ($self) = @_;

	my $division = $self->o('division');
	$division = ['DUMMY'] unless($division);

	return
	[
	    {  -logic_name => 'GVF_setup',
		   -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
           -parameters => {
                'sql'   => [
				    qq~
CREATE TABLE IF NOT EXISTS gvf_species (
	species_id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
	species VARCHAR(255) DEFAULT NULL,
	division VARCHAR(255) DEFAULT NULL,
	total_files INT(10) UNSIGNED NOT NULL,
	PRIMARY KEY (species_id),
	UNIQUE KEY species_idx (species)
);
				    ~,
#
# Stores information about intermediary files.
# - The species to which this partial dump belongs,
# - The gvf type of dump this is
# - and the name of the file.
#
				    qq~
CREATE TABLE IF NOT EXISTS gvf_file (
	file_id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
	species_id INT(10) UNSIGNED NOT NULL,
	type TEXT NOT NULL,
	file TEXT NOT NULL,

	PRIMARY KEY (file_id)
);
				    ~,
				    qq~
CREATE TABLE IF NOT EXISTS gvf_merge (
	merge_id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
	species_id INT(10) UNSIGNED NOT NULL,
	type TEXT NOT NULL,
	created BOOLEAN NOT NULL DEFAULT 0,
	
	PRIMARY KEY (merge_id)
);
				    ~
                ],
            },
	    },

     { -logic_name     => 'backbone_fire_pipeline_variation_dump',
  	   -module         => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -input_ids      => [ {} ], 
       -parameters     => {},
       -hive_capacity  => -1,
       -rc_name 	   => 'default',
       -flow_into      => {'1->A' => ['GVF_setup'],
                           'A->1' => ['GVF_job_factory'],
                          }		                       
     },   

	 { -logic_name     => 'GVF_job_factory',
       -module         => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -parameters     => {
                             species     => $self->o('species'),
                             antispecies => $self->o('antispecies'),
                             division    => $self->o('division'),
                             run_all     => $self->o('run_all'),
                          },
	  -hive_capacity   => -1,
      -rc_name 	       => 'default',     
      -max_retry_count => 1,
      -flow_into       => { '4' => ['GVF_create_seqregion_batches', 'VCF_readme'],},    
    },

    { -logic_name => 'GVF_create_seqregion_batches',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::GVF::JobForEachSeqRegion',	   
	  -flow_into  => {
 		 2 => 'GVF_dumpbatch',
		 3 => [ ":////gvf_species" ],
		 4 => [ ":////gvf_merge"   ],
	  },
	  -parameters => {
		gvf_type => [
		    'default',
		    'failed',
		    'incl_consequences',
		    'structural_variations',
		],
	   	division => $self->o('division'),
	  },
	 -input_ids => [],
	},


    { -logic_name => 'GVF_dumpbatch',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::GVF::DumpGVFBatch',	   
      # Seems to provide a reasonable trade off between
	  -hive_capacity => 30,
	  -wait_for      => [ 'GVF_job_factory'],
      -parameters => {
		dump_gvf_script  => $self->o('ensembl_cvs_root_dir') . '/ensembl-variation/scripts/export/dump_gvf.pl',
       },
	 -rc_name => 'default',
	 -flow_into => {
# The URL ':////gvf_file' only works with the old parser, please start using the new syntax as the old parser will soon be deprecated
		2 => [ ":////gvf_file" ],
		3 => 'GVF_merge_job_factory',
	 },
   },

   { -logic_name => 'GVF_start_merge_job_factory',
     -module     => 'Bio::EnsEMBL::Production::Pipeline::GVF::StartMergeJobFactory',	   
     -flow_into  => { 2 => 'GVF_merge_job_factory', },
     -input_ids  => [ {} ],
	 -wait_for   => [ 'GVF_dumpbatch' ],
   },

   { -logic_name    => 'GVF_merge_job_factory',
     -module        => 'Bio::EnsEMBL::Production::Pipeline::GVF::MergeJobFactory',	   
     -hive_capacity => 1,
	 -rc_name       => 'default',
	 -flow_into     => { 2 => 'GVF_merge_partial_gvf'},
	   # Try to let one worker get all the jobs. Multiple job
	   # factories might create competing merge jobs, though
	   # unlikely. This could be prevented by having jobs from 
	   # this analysis locking the gvf_file table.
     -batch_size    => 10000,
     -parameters    => { division => $self->o('division'), },
   },

   { -logic_name    => 'GVF_merge_partial_gvf',
     -module        => 'Bio::EnsEMBL::Production::Pipeline::GVF::MergePartialGVF',	   
     -hive_capacity => 5,
	 -rc_name       => 'default',
	 -flow_into     => {
			2 => 'GVF_tidy',
			3 => 'convert_GVF2VCF',
	   },
	 -parameters    => { },
   },

   { -logic_name    => 'GVF_tidy',
     -module        => 'Bio::EnsEMBL::Production::Pipeline::GVF::Tidy',	   
	 -hive_capacity => 1,
	 -rc_name => 'default',
	 -flow_into => {},
	 -parameters => {
			tidy_gvf_dump_script => $self->o('ensembl_cvs_root_dir') . '/ensembl-variation/scripts/export/tidy_gvf_dumps.pl',
	   },
   },

   { -logic_name    => 'convert_GVF2VCF',
     -module        => 'Bio::EnsEMBL::Production::Pipeline::GVF::ConvertGVFToVCF',	   
	 -hive_capacity => 5,
	 -rc_name => 'default',
	 -parameters => {
		ensembl_gvf2vcf_script => $self->o('ensembl_gvf2vcf_script'),
		registry               => $self->o('registry'),
	   },
   },

   { -logic_name    => 'VCF_readme',
     -module        => 'Bio::EnsEMBL::Production::Pipeline::GVF::Readme',	   
     -hive_capacity => 5,
	 -rc_name       => 'default',
	 -parameters    => { },
	 -wait_for      => [ 'convert_GVF2VCF' ],
   },
	];
}

1;
