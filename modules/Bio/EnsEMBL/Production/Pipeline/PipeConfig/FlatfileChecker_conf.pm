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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::FlatfileChecker_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub default_options {
    my ($self) = @_;
    
    my $h = {
      # inherit other stuff from the base class
      %{ $self->SUPER::default_options() }, 
      
      # 'base_path' => '', #where do you want your files
      # 'type' => '',
      
      ### Defaults 
      
      pipeline_name => 'flatfile_dump_check_'.$self->o('type'),
      
    };
    $h->{pipeline_db}->{-driver} = 'sqlite';
    return $h;
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
      # inheriting database and hive tables' creation
      @{$self->SUPER::pipeline_create_commands}, 
    ];
}

sub pipeline_analyses {
  my ($self) = @_;
  return [
    {
      -logic_name => 'FindFiles',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -meadow_type => 'LOCAL',
      -parameters => {
        inputcmd => 'find '.$self->o('base_path').q{ -type f -name '*.dat.gz'},
        column_names => ['file'],
        randomize => 1
      },
      -input_ids  => [ {} ],
      -flow_into  => {
        2 =>  { CheckFlatfile => { file => '#file#'} }
      },
    },
    {
      -logic_name => 'CheckFlatfile',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Flatfile::CheckFlatfile',
      -analysis_capacity => 15,
      -rc_name => 'dump',
    },
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },
    type => $self->o('type'),
  };
}

sub resource_classes {
  my $self = shift;
  return {
    %{$self->SUPER::resource_classes()},
    dump => { 'LSF' => '-q normal -M3000 -R"select[mem>3000] rusage[mem=3000]"'},
  }
}

1;
