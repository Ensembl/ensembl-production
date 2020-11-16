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

=cut

=pod

=head1 NAME  

Bio::EnsEMBL::Production::Pipeline::PipeConfig::WebDataFile_conf

=head1 DESCRIPTION

This pipeline automate current manual processing of the 7 species (https://2020.ensembl.org/app/species-selector) currently available on 2020 website.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::WebDataFile_conf;
use strict;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;

use Data::Dumper;

sub default_options {
    my $self = shift;
    return {
        %{$self->SUPER::default_options()},
        species         => [],
        division        => [],
        antispecies     => [],
        run_all         => 0, #always run every species
        step             => [],  
        genomeinfo_yml    => undef,
        ftp_pub_path     =>  '/nfs/panda/ensembl/production/ensemblftp',
        ENS_BIN_NUMBER   => 150, 
        write_seqs_out   => 1,
        # Email Report subject
        email_subject => $self->o('pipeline_name').'  pipeline has finished',
         
	};
}

sub pipeline_wide_parameters {
    my $self = shift;
    return { %{$self->SUPER::pipeline_wide_parameters()},
        output_path       => $self->o('output_path'),
        ENS_VERSION       => $self->o('ENS_VERSION'),  
        EG_VERSION        => $self->o('EG_VERSION'),
        ftp_pub_path      => $self->o('ftp_pub_path'),
        ENS_BIN_NUMBER    => $self->o('ENS_BIN_NUMBER'),  
    };
}

sub pipeline_analyses {
    my $self = shift;

    return [

        {
            -logic_name => 'SpeciesFactory',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            -input_ids  => [ {} ], # required for automatic seeding
            -parameters => { species => $self->o('species'),
                antispecies          => $self->o('antispecies'),
                division             => $self->o('division'),
                run_all              => $self->o('run_all') 
             },
            -flow_into  => { '2->A' => [ 'GenomeInfo' ],
                             'A->1' => ['email_notification']
                           },
             
        },
        {
          -logic_name => 'GenomeInfo',          
          -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenomeInfo',
          -flow_into  => {'1' => ['StepBootstrap']},
          
        },
        {    
            -logic_name => 'StepBootstrap',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFileBootstrap',
            -parameters => { current_step       => 'bootstrap',
                             step => $self->o('step')
                           }, 
            -flow_into        => {
                      '1' =>  ['StepGeneAndTranscript'],
                      '2' =>  ['StepContigs'],
                      '3' =>  ['StepGC'],
                      '4' =>  ['StepVariation'],
            },

        },
        {   -logic_name => 'StepGeneAndTranscript',
              -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFileGeneAndTranscript',
             -rc_name    => 'large', 
        },
        {   -logic_name => 'StepContigs',
              -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFileContigs',
        },
        {   -logic_name => 'StepGC',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFileGenerateGC',
             -rc_name    => 'large',
	},
        {   -logic_name => 'StepVariation',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFileVariation',
            -rc_name     => 'large', 
        },
        {
           -logic_name => 'email_notification',
           -module     => 'Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
           -parameters => {
                           'email'   => $self->o('email'),
                           'subject' => 'Webdatafile pipeline  completed',
                           'text'    => 'Output location : '. $self->o('output_path'), 
                          },
        },

 

    ];
} ## end sub pipeline_analyses

sub resource_classes {
  my ($self) = @_;

  return {
    %{$self->SUPER::resource_classes},
    'small' => { 'LSF' => '-q production-rh74 -M 200 -R "rusage[mem=200]"'},
    'mem'   => { 'LSF' => '-q production-rh74 -M 3000 -R "rusage[mem=3000]"'},
    'large' => { 'LSF' => '-q production-rh74 -M 10000 -R "rusage[mem=10000]"'},
  }
}



1;
