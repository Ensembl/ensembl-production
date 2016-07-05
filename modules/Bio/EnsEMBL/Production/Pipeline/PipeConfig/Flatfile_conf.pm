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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::Flatfile_conf;

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
      
      #'registry' => 'Reg.pm', # default option to refer to Reg.pm, should be full path
      #'base_path' => '', #where do you want your files
      
      ### Optional overrides        
      species => [],
      
      release => software_version(),

      types => [],
      
      ### Defaults 
      
      pipeline_name => 'flatfile_dump_'.$self->o('release'),
      
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
        -module     => 'Bio::EnsEMBL::Production::Pipeline::SpeciesFactory',
        -parameters => {
          species => $self->o('species'),
          randomize => 1,
        },
        -input_ids  => [ {} ],
        -flow_into  => {
          1 => 'Notify',
          2 => ['DumpTypeFactory'],
        },
      },
      
      ######### DUMPING DATA
      
      {
        -logic_name => 'DumpTypeFactory',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpTypeFactory',
        -parameters => {
          types => $self->o('types'),
        },
        -flow_into  => {
          2 => { 'DumpFlatfile' => { species => "#species#", type => "#type#" },
		 'CheckFlatfile' => { species => "#species#", type => "#type#" },
                 'ChecksumGenerator' => { species => "#species#", type => "#type#" },
          },
        },
      },
      
      {
        -logic_name => 'DumpFlatfile',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile',
        -max_retry_count  => 1,
        -analysis_capacity => 10,
        -rc_name => 'dump',
      },
      
      ####### CHECK

      {
       -logic_name => 'CheckFlatfile',
       -module     => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::CheckFlatfile',
       -wait_for   => [qw/DumpFlatfile/],
       -analysis_capacity => 15,
       -rc_name => 'check',
      },
      
      {
        -logic_name => 'ChecksumGenerator',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::ChecksumGenerator',
        -wait_for   => [qw/DumpFlatfile/],
        -analysis_capacity => 10, 
      },
      
      ####### NOTIFICATION
      
      {
        -logic_name => 'Notify',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
        -parameters => {
          email   => $self->o('email'),
          subject => $self->o('pipeline_name').' has finished',
          text    => 'Your pipeline has finished. Please consult the hive output'
        },
        -wait_for   => [qw/ CheckFlatfile ChecksumGenerator /],
      }
    
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    
    return {
        %{ $self->SUPER::pipeline_wide_parameters() },  # inherit other stuff from the base class
        base_path => $self->o('base_path'),
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
      %{$self->SUPER::resource_classes()},
      dump => { 'LSF' => '-q normal -M1500 -R"select[mem>1500] rusage[mem=1500]"'},
      check => { 'LSF' => '-q normal -M500 -R"select[mem>500] rusage[mem=500]"'},
    }
}

1;
