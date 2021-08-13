=head1 LICENSE
 
 See the NOTICE file distributed with this work for additional information
 regarding copyright ownership.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL:Production::Pipeline::PipeConfig::AlphaDBImport_conf:

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::AlphaDBImport_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;



=head2 default_options

 Arg [1]    : None
 Description: Create default hash for this configuration file
 Returntype : Hashref
 Exceptions : None

=cut

sub default_options {
  my ($self) = @_;

  return {
    %{$self->SUPER::default_options()},

    species => 'homo_sapiens',

    user_r => 'ensro',
    password => $ENV{EHIVE_PASS},
    user => 'ensadmin',
    pipe_db_host => 'mysql-ens-genebuild-prod-7',
    pipe_db_port => 4533,
    email_address => $ENV{USER}.'@ebi.ac.uk',
  };
}


sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
  }
}


sub pipeline_analyses {
  my ($self) = @_;

  my @analyses = (
    {
      -logic_name => 'load_alphadb',
      -module => 'Bio::EnsEMBL::Analysis::Hive::RunnableDB::HiveLoadAlphaFoldDBProteinFeatures',
      -input_ids  => [{}],
      -parameters => {
        output_path => $self->o('base_path'),
        core_dbhost => $self->o('host'),
        core_dbport => $self->o('port'),
        core_dbname => $self->o('dbname'),
        core_dbuser => $self->o('user'),
        core_dbpass => $self->o('pass'),
        cs_version => $self->o('cs_version'),
        species => $self->o('species'),
        alpha_path => $self->o('alpha_path')
      },
      -rc_name => '4GB',
    },
  );

  return \@analyses;
}


sub resource_classes {
  my ($self) = @_;

  return {
    'default' => { LSF => '-q production -M 1000 -R"select[mem>1000] rusage[mem=1000]"'},
    '4GB' => { LSF => '-q production -M 4000 -R"select[mem>4000] rusage[mem=4000]"'},
    '8GB' => { LSF => '-q production -M 8000 -R"select[mem>8000] rusage[mem=8000]"'},
    '16GB' => { LSF => '-q production -M 16000 -R"select[mem>16000] rusage[mem=16000]"'},
    '20GB' => { LSF => '-q production -M 20000 -R"select[mem>20000] rusage[mem=20000]"'},
  };
}

1;
