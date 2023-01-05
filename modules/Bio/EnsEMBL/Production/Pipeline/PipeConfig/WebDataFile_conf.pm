=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

This pipeline automate current manual processing of the 7 species
(https://2020.ensembl.org/app/species-selector) currently available
on 2020 website.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::WebDataFile_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    species     => [],
    division    => [],
    antispecies => [],
    run_all     => 0,

    step           => [],
    ENS_BIN_NUMBER => 150, 
    write_seqs_out => 1,
	};
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{$self->SUPER::pipeline_wide_parameters()},
    output_path    => $self->o('output_path'),
    ENS_VERSION    => $self->o('ENS_VERSION'),  
    EG_VERSION     => $self->o('EG_VERSION'),
    ftp_pub_path   => $self->o('ftp_pub_path'),
    ENS_BIN_NUMBER => $self->o('ENS_BIN_NUMBER'),
    write_seqs_out => $self->o('write_seqs_out'),     
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name => 'SpeciesFactory',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -input_ids  => [ {} ],
      -parameters => {
                      species     => $self->o('species'),
                      division    => $self->o('division'),
                      antispecies => $self->o('antispecies'),
                      run_all     => $self->o('run_all') 
                     },
      -flow_into  => {
                      '2->A' => ['GenomeInfo'],
                      'A->1' => ['EmailNotification']
                     },
    },
    {
      -logic_name => 'GenomeInfo',          
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenomeInfo',
      -flow_into  => ['StepBootstrap'],
    },
    {    
      -logic_name => 'StepBootstrap',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenomeAssemblyInfo',
      -parameters => {
                      current_step => 'bootstrap',
                      step         => $self->o('step')
                     },
      -flow_into  => {
                      '2' =>  ['StepGeneAndTranscript'],
                      '3' =>  ['StepContigs'],
                      '4' =>  ['StepGC'],
                      '5' =>  ['StepVariation'],
                     },
    },
    {
      -logic_name => 'StepGeneAndTranscript',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::GeneAndTranscript',
      -rc_name    => '8GB', 
    },
    {
      -logic_name => 'StepContigs',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::Contigs',
    },
    {
      -logic_name => 'StepGC',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenerateGC',
      -rc_name    => '8GB',
    },
    {
      -logic_name => 'StepVariation',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::Variation',
      -rc_name    => '8GB', 
    },
    {
      -logic_name => 'EmailNotification',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
      -parameters => {
                      'email'   => $self->o('email'),
                      'subject' => 'Webdatafile pipeline completed',
                      'text'    => 'Output location : '. $self->o('output_path'), 
                     },
    },
  ];
}

1;
