=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::GPAD_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

maurel@ebi.ac.uk and ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GPAD_conf;

use strict;
use warnings;
use File::Spec;
use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  
use File::Spec::Functions qw(catdir);

sub default_options {
    my ($self) = @_;

    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() },      

	## General parameters
    'registry'      => $self->o('registry'),   
    'release'       => $self->o('release'),
    'pipeline_name' => 'gpad_loader_'.$self->o('release'),
    'email'         => $self->o('ENV', 'USER').'@ebi.ac.uk',
    'output_dir'    => '/nfs/nobackup/ensembl/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name'),

    ## Location of GPAD files
    'gpad_directory' => '',

	## Email Report subject
    'email_subject'  => $self->o('pipeline_name').' GPAD loading pipeline has finished',

    ## Remove existing GO annotations and associated analysis
    # on '1' by default
    'delete_existing' => 1,

    ## 'job_factory' parameters
    'species'     => [], 
    'antispecies' => [qw/mus_musculus_129s1svimj mus_musculus_aj mus_musculus_akrj mus_musculus_balbcj mus_musculus_c3hhej mus_musculus_c57bl6nj mus_musculus_casteij mus_musculus_cbaj mus_musculus_dba2j mus_musculus_fvbnj mus_musculus_lpj mus_musculus_nodshiltj mus_musculus_nzohlltj mus_musculus_pwkphj mus_musculus_wsbeij/],
    'division' 	 => [], 
    'run_all'     => 0,	
    'meta_filters' => {},

    #analysis informations
    'logic_name' => 'goa_import',
    'db' => 'GO',
    'program' => 'goa_import',
    'production_lookup' => 1,
    'linked_tables' => ['object_xref']

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
    };
}

sub resource_classes {
    my $self = shift;
    return {
      'default'  	=> {'LSF' => '-q production-rh74 -n 4 -M 4000   -R "rusage[mem=4000]"'},
      '32GB'  	 	=> {'LSF' => '-q production-rh74 -n 4 -M 32000  -R "rusage[mem=32000]"'},
      '64GB'  	 	=> {'LSF' => '-q production-rh74 -n 4 -M 64000  -R "rusage[mem=64000]"'},
      '128GB'  	 	=> {'LSF' => '-q production-rh74 -n 4 -M 128000 -R "rusage[mem=128000]"'},
      '256GB'  	 	=> {'LSF' => '-q production-rh74 -n 4 -M 256000 -R "rusage[mem=256000]"'},
	}
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
    {  -logic_name => 'backbone_fire_GPADLoad',
       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -input_ids  => [ {} ] , 
       -flow_into  => {
		                 '1->A' => ['DbFactory'],
		                 'A->1' => ['RunXrefCriticalDatacheck'],		                       
                       },          
    },
    {
      -logic_name        => 'DbFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
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
                              'A->2' => ['SpeciesFactory'],
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
                                'object_xref',
                                'ontology_xref',
                              ],
                              output_file => catdir($self->o('output_dir'), '#dbname#', 'pre_pipeline_bkp.sql.gz'),
                            },
      -rc_name           => 'default',
      -flow_into         => {
                              '1->A' => ['AnalysisSetup'],
                              'A->1' => ['RemoveOrphans'],
      }
    },
    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::AnalysisSetup',
      -max_retry_count   => 0,
      -analysis_capacity => 20,
      -parameters        => {
                              db_backup_required => 0,
                              delete_existing => $self->o('delete_existing'),
                              production_lookup  => $self->o('production_lookup'),
                              logic_name => $self->o('logic_name'),
                              db => $self->o('db'),
                              program => $self->o('program'),
                              linked_tables => $self->o('linked_tables')
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
    },
        {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbAwareSpeciesFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              chromosome_flow    => 0,
                              otherfeatures_flow => 0,
                              regulation_flow    => 0,
                              variation_flow     => 0,
                            },
      -flow_into         => {
                              '2' => ['FindFile'],
                            }
    },
    { -logic_name     => 'FindFile',
      -module         => 'Bio::EnsEMBL::Production::Pipeline::GPAD::FindFile',
      -analysis_capacity  => 30,
      -rc_name 	      => 'default',
      -parameters     => {
                            gpad_directory => $self->o('gpad_directory')
      },
      -flow_into         => {
                  '2' => ['gpad_file_load'],
                }
    },
    { -logic_name     => 'gpad_file_load',
  	  -module         => 'Bio::EnsEMBL::Production::Pipeline::GPAD::LoadFile',
      -parameters     => {
                              delete_existing => $self->o('delete_existing'),
                              logic_name => $self->o('logic_name')
       },
      -analysis_capacity  => 20,
      -rc_name 	      => 'default'
    },
    {
      -logic_name        => 'RunXrefCriticalDatacheck',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters        => {
                              datacheck_groups => ['xref'],
                              datacheck_types  => ['critical'],
                              registry_file    => $self->o('registry'),
                              history_file    => $self->o('history_file'),
                              failures_fatal  => 1,
                            },
      -flow_into         => 'RunXrefAdvisoryDatacheck', 
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -batch_size        => 10,
    },
    {
      -logic_name        => 'RunXrefAdvisoryDatacheck',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters        => {
                              datacheck_groups => ['xref'],
                              datacheck_types  => ['advisory'],
                              registry_file    => $self->o('registry'),
                              history_file    => $self->o('history_file'),
                              failures_fatal  => 1,
                            },
      -flow_into         => 'email_notification',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -batch_size        => 10,
    },


    { -logic_name     => 'email_notification',
  	  -module         => 'Bio::EnsEMBL::Production::Pipeline::GPAD::GPADEmailReport',
      -parameters     => {
          	'email'      => $self->o('email'),
          	'subject'    => $self->o('email_subject'),
			'output_dir' => $self->o('output_dir'),
       },
      -rc_name 	      => 'default'
    },  
    
  ];
}


1;
