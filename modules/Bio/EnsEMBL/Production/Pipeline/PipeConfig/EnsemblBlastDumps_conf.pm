=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::EnsemblBlastDumps_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');
use Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;
use File::Spec::Functions qw(catdir);


sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    
    #load default from mysql dumps
    %{Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf::default_options($self)},

    skip_convert_fasta => 1,
    #registry 
    registry          => $self->o('registry'),
    # Metadata Report Script
    species           => [],
    division          => [],
    base_dir          => $self->o('ENV', 'BASE_DIR'),
    ensembl_version   => $self->o('ENV', 'ENS_VERSION'),
    eg_version        => $self->o('ENV', 'EG_VERSION'),
    division_list     => ['vertebrates','fungi','metazoa','plants','protists'],  #'bacteria'  

    ## fasta parameters
    # types to emit
    dna_sequence_type_list => [ 'dna' ],
    pep_sequence_type_list => [ 'cdna', 'ncrna' ],
    prev_rel_dir           => '/nfs/ftp/ensemblftp/ensembl/PUBLIC/pub/',

    #Mysql Dumps Params
    # Database type factory
    group => ['core'],

    # By default, files are not written if the parent directory
    # (which is the database name) exists.
    overwrite => 0,
    dump_dir  => undef,
  };
}

# Implicit parameter propagation throughout the pipeline.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
     username        => $self->o('username'),
     dump_dir        => $self->o('dump_dir') 
  };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},
        'mkdir -p ' . $self->o('dump_dir'),
    ];
}

sub pipeline_analyses {
  my $self = shift @_;

  return [  

    @{Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf::pipeline_analyses($self)},  
    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -max_retry_count   => 1,
      -analysis_capacity => 20,
      -flow_into         => {
        '2' => ['Dumps']
      }
        
    },
  
    { 
      -logic_name        => 'Dumps',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -flow_into         => { '1->A' => ['fasta_pep', 'fasta_dna'], 'A->1' => 'checksum_generator' },
    },
    {
      -logic_name        => 'Email',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailNotify',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -parameters        => {
        email         => $self->o('email'),
        pipeline_name => $self->o('pipeline_name'),
      },
    },
    {
      -logic_name      => 'checksum_generator',
      -module        => 'Bio::EnsEMBL::Production::Pipeline::Common::ChksumGenerator',
      -parameters    => {
        dumps              => ['fasta_pep', 'fasta_dna'],
        # skip_convert_fasta => '#expr( #dump_division# eq "vertebrates" ? 1 : 0 )expr#',  
      },
      -hive_capacity => 10,
    },
    {
     -logic_name      => 'fasta_pep',
     -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::DumpFile',
     -parameters      => {
        sequence_type_list  => ['cdna','ncrna'],
        process_logic_names => $self->o('process_logic_names'),
        skip_logic_names    => $self->o('skip_logic_names'),
        base_path           => '#base_path#',
      },
      -can_be_empty    => 1,
      -max_retry_count => 1,
      -hive_capacity   => 20,
      -priority        => 5,
      -rc_name         => '2GB',
    },
    { 
      -logic_name      => 'fasta_dna',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::DumpFile',
      -parameters      => {
        sequence_type_list  => $self->o('dna_sequence_type_list'),
        process_logic_names => $self->o('process_logic_names'),
        skip_logic_names    => $self->o('skip_logic_names'),
       },
      -can_be_empty    => 1,
      -flow_into       => { 1 => 'concat_fasta' },
      -max_retry_count => 1,
      -hive_capacity   => 20,
      -priority        => 5,
      -rc_name         => '4GB',
    },
   
    { 
      -logic_name      => 'concat_fasta',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::ConcatFiles',
      -can_be_empty    => 1,
      -parameters      => {
        blat_species => $self->o('blat_species'),
      },
      -max_retry_count => 5,
      -priority        => 5,
      -flow_into         => WHEN('#dump_division# eq "vertebrates"' => ['primary_assembly'])
    },
    {
      -logic_name      => 'primary_assembly',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::FASTA::CreatePrimaryAssembly',
      -can_be_empty    => 1,
      -max_retry_count => 5,
      -priority        => 5,
    },	

  ];
} 

1;
