=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::Core_handover_conf;

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

        ### Allow pipeline to run on species without declarations. Use it with -species parameter
        force => 0,
        
        release => software_version(),

        run_all => 0,

        bin_count => '150',

        max_run => '100',
        
        ### Defaults 
        
        pipeline_name => 'core_handover_update_'.$self->o('release'),
        
        email => $self->o('ENV', 'USER').'@ebi.ac.uk',

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
          force => $self->o('force'),
        },
        -input_ids  => [ {} ],
        -max_retry_count  => 10,
        -flow_into  => {
         #'5->A'  => ['ConstitutiveExonsVega', 'PepStatsVega'],
         '3->A'  => ['PercentRepeat', 'CodingDensity', 'ShortNonCodingDensity'],
         '2->A'  => ['GeneGC', 'PepStats', 'GeneCount', 'ConstitutiveExons', 'GenomeStats'],
         'A->1'  => ['Notify'], 
        },
      },

      {
        -logic_name => 'ConstitutiveExons',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::ConstitutiveExons',
        -parameters => {
          dbtype => 'core',
        },
        -max_retry_count  => 3,
        -hive_capacity    => 5,
        -rc_name          => 'normal',
      },

      {
        -logic_name => 'PepStats',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::PepStats',
        -parameters => {
          tmpdir => '/tmp',
          pepstats_binary => 'pepstats',
          dbtype => 'core',
        },
        -max_retry_count  => 3,
        -hive_capacity    => 5,
        -rc_name          => 'mem',
      },

#      {
#        -logic_name => 'ConstitutiveExonsVega',
#        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::ConstitutiveExons',
#        -parameters => {
#          dbtype => 'vega',
#        },
#        -max_retry_count  => 5,
#        -hive_capacity    => 10,
#        -rc_name          => 'normal',
#        -can_be_empty     => 1,
#      },

#      {
#        -logic_name => 'PepStatsVega',
#        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::PepStats',
#        -parameters => {
#          tmpdir => '/tmp', binpath => '/software/pubseq/bin/emboss',
#          dbtype => 'vega',
#        },
#        -max_retry_count  => 5,
#        -hive_capacity    => 10,
#        -rc_name          => 'mem',
#        -can_be_empty     => 1,
#      },

      {
        -logic_name => 'GeneCount',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::GeneCount',
        -max_retry_count  => 3,
        -hive_capacity    => 5,
        -rc_name          => 'mem',
      },

      {
        -logic_name => 'GenomeStats',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::GenomeStats',
        -max_retry_count  => 3,
        -hive_capacity    => 5,
        -rc_name          => 'normal',
      },

      {
        -logic_name => 'ShortNonCodingDensity',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::ShortNonCodingDensity',
        -parameters => {
          logic_name => 'shortnoncodingdensity', value_type => 'sum',
        },
        -max_retry_count  => 3,
        -hive_capacity    => 5,
        -rc_name          => 'normal',
        -can_be_empty     => 1,
        -flow_into => ['PseudogeneDensity'],
      },

      {
        -logic_name => 'LongNonCodingDensity',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::LongNonCodingDensity',
        -parameters => {
          logic_name => 'longnoncodingdensity', value_type => 'sum',
        },
        -max_retry_count  => 3,
        -hive_capacity    => 5,
        -rc_name          => 'normal',
        -can_be_empty     => 1,
      },

      {
        -logic_name => 'PseudogeneDensity',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::PseudogeneDensity',
        -parameters => {
          logic_name => 'pseudogenedensity', value_type => 'sum',
        },
        -max_retry_count  => 3,
        -hive_capacity    => 5,
        -rc_name          => 'normal',
        -can_be_empty     => 1,
      },

      {
        -logic_name => 'CodingDensity',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::CodingDensity',
        -parameters => {
          logic_name => 'codingdensity', value_type => 'sum',
        },
        -max_retry_count  => 3,
        -hive_capacity    => 5,
        -rc_name          => 'normal',
        -can_be_empty     => 1,
        -flow_into  => {
         1  => ['LongNonCodingDensity'],
        },
      },

      {
        -logic_name => 'GeneGC',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::GeneGC',
        -max_retry_count  => 3,
        -hive_capacity    => 5,
        -rc_name => 'normal',
      },

      {
        -logic_name => 'PercentGC',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::PercentGC',
        -parameters => {
          table => 'repeat', logic_name => 'percentgc', value_type => 'ratio',
        },
        -max_retry_count  => 3,
        -hive_capacity    => 5,
        -rc_name          => 'normal',
        -can_be_empty     => 1,
      },

      {
        -logic_name => 'PercentRepeat',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::PercentRepeat',
        -parameters => {
          logic_name => 'percentagerepeat', value_type => 'ratio',
        },
        -max_retry_count  => 3,
        -hive_capacity    => 5,
        -rc_name          => 'mem',
        -can_be_empty     => 1,
        -flow_into  => {
         1  => ['PercentGC'], 
        },
      },

      ####### NOTIFICATION
      
      {
        -logic_name => 'Notify',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::EmailSummaryCore',
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
        bin_count => $self->o('bin_count'),
        max_run => $self->o('max_run'),
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
      'default' => { 'LSF' => ''},
      'normal'  => { 'LSF' => '-q production-rh7 -M 500 -R "rusage[mem=500]"'},
      'mem'     => { 'LSF' => '-q production-rh7 -M 2000 -R "rusage[mem=2000]"'},
    }
}

1;
