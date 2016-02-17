=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf;

use Bio::EnsEMBL::Hive::Version 2.3;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use File::Spec;
use Data::Dumper;
use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  
   
sub default_options {
	my ($self) = @_;
	return {
       ## inherit other stuff from the base class
       %{ $self->SUPER::default_options() },

	   ## General parameters
       'registry'      => $self->o('registry'),   
       'release'       => $self->o('release'),
       'pipeline_name' => $self->o('hive_db'),       
	   'email'         => $self->o('ENV', 'USER').'@ebi.ac.uk',
       'output_dir'    => '/nfs/nobackup/ensemblgenomes/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name').'/ftp_site',     

	   ## 'job_factory' parameters
	   'species'     => [], 
	   'antispecies' => [],
       'division' 	 => [], 
	   'run_all'     => 0,	
	  
	   ## Set to '1' for eg! run 
       #   default => OFF (0)
       #   affect: gff3, gtf
	   'eg' 		 => 0,

	   ## Set to '0' to skip dump format(s)
       #   default => OFF (0)
	   #  'tsv'   - ena & uniprot
	   #  'fasta' - cdna, cds, dna, ncrna, pep
   	   'f_dump_gtf'     => 0,
	   'f_dump_gff3'    => 0,
	   'f_dump_embl'    => 0,
   	   'f_dump_genbank' => 0,
   	   'f_dump_tsv'     => 0,
   	   'f_dump_fasta'   => 0,

	   ## gtf parameters, e! specific
	   'gtftogenepred_exe' => 'gtfToGenePred',
       'genepredcheck_exe' => 'genePredCheck',

       ## gff3 parameters
       'gt_exe'          => '/nfs/panda/ensemblgenomes/external/genometools/bin/gt',
       'gff3_tidy'       => $self->o('gt_exe').' gff3 -tidy -sort -retainids',
       'gff3_validate'   => $self->o('gt_exe').' gff3validator',

       'feature_type'    => ['Gene', 'Transcript', 'RepeatFeature', 'SimpleFeature'],
       'per_chromosome'  => 1,
       'include_scaffold'=> 1,
	   'logic_name'      => [],
	   'db_type'	     => 'core',
       'out_file_stem'   => undef,
       'xrefs'           => 0,
       'abinitio'        => 1,
=pod
       # e! specific
       'e_feature_type'     => ['Gene', 'Transcript'],
       'e_per_chromosome'   => 0,
       'e_include_scaffold' => 1,
       # eg! specific
       'eg_feature_type'    => ['Gene', 'Transcript', 'RepeatFeature', 'SimpleFeature'],
       'eg_per_chromosome'  => 1,
       'eg_include_scaffold'=> 0,
=cut	

       'pipeline_db' => {  
 	      -host   => $self->o('hive_host'),
       	  -port   => $self->o('hive_port'),
          -user   => $self->o('hive_user'),
          -pass   => $self->o('hive_password'),
	      -dbname => $self->o('hive_db'),
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

sub pipeline_create_commands {
    my ($self) = @_;
    return [
      # inheriting database and hive tables' creation
      @{$self->SUPER::pipeline_create_commands},
      'mkdir -p '.$self->o('output_dir'),
    ];
}

# Ensures output parameters gets propagated implicitly
sub hive_meta_table {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

# Override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;
  return 
      ' -reg_conf ' . $self->o('registry'),
  ;
}

# these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
sub pipeline_wide_parameters {  
    my ($self) = @_;
    return {
            %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
		    'pipeline_name' => $self->o('pipeline_name'), #This must be defined for the beekeeper to work properly
            'base_path'     => $self->o('output_dir'),
            'release'       => $self->o('release'),

			# 'eg' flag, 
			'eg'			=> $self->o('eg'),
            # eg_version & sub_dir parameter in Production/Pipeline/GTF/DumpFile.pm 
            # needs to be change , maybe removing the need to eg flag
            'eg_version'    => $self->o('release'),
            'sub_dir'       => $self->o('output_dir'),
    };
}

sub resource_classes {
    my $self = shift;
    return {
      'default'  	=> {'LSF' => '-q production-rh6 -n 4 -M 4000   -R "rusage[mem=4000]"'},
      '32GB'  	 	=> {'LSF' => '-q production-rh6 -n 4 -M 32000  -R "rusage[mem=32000]"'},
      '64GB'  	 	=> {'LSF' => '-q production-rh6 -n 4 -M 64000  -R "rusage[mem=64000]"'},
      '128GB'  	 	=> {'LSF' => '-q production-rh6 -n 4 -M 128000 -R "rusage[mem=128000]"'},
      '256GB'  	 	=> {'LSF' => '-q production-rh6 -n 4 -M 256000 -R "rusage[mem=256000]"'},
	}
}

sub pipeline_analyses {
    my ($self) = @_;

   	my $pipeline_flow;

#  	if ($self->o('dump_tsv') && $self->o('dump_gtf') && $self->o('dump_gff3') && $self->o('dump_embl') && $self->o('dump_genbank') && $self->o('dump_fasta') ) {
  	if ($self->o('f_dump_gtf') && $self->o('f_dump_gff3') && $self->o('f_dump_embl') && $self->o('f_dump_genbank')) {
    	$pipeline_flow  = ['dump_gtf', 'predump_gff3', 'dump_embl', 'dump_genbank'];
    } 
      elsif ($self->o('f_dump_gtf')  && $self->o('f_dump_gff3') && $self->o('f_dump_embl'))    { $pipeline_flow  = ['dump_gtf', 'predump_gff3', 'dump_embl']; } 
  	  elsif ($self->o('f_dump_gtf')  && $self->o('f_dump_gff3') && $self->o('f_dump_genbank')) { $pipeline_flow  = ['dump_gtf', 'predump_gff3', 'dump_genbank']; }
  	  elsif ($self->o('f_dump_gtf')  && $self->o('f_dump_embl') && $self->o('f_dump_genbank')) { $pipeline_flow  = ['dump_gtf', 'dump_embl', 'dump_genbank']; } 
  	  elsif ($self->o('f_dump_gff3') && $self->o('f_dump_embl') && $self->o('f_dump_genbank')) { $pipeline_flow  = ['predump_gff3', 'dump_embl', 'dump_genbank']; } 

  	  elsif ($self->o('f_dump_gtf')  && $self->o('f_dump_gff3'))    { $pipeline_flow  = ['dump_gtf', 'predump_gff3']; } 
  	  elsif ($self->o('f_dump_gtf')  && $self->o('f_dump_embl'))    { $pipeline_flow  = ['dump_gtf', 'dump_embl']; } 
  	  elsif ($self->o('f_dump_gtf')  && $self->o('f_dump_genbank')) { $pipeline_flow  = ['dump_gtf', 'dump_genbank']; } 
  	  elsif ($self->o('f_dump_gff3') && $self->o('f_dump_embl'))    { $pipeline_flow  = ['predump_gff3', 'dump_embl']; } 
  	  elsif ($self->o('f_dump_gff3') && $self->o('f_dump_genbank')) { $pipeline_flow  = ['predump_gff3', 'dump_genbank']; }
  	  elsif ($self->o('f_dump_embl') && $self->o('f_dump_genbank')) { $pipeline_flow  = ['dump_embl', 'dump_genbank']; }
  	  
  	  elsif ($self->o('f_dump_gtf'))     { $pipeline_flow  = ['dump_gtf']; } 
  	  elsif ($self->o('f_dump_gff3'))    { $pipeline_flow  = ['predump_gff3']; } 
  	  elsif ($self->o('f_dump_embl'))    { $pipeline_flow  = ['dump_embl']; } 
  	  elsif ($self->o('f_dump_genbank')) { $pipeline_flow  = ['dump_genbank'];
	}
    
    return [
     { -logic_name     => 'backbone_fire_pipeline',
  	   -module         => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -input_ids      => [ {} ], 
       -parameters     => {},
       -hive_capacity  => -1,
       -rc_name 	   => 'default',       
       -meadow_type    => 'LOCAL',
   	   -flow_into      => { '1' => ['job_factory'] },
     },   

	 { -logic_name     => 'job_factory',
       -module         => 'Bio::EnsEMBL::Production::Pipeline::BaseSpeciesFactory',
       -parameters     => {
                             species     => $self->o('species'),
                             antispecies => $self->o('antispecies'),
                             division    => $self->o('division'),
                             run_all     => $self->o('run_all'),
                           },
	  -hive_capacity   => -1,
      -rc_name 	       => 'default',     
      -max_retry_count => 1,
      -flow_into       => {
		                    '2->A' => $pipeline_flow,
		                    'A->1' => ['email_report'],		                       
                          },        
			             #   '2'    => ['build_dir_chain','build_dir_gff3', 'build_dir_gtf', 'dump_embl', 'dump_genbank', 'dump_tsv', 'dump_ena_tsv'], 
                         #   '2->A' => [ @$dna_analyses_names_default, 'dump_peptide', 'dump_cdna', 'dump_ncrna'],
                         #      'A->2' => ['convert_fasta'],
    },

### EMBL Dump
    { -logic_name    => 'dump_embl',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
	  -parameters    => { type      => 'embl',},
	  -hive_capacity => 50,
	  -rc_name       => 'default',
      -flow_into     => { '-1' => 'dump_embl_32GB', }, 
	},  

    { -logic_name    => 'dump_embl_32GB',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
	  -parameters    => { type      => 'embl',},
	  -hive_capacity => 50,
      -rc_name       => '32GB',
      -flow_into     => { '-1' => 'dump_embl_64GB', }, 
	},  

    { -logic_name    => 'dump_embl_64GB',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
	  -parameters    => { type      => 'embl',},
	  -hive_capacity => 50,
      -rc_name       => '64GB',
      -flow_into     => { '-1' => 'dump_embl_128GB', }, 
	},  

    { -logic_name    => 'dump_embl_128GB',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
	  -parameters    => { type      => 'embl',},
	  -hive_capacity => 50,
      -rc_name       => '128GB',
	},  

### GenBank Dump
    { -logic_name    => 'dump_genbank',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
	  -parameters    => { type      => 'genbank',},
	  -hive_capacity => 50,
	  -rc_name       => 'default',
      -flow_into     => { -1 => 'dump_genbank_32GB', }, 
	},  

    { -logic_name    => 'dump_genbank_32GB',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
	  -parameters    => { type      => 'genbank',},
	  -hive_capacity => 50,
      -rc_name       => '32GB',
      -flow_into     => { -1 => 'dump_genbank_64GB', }, 
	},  

    { -logic_name    => 'dump_genbank_64GB',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
	  -parameters    => { type      => 'genbank',},
	  -hive_capacity => 50,
      -rc_name       => '64GB',
      -flow_into     => { -1 => 'dump_genbank_128GB', }, 
	},  

    { -logic_name    => 'dump_genbank_128GB',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
	  -parameters    => { type      => 'genbank',},
	  -hive_capacity => 50,
      -rc_name       => '128GB',
	}, 
	
### GTF Dump
	{ -logic_name     => 'dump_gtf',
      -module         => 'Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile',
      -parameters     => {
				            gtf_to_genepred => $self->o('gtftogenepred_exe'),
					        gene_pred_check => $self->o('genepredcheck_exe')						
                          },
	  -hive_capacity  => 50,
	  -rc_name        => 'default',
  	  -flow_into      => { '-1' => 'dump_gtf_32GB', }, 
	}, 
 	
	{ -logic_name     => 'dump_gtf_32GB',
      -module         => 'Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile',
      -parameters     => {
				            gtf_to_genepred => $self->o('gtftogenepred_exe'),
					        gene_pred_check => $self->o('genepredcheck_exe')						
                          },
	  -hive_capacity  => 50,
      -rc_name       => '32GB',
  	  -flow_into      => { '-1' => 'dump_gtf_64GB', }, 
	},  	

	{ -logic_name     => 'dump_gtf_64GB',
      -module         => 'Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile',
      -parameters     => {
				            gtf_to_genepred => $self->o('gtftogenepred_exe'),
					        gene_pred_check => $self->o('genepredcheck_exe')						
                          },
	  -hive_capacity  => 50,
      -rc_name       => '64GB',
  	  -flow_into      => { '-1' => 'dump_gtf_128GB', }, 
	},  	
 	
	{ -logic_name     => 'dump_gtf_128GB',
      -module         => 'Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile',
      -parameters     => {
				            gtf_to_genepred => $self->o('gtftogenepred_exe'),
					        gene_pred_check => $self->o('genepredcheck_exe')						
                          },
	  -hive_capacity  => 50,
      -rc_name       => '128GB',
	},  	
 	
### GFF3 Dump
    { -logic_name     => 'predump_gff3',
      -module         => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -parameters     => {},
      -hive_capacity  => -1,
      -rc_name 	      => 'default',       
      -flow_into      => { '1' => [$self->o('eg') ? 'dump_eg_gff3' : 'dump_e_gff3'] },
     },   

     { -logic_name     => 'dump_eg_gff3',
       -module         => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
       -parameters     => {
          feature_type       => $self->o('feature_type'),
          per_chromosome     => $self->o('per_chromosome'),
          include_scaffold   => $self->o('include_scaffold'),
          logic_name         => $self->o('logic_name'),
          db_type            => $self->o('db_type'),
	      abinitio           => $self->o('abinitio'),
	      out_file_stem      => $self->o('out_file_stem'),
	      xrefs              => $self->o('xrefs'),        
        },
	   -hive_capacity  => 50, 
       -rc_name 	   => 'default',       
  	   -flow_into      => { 
    						'-1' => 'dump_eg_gff3_32GB', 
							'1'  => [ $self->o('eg') ? 'tidy_gff3' : () ],
     					  }, 
     },   

	 { -logic_name     => 'dump_eg_gff3_32GB',
       -module         => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
       -parameters     => {
          feature_type       => $self->o('feature_type'),
          per_chromosome     => $self->o('per_chromosome'),
          include_scaffold   => $self->o('include_scaffold'),
          logic_name         => $self->o('logic_name'),
          db_type            => $self->o('db_type'),
    	  abinitio           => $self->o('abinitio'),
	      out_file_stem      => $self->o('out_file_stem'),
	      xrefs              => $self->o('xrefs'),        
        },
	   -hive_capacity  => 50, 
  	   -rc_name        => '32GB',
   	   -flow_into      => { '-1' => 'dump_eg_gff3_64GB', }, 
	 },	

	 { -logic_name     => 'dump_eg_gff3_64GB',
       -module         => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
       -parameters     => {
          feature_type       => $self->o('feature_type'),
          per_chromosome     => $self->o('per_chromosome'),
          include_scaffold   => $self->o('include_scaffold'),
          logic_name         => $self->o('logic_name'),
          db_type            => $self->o('db_type'),
    	  abinitio           => $self->o('abinitio'),
	      out_file_stem      => $self->o('out_file_stem'),
	      xrefs              => $self->o('xrefs'),        
        },
	   -hive_capacity  => 50, 
  	   -rc_name        => '64GB',
   	   -flow_into      => { '-1' => 'dump_eg_gff3_128GB', }, 
	 },	

	 { -logic_name     => 'dump_eg_gff3_128GB',
       -module         => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
       -parameters     => {
          feature_type       => $self->o('feature_type'),
          per_chromosome     => $self->o('per_chromosome'),
          include_scaffold   => $self->o('include_scaffold'),
          logic_name         => $self->o('logic_name'),
          db_type            => $self->o('db_type'),
	      abinitio           => $self->o('abinitio'),
	      out_file_stem      => $self->o('out_file_stem'),
	      xrefs              => $self->o('xrefs'),        
        },
	   -hive_capacity  => 50, 
  	   -rc_name        => '128GB',
	 },	

     { -logic_name     => 'dump_e_gff3',
       -module         => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
       -parameters     => {
          feature_type       => $self->o('feature_type'),
          per_chromosome     => $self->o('per_chromosome'),
          include_scaffold   => $self->o('include_scaffold'),
          logic_name         => $self->o('logic_name'),
          db_type            => $self->o('db_type'),
          abinitio           => $self->o('abinitio'),
          out_file_stem      => $self->o('out_file_stem'),
          xrefs              => $self->o('xrefs'),
        },
	   -hive_capacity  => 50, 
       -rc_name 	   => 'default',       
  	   -flow_into      => { 
  	    					'-1' => 'dump_e_gff3_32GB', 
							'1'  => [ $self->o('eg') ? () : 'tidy_gff3' ],
     					  }, 
     },   

	 { -logic_name     => 'dump_e_gff3_32GB',
       -module         => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
       -parameters     => {
          feature_type       => $self->o('feature_type'),
          per_chromosome     => $self->o('per_chromosome'),
          include_scaffold   => $self->o('include_scaffold'),
          logic_name         => $self->o('logic_name'),
          db_type            => $self->o('db_type'),
          abinitio           => $self->o('abinitio'),
          out_file_stem      => $self->o('out_file_stem'),
          xrefs              => $self->o('xrefs'),
        },
	   -hive_capacity  => 50, 
  	   -rc_name        => '32GB',
   	   -flow_into     => { '-1' => 'dump_e_gff3_64GB', }, 
	 },	

	 { -logic_name     => 'dump_e_gff3_64GB',
       -module         => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
       -parameters     => {
          feature_type       => $self->o('feature_type'),
          per_chromosome     => $self->o('per_chromosome'),
          include_scaffold   => $self->o('include_scaffold'),
          logic_name         => $self->o('logic_name'),
          db_type            => $self->o('db_type'),
          abinitio           => $self->o('abinitio'),
          out_file_stem      => $self->o('out_file_stem'),
          xrefs              => $self->o('xrefs'),
        },
	   -hive_capacity  => 50, 
  	   -rc_name        => '64GB',
   	   -flow_into     => { '-1' => 'dump_e_gff3_128GB', }, 
	 },	

	 { -logic_name     => 'dump_e_gff3_128GB',
       -module         => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
       -parameters     => {
          feature_type       => $self->o('feature_type'),
          per_chromosome     => $self->o('per_chromosome'),
          include_scaffold   => $self->o('include_scaffold'),
          logic_name         => $self->o('logic_name'),
          db_type            => $self->o('db_type'),
          abinitio           => $self->o('abinitio'),
          out_file_stem      => $self->o('out_file_stem'),
          xrefs              => $self->o('xrefs'),
        },
	   -hive_capacity  => 50, 
  	   -rc_name        => '128GB',
	 },	

### GFF3 Dump post-processing
     { -logic_name     => 'tidy_gff3',
       -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
       -parameters     => {  cmd => $self->o('gff3_tidy').' -gzip -o #out_file#.sorted.gz #out_file#', },
       -hive_capacity  => 10,
       -batch_size     => 10,
	   -rc_name        => 'default',
       -flow_into      => 'move_gff3',
     },

     {
       -logic_name     => 'move_gff3',
       -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
       -parameters     => { cmd => 'mv #out_file#.sorted.gz #out_file#', },
       -hive_capacity  => 10,
       -rc_name        => 'default',	
       -meadow_type    => 'LOCAL',
       -flow_into      => 'validate_gff3',
      },
 
      {
     	-logic_name        => 'validate_gff3',
     	-module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
     	-parameters        => { cmd => $self->o('gff3_validate').' #out_file#', },
     	-hive_capacity => 10,
     	-batch_size        => 10,
     	-rc_name           => 'default',
   	  },


#####
    {  -logic_name    => 'email_report',
  	   -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
#       -module        => 'EGExt::FTP::Test::RunnableDB::AssertFTPEmailReport',
       -parameters    => {
#          	'email'      			 => $self->o('email'),
#          	'subject'    			 => $self->o('subject'),
       },
       -hive_capacity  => -1,
       -rc_name 	   => 'default',       
       -meadow_type    => 'LOCAL',
    },


    ];
}

1;

