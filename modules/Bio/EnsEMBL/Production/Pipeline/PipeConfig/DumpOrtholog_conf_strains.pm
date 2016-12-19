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
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf_strains;

use strict;
use warnings;
use Bio::EnsEMBL::Hive::Version 2.3;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpOrtholog_conf');  

sub default_options {
    my ($self) = @_;

    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() },      

        'registry'         => '',   
        'pipeline_name'    => $self->o('hive_dbname'),       
        'output_dir'       => '/lustre/scratch110/ensembl/tm6/'.$self->o('pipeline_name'),
		'method_link_type' => 'ENSEMBL_ORTHOLOGUES',

     	## Set to '1' for eg! run 
        #   default => OFF (0)
  	    'eg' => 0,

        # hive_capacity values for analysis
	    'getOrthologs_capacity'  => '50',

        # orthologs cutoff
        'perc_id'  => '30',
        'perc_cov' => '66',

        # 'target' & 'exclude' are mutually exclusive
        #  only one of those should be defined if used 
	 	'species_config' => 
		{ 

          '1' => {	'compara'  => 'multi',   
 				   	'source'   => 'mus_musculus', 
                                        'target'   => ['mus_musculus_129s1svimj','mus_musculus_aj','mus_musculus_akrj','mus_musculus_balbcj','mus_musculus_c3hhej','mus_musculus_c57bl6nj','mus_musculus_casteij','mus_musculus_cbaj','mus_musculus_dba2j','mus_musculus_fvbnj','mus_musculus_lpj','mus_musculus_nodshiltj','mus_musculus_nzohlltj','mus_musculus_pwkphj','mus_musculus_wsbeij'],
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


1;
