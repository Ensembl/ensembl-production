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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::Ga4gh_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;
use File::Spec;

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options()},

        ## General parameters
        'release'                => $self->o('ensembl_release'),
        'pipeline_name'          => "ga4gh_checksum_generator_".$self->o('ensembl_release'),
        'web_email'              => '',
        'sequence_types'         => [],
	'run_all'                => 0, 
        ## 'job_factory' parameters
        'species'                => [],
        'antispecies'            => [],
        'division'               => [],
        'dbname'                 => undef,
	#checksum params
	'sequence_type'         => [],
	'hash_type'             => [],
    };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands}
  ];
}

# Ensures output parameters gets propagated implicitly
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
    'pipeline_name' => $self->o('pipeline_name'),
    'release'       => $self->o('release'),
    'sequence_types'         => $self->o('sequence_type'),
    'hash_types'             => $self->o('hash_type'),


  };
}

sub resource_classes {
  my ($self) = @_;

  return {
    %{$self->SUPER::resource_classes},
     '64GB' => { 'LSF' => '-q '.$self->o('production_queue').' -M  64000 -R "rusage[mem=64000]"' },
    '128GB' => { 'LSF' => '-q '.$self->o('production_queue').' -M 128000 -R "rusage[mem=128000]"' },
    '256GB' => { 'LSF' => '-q '.$self->o('production_queue').' -M 256000 -R "rusage[mem=256000]"' },
  }
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        { 
            -logic_name      => 'species_factory',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            -parameters      => {
                species      => $self->o('species'),
                antispecies  => $self->o('antispecies'),
                division     => $self->o('division'),
                dbname       => $self->o('dbname'),
                run_all      => $self->o('run_all'),
            },
            -input_ids       => [ {} ],
            -hive_capacity   => -1,
            -max_retry_count => 1,
            -flow_into       => { '2' => 'job_factory', },
        },
        { -logic_name      => 'job_factory',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -hive_capacity => -1,
            -flow_into => { '1' => 'fetch_sequences' }
        },
        { -logic_name      => 'fetch_sequences',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::FetchSequence',
            -hive_capacity => -1,
	    -flow_into => { '2' => 'toplevel_checksum', '3' => 'cdna_checksum' , '4'=> 'cds_checksum', '5'=> 'pep_checksum' }
        },
        { -logic_name      => 'toplevel_checksum',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::SecureHashGenerator',
            -hive_capacity => 50,
            -rc_name       => '2GB',

        },
        { -logic_name      => 'cdna_checksum',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::SecureHashGenerator',
            -hive_capacity => 50,
            -rc_name       => '2GB',

        },
        { -logic_name      => 'cds_checksum',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::SecureHashGenerator',
            -hive_capacity => 50,
            -rc_name       => '2GB',

        },
        { -logic_name      => 'pep_checksum',
            -module        => 'Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::SecureHashGenerator',
            -hive_capacity => 50,
            -rc_name       => '2GB',

        },
	
    ];
}

1;

