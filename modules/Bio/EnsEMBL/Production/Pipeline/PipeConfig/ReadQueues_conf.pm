=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::ReadQueues_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::ReadQueues_conf;

use strict;
use warnings;
use File::Spec;
use Bio::EnsEMBL::Hive::Version 2.3;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  

sub default_options {
    my ($self) = @_;

    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() },      

	## General parameters
    'registry'      => $self->o('registry'),   
    'release'       => $self->o('release'),
    'pipeline_name' => $self->o('hive_dbname'),       
    'email'         => $self->o('ENV', 'USER').'@ebi.ac.uk',
    'output_dir'    => '/nfs/nobackup/ensemblgenomes/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name'),     

    ## Messaging Queue Server
    'queue_host'  => 'ebi-007.ebi.ac.uk',#$self->o('queue_host'),
    'queue_port'  => '61613',#$self->o('queue_port'),
    
###    
	## Email Report subject
    'email_subject'       	   => $self->o('pipeline_name').' GPAD loading pipeline has finished',

    ## Remove existing GO annotations
    # on '1' by default
#    'delete_existing' => 1,


    ## hive_capacity values for analysis
#    'gpad_capacity'  => '50',

	 'queue_config' => { 
	 	  '1'=>{
	 	  		# physical queue name 
	 	  		'queue'  => 'q_InterProScan', 
	 			'id'     => 'queue1', 
	 	       }, 
		  '2'=>{
	 	  		'queue'  => 'q_FTP_annotation', 
	 			'id'     => 'queue2',
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
            %{$self->SUPER::pipeline_wide_parameters},    # here we inherit anything from the base class
		    'pipeline_name'   => $self->o('pipeline_name'), # This must be defined for the beekeeper to work properly
		    'output_dir'      => $self->o('output_dir'), 
#            'delete_existing' => $self->o('delete_existing'),		    
    };
}

sub resource_classes {
    my $self = shift;
    return {
      'default'  	=> {'LSF' => '-q production-rh7 -n 4 -M 4000   -R "rusage[mem=4000]"'},
      '32GB'  	 	=> {'LSF' => '-q production-rh7 -n 4 -M 32000  -R "rusage[mem=32000]"'},
      '64GB'  	 	=> {'LSF' => '-q production-rh7 -n 4 -M 64000  -R "rusage[mem=64000]"'},
      '128GB'  	 	=> {'LSF' => '-q production-rh7 -n 4 -M 128000 -R "rusage[mem=128000]"'},
      '256GB'  	 	=> {'LSF' => '-q production-rh7 -n 4 -M 256000 -R "rusage[mem=256000]"'},
	}
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
    {  -logic_name => 'backbone_fire_ReadQueues',
       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -input_ids  => [ {} ] , 
       -flow_into  => {
		                 '1->A' => ['queue_factory'],
		                 'A->1' => ['email_notification'],		                       
                       },          
    },   

    { -logic_name    => 'queue_factory',
      -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -parameters    => {
						    'queue_config'  => $self->o('queue_config'),
                        }, 
      -hive_capacity => 10,
      -rc_name 	     => 'default',     
      -flow_into     => { '2' => ['read_events'], }
    },   

    { -logic_name    => 'read_events',
  	  -module        => 'Bio::EnsEMBL::Production::Pipeline::Queue::ReadEvents',
      -parameters    => {
            'queue_host' => $self->o('queue_host'),
            'queue_port' => $self->o('queue_port'),
       },
      -hive_capacity => 10,
      -rc_name 	     => 'default',     
#      -flow_into    => { '2' => ['gpad_file_load'], }
    },   

    { -logic_name    => 'email_notification',
      -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -parameters    => {
          	'email'      => $self->o('email'),
          	'subject'    => $self->o('email_subject'),
			'output_dir' => $self->o('output_dir'),
       },
      -rc_name 	      => 'default',     
	  -meadow_type    => 'LOCAL',
    },  
    
  ];
}


1;
