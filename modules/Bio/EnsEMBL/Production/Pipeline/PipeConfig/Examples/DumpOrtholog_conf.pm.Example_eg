=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf;

use strict;
use warnings;
use Bio::EnsEMBL::Hive::Version 2.3;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  

sub default_options {
    my ($self) = @_;

    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() },      

        'registry'         => '',   
        'pipeline_name'    => $self->o('hive_dbname'),       
        'output_dir'       => '/nfs/ftp/pub/databases/ensembl/projections/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name'),     
		'method_link_type' => 'ENSEMBL_ORTHOLOGUES',

     	## Set to '1' for eg! run 
        #   default => OFF (0)
  	    'eg' => 1,

        # hive_capacity values for analysis
	    'getOrthologs_capacity'  => '50',

        # orthologs cutoff
        'perc_id'  => '30',
        'perc_cov' => '30',

        # 'target' & 'exclude' are mutually exclusive
        #  only one of those should be defined if used 
	 	'species_config' => 
		{ 
		  # Plants
          'EPl_1' => {	# compara database to get orthologs from
                   		#  'plants', 'protists', 'fungi', 'metazoa', 'multi'
	          		   	'compara'  => 'plants',   
    	               	# source species to project from
 					   	'source'   => 'arabidopsis_thaliana', 
            	       	# target species to project to (DEFAULT: undef)
						'target'   => undef,
                   		# target species to exclude in projection
	                   	'exclude'  => ['caenorhabditis_elegans', 'drosophila_melanogaster', 'homo_sapiens', 'ciona_savignyi'], 
  					   	'homology_types' => ['ortholog_one2one','apparent_ortholog_one2one'],		       
            	     },   

          'EPl_2' => { 'compara'  => 'plants',   
 					   'source'   => 'oryza_sativa', 
					   'target'   => undef,
                   	   'exclude'  => ['caenorhabditis_elegans', 'drosophila_melanogaster', 'homo_sapiens', 'ciona_savignyi'], 
  				   	   'homology_types' => ['ortholog_one2one','apparent_ortholog_one2one'],		       
                 	 },   

		  # Protists, dictyostelium_discoideum to all amoebozoa
          'EPr_1' => { 'compara'  => 'protists',   
 				   	   'source'   => 'dictyostelium_discoideum', 
					   'target'   => ['polysphondylium_pallidum_pn500', 'entamoeba_nuttalli_p19', 'entamoeba_invadens_ip1', 'entamoeba_histolytica_ku27', 'entamoeba_histolytica_hm_3_imss', 'entamoeba_histolytica_hm_1_imss_b', 'entamoeba_histolytica_hm_1_imss_a', 'entamoeba_histolytica', 'entamoeba_dispar_saw760', 'dictyostelium_purpureum', 'dictyostelium_fasciculatum', 'acanthamoeba_castellanii_str_neff'],
                   	   'exclude'  => undef, 
  				   	   'homology_types' => ['ortholog_one2one','apparent_ortholog_one2one'],		       
                 	 },   

          # Fungi
          'EF_1' => { 'compara'  => 'fungi',   
 				   	  'source'   => 'schizosaccharomyces_pombe', 
					  'target'   => undef,
                   	  'exclude'  => ['saccharomyces_cerevisiae'], 
  				   	  'homology_types' => ['ortholog_one2one','apparent_ortholog_one2one'],		       
                 	},   

          'EF_2' => { 'compara'  => 'fungi',   
 				   	  'source'   => 'saccharomyces_cerevisiae', 
					  'target'   => undef,
                   	  'exclude'  => ['schizosaccharomyces_pombe'], 
  				   	  'homology_types' => ['ortholog_one2one','apparent_ortholog_one2one'],		       
                 	},   

          # Metazoa
          'EM_1' => { 'compara'  => 'metazoa',   
 				   	  'source'   => 'caenorhabditis_elegans', 
					  'target'   => ['caenorhabditis_brenneri', 'caenorhabditis_briggsae', 'caenorhabditis_japonica', 'caenorhabditis_remanei', 'pristionchus_pacificus', 'brugia_malayi', 'onchocerca_volvulus', 'strongyloides_ratti', 'loa_loa', 'trichinella_spiralis'],
                   	  'exclude'  => undef, 
  				   	  'homology_types' => ['ortholog_one2one','apparent_ortholog_one2one'],		       
                 	},   

          'EM_2' => { 'compara'  => 'metazoa',   
 				   	  'source'   => 'drosophila_melanogaster', 
					  'target'   => ['drosophila_ananassae', 'drosophila_erecta', 'drosophila_grimshawi', 'drosophila_mojavensis','drosophila_persimilis' ,'drosophila_pseudoobscura', 'drosophila_sechellia', 'drosophila_simulans', 'drosophila_virilis', 'drosophila_willistoni', 'drosophila_yakuba'],
                   	  'exclude'  => undef, 
  				   	  'homology_types' => ['ortholog_one2one','apparent_ortholog_one2one'],		       
                 	},   

    	},

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

# override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;
  return 
      ' -reg_conf ' . $self->o('registry'),
  ;
}

# these parameter values are visible to all analyses, 
# can be overridden by parameters{} and input_id{}
sub pipeline_wide_parameters {  
    my ($self) = @_;
    return {
            %{$self->SUPER::pipeline_wide_parameters},  # here we inherit anything from the base class
            'perc_id'  => $self->o('perc_id'),
            'perc_cov' => $self->o('perc_cov'),
    };
}


sub pipeline_analyses {
    my ($self) = @_;
 
    return [
    {  -logic_name    => 'backbone_fire_DumpOrthologs',
       -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -input_ids     => [ {} ] , 
       -flow_into 	  => { '1' => ['SourceFactory'], }
    },   
 
    {  -logic_name    => 'SourceFactory',
       -module        => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::SourceFactory',
       -parameters    => { 'species_config'  => $self->o('species_config'), }, 
       -flow_into     => { '2' => ['MLSSJobFactory'], },          
       -rc_name       => 'default',
    },    
 
    {  -logic_name    => 'MLSSJobFactory',
       -module        => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::MLSSJobFactory',
       -parameters    => { 'method_link_type' => $self->o('method_link_type'), },
       -flow_into     => { '2' => ['GetOrthologs'], },
       -rc_name       => 'default',
    },
  
    {  -logic_name    => 'GetOrthologs',
       -module        => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile',
       -parameters    => {	'eg' 			   => $self->o('eg'),
       						'output_dir'       => $self->o('output_dir'),
							'method_link_type' => $self->o('method_link_type'),
    	 				 },
       -batch_size    =>  1,
       -rc_name       => 'default',
	   -hive_capacity => $self->o('getOrthologs_capacity'), 
	   -flow_into     => { '-1' => 'GetOrthologs_16GB', }, 
	 },
	 
    {  -logic_name    => 'GetOrthologs_16GB',
       -module        => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile',
       -parameters    => {	'output_dir'             => $self->o('output_dir'),
							'method_link_type'       => $self->o('method_link_type'),
    	 				 },
       -batch_size    =>  1,
       -rc_name       => '16Gb_mem',
	   -hive_capacity => $self->o('getOrthologs_capacity'), 
	   -flow_into     => { '-1' => 'GetOrthologs_32GB', }, 
	 },

    {  -logic_name    => 'GetOrthologs_32GB',
       -module        => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile',
       -parameters    => {	'output_dir'             => $self->o('output_dir'),
							'method_link_type'       => $self->o('method_link_type'),
    	 				 },
       -batch_size    =>  1,
       -rc_name       => '32Gb_mem',
	   -hive_capacity => $self->o('getOrthologs_capacity'), 
	 },
	 	 
  ];
}

sub resource_classes {
  my ($self) = @_;
  return {
    'default'           => {'LSF' => '-q production-rh6 -M  4000 -R "rusage[mem=4000]"'},
    'normal'            => {'LSF' => '-q production-rh6 -M  4000 -R "rusage[mem=4000]"'},
    '2Gb_mem'           => {'LSF' => '-q production-rh6 -M  2000 -R "rusage[mem=2000]"'},
    '4Gb_mem'           => {'LSF' => '-q production-rh6 -M  4000 -R "rusage[mem=4000]"'},
    '8Gb_mem'           => {'LSF' => '-q production-rh6 -M  8000 -R "rusage[mem=8000]"'},
    '12Gb_mem'          => {'LSF' => '-q production-rh6 -M 12000 -R "rusage[mem=12000]"'},
    '16Gb_mem'          => {'LSF' => '-q production-rh6 -M 16000 -R "rusage[mem=16000]"'},
    '24Gb_mem'          => {'LSF' => '-q production-rh6 -M 24000 -R "rusage[mem=24000]"'},
    '32Gb_mem'          => {'LSF' => '-q production-rh6 -M 32000 -R "rusage[mem=32000]"'},
    '2Gb_mem_4Gb_tmp'   => {'LSF' => '-q production-rh6 -M  2000 -R "rusage[mem=2000,tmp=4000]"'},
    '4Gb_mem_4Gb_tmp'   => {'LSF' => '-q production-rh6 -M  4000 -R "rusage[mem=4000,tmp=4000]"'},
    '8Gb_mem_4Gb_tmp'   => {'LSF' => '-q production-rh6 -M  8000 -R "rusage[mem=8000,tmp=4000]"'},
    '12Gb_mem_4Gb_tmp'  => {'LSF' => '-q production-rh6 -M 12000 -R "rusage[mem=12000,tmp=4000]"'},
    '16Gb_mem_4Gb_tmp'  => {'LSF' => '-q production-rh6 -M 16000 -R "rusage[mem=16000,tmp=4000]"'},
    '16Gb_mem_16Gb_tmp' => {'LSF' => '-q production-rh6 -M 16000 -R "rusage[mem=16000,tmp=16000]"'},
    '24Gb_mem_4Gb_tmp'  => {'LSF' => '-q production-rh6 -M 24000 -R "rusage[mem=24000,tmp=4000]"'},
    '32Gb_mem_4Gb_tmp'  => {'LSF' => '-q production-rh6 -M 32000 -R "rusage[mem=32000,tmp=4000]"'},
  }
}

1;
