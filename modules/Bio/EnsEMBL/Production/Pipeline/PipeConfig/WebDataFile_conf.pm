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

registry=${BASR_DIR}/ensembl-production_private/release_coordination/registries/reg_ens-sta-1_rw.pm
HIVE_SRV=mysql-ens-hive-prod-1-ensadmin
init_pipeline.pl Bio::EnsEMBL::Production::Pipeline::PipeConfig::WebDataFile_conf \
 -registry ${registry} \
 $($HIVE_SRV details hive) \
 -pipeline_name Webdatafile_${ENS_VERSION} \
 -release ${ENS_VERSION} \
 -output_path /hps/nobackup2/production/ensembl/${USER}/test_webdatafile \
 -hive_force_init 1 \
 -run_all 1 \
 -app_path ${BASE_DIR}/e2020_march_datafiles/ \
 -genomeinfo_yml ${BASE_DIR}/e2020_march_datafiles/common_files/genome_id_info.yml \
 -email ${USER}@ebi.ac.uk

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::WebDataFile_conf;
use strict;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');
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
        # Email Report subject
        email_subject => $self->o('pipeline_name').'  pipeline has finished',
        release => software_version()
	};
}

sub pipeline_wide_parameters {
    my $self = shift;
    return { %{$self->SUPER::pipeline_wide_parameters()},
        output_path       => $self->o('output_path'),
        app_path          => $self->o('app_path'),
        genomeinfo_yml    => $self->o('genomeinfo_yml')
    };
}

sub pipeline_analyses {
    my $self = shift;

    return [
        
        { 
          -logic_name  => 'GeneInfo_logic',
          -input_ids  => [ {} ],
          -module      =>  'Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenomeInfoYml',
          -parameters => { species => $self->o('species'),
                           genomeinfo_yml => $self->o('genomeinfo_yml'), 
                           run_all        => $self->o('run_all'),   
                         },
          -flow_into   =>  {  '2->A' => ['StepBootstrap'],
                              '3->A'  => ['SpeciesFactory'],   
                               # WHEN(
                               #   '#genomeinfo_yml#' =>  ['StepBootstrap'],
                               #    ELSE                  ['SpeciesFactory'],
                               # ),
                              'A->1' => ['email_notification'],   
                           }

        }, 

        {
            -logic_name => 'SpeciesFactory',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            #-input_ids  => [ {} ], # required for automatic seeding
            -parameters => { species => $self->o('species'),
                antispecies          => $self->o('antispecies'),
                division             => $self->o('division'),
                run_all              => $self->o('run_all') 
             },
            -flow_into  => { '2' => [ 'StepBootstrap' ],
                             #'A->1' => ['email_notification']
                           },
             
        },
        {    
            -logic_name => 'StepBootstrap',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFile',
            -parameters => { current_step       => 'bootstrap',
                             step => $self->o('step',)
                           }, 
            -flow_into        => {
                      '1' =>  ['StepGeneAndTranscript'],
                      '2' =>  ['StepContigs'],
                      '3' =>  ['StepGC'],
                      '4' =>  ['StepVariation'],
            },

        },
        {   -logic_name => 'StepGeneAndTranscript',
              -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFile',
        },
        {   -logic_name => 'StepContigs',
              -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFile',
        },
        {   -logic_name => 'StepGC',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFile',
	},
        {   -logic_name => 'StepVariation',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFile',
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

sub beekeeper_extra_cmdline_options {
    my $self = shift;
    return "-reg_conf " . $self->o("registry");
}

sub resource_classes {
    my $self = shift;
    return {
        '32g' => { LSF => '-q production-rh74 -M 32000 -R "rusage[mem=32000]"' },
        '100g' => { LSF => '-q production-rh74 -M 100000 -R "rusage[mem=100000]"' },
        '16g' => { LSF => '-q production-rh74 -M 16000 -R "rusage[mem=16000]"' },
        '8g'  => { LSF => '-q production-rh74 -M 16000 -R "rusage[mem=8000]"' },
        '4g'  => { LSF => '-q production-rh74 -M 4000 -R "rusage[mem=4000]"' },
        '1g'  => { LSF => '-q production-rh74 -M 1000 -R "rusage[mem=1000]"' } };
}

1;
