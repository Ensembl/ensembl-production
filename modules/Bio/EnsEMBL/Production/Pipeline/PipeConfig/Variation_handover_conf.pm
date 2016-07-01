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

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::Variation_handover_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
    my ($self) = @_;
    
    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() }, 
        
        ### OVERRIDE
        
        ### Optional overrides        
        species => [],
        
        release => software_version(),

        run_all => 0,

        bin_count => '150',

        max_run => '100',
        
        ### Defaults 
        
        pipeline_name => 'variation_handover_update_'.$self->o('release'),
        
        email => $self->o('ENV', 'USER').'@sanger.ac.uk',
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
      # inheriting database and hive tables' creation
      @{$self->SUPER::pipeline_create_commands}, 
    ];
}

## See diagram for pipeline structure 
sub pipeline_analyses {
    my ($self) = @_;
    
    return [
    
      {
        -logic_name => 'ScheduleSpecies',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::ClassSpeciesFactory',
        -parameters => {
          species => $self->o('species'),
          run_all => $self->o('run_all'),
          max_run => $self->o('max_run')
        },
        -input_ids  => [ {} ],
        -flow_into  => {
          'A->1' => ['Notify'],
          '4->A' => ['SnpDensity', 'SnpCount', 'NonSense', 'GenomeStats'],
        },
      },

      {
        -logic_name => 'SnpCount',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::SnpCount',
        -max_retry_count  => 2,
        -hive_capacity    => 10,
        -rc_name          => 'normal',
      },

      {
        -logic_name => 'SnpDensity',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::SnpDensity',
        -parameters => {
          table => 'gene', logic_name => 'snpdensity', value_type => 'sum',
          bin_count => $self->o('bin_count'), max_run => $self->o('max_run'),
        },
        -max_retry_count  => 2,
        -hive_capacity    => 10,
        -rc_name          => 'default',
      },

      {
        -logic_name => 'NonSense',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::NonSense',
        -parameters => {
          frequency => 0.1, observation => 20,
        },
        -max_retry_count  => 2,
        -hive_capacity    => 10,
        -rc_name          => 'default',
      },

      {
        -logic_name => 'GenomeStats',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::GenomeStats',
        -max_retry_count  => 3,
        -hive_capacity    => 100,
        -rc_name          => 'normal',
      },

      ####### NOTIFICATION
      
      {
        -logic_name => 'Notify',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::EmailSummaryVariation',
        -parameters => {
          email   => $self->o('email'),
          subject => $self->o('pipeline_name').' has finished',
        },
      }
    
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    
    return {
        %{ $self->SUPER::pipeline_wide_parameters() },  # inherit other stuff from the base class
        release => $self->o('release'),
    };
}

# override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
    my $self = shift;
    return "-reg_conf ".$self->o("registry");
}

sub resource_classes {
    my $self = shift;
    return {
      'default' => { 'LSF' => '-q normal'},
      'normal'  => { 'LSF' => '-q normal -M 500 -R"select[mem>500] rusage[mem=500]"'},
      'mem'     => { 'LSF' => '-q normal -M 1000 -R"select[mem>1000] rusage[mem=1000]"'},
    }
}

1;
