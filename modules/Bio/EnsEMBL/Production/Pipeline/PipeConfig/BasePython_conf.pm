=pod
=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 LICENSE
    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2022] EMBL-European Bioinformatics Institute
    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
         http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.
=head1 CONTACT
    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates
=cut


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::BasePython_conf;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        user  => $ENV{'USER'},
        email => $ENV{'USER'}.'@ebi.ac.uk',

        production_queue => 'production',
        datamover_queue => 'datamover',
    }
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},

        # Create/alter tables used by ensembl.production.core.models.hive Python module
        $self->db_cmd('CREATE TABLE result (job_id int(10), output TEXT, PRIMARY KEY (job_id))'),
        $self->db_cmd('CREATE TABLE job_progress (job_progress_id int(11) NOT NULL AUTO_INCREMENT, job_id int(11) NOT NULL , message TEXT,  PRIMARY KEY (job_progress_id))'),
        $self->db_cmd('ALTER TABLE job_progress ADD INDEX (job_id)'),
        $self->db_cmd('ALTER TABLE job DROP KEY input_id_stacks_analysis'),
        $self->db_cmd('ALTER TABLE job MODIFY input_id TEXT')
    ];
}

sub resource_classes {
  my $self = shift;
  return {
    'default' => {LSF => '-q '.$self->o('production_queue')},
    'dm'      => {LSF => '-q '.$self->o('datamover_queue')},
    '1GB'     => {LSF => '-q '.$self->o('production_queue').' -M  1000 -R "rusage[mem=1000]"'},
    '2GB'     => {LSF => '-q '.$self->o('production_queue').' -M  2000 -R "rusage[mem=2000]"'},
    '4GB'     => {LSF => '-q '.$self->o('production_queue').' -M  4000 -R "rusage[mem=4000]"'},
    '8GB'     => {LSF => '-q '.$self->o('production_queue').' -M  8000 -R "rusage[mem=8000]"'},
    '16GB'    => {LSF => '-q '.$self->o('production_queue').' -M 16000 -R "rusage[mem=16000]"'},
    '32GB'    => {LSF => '-q '.$self->o('production_queue').' -M 32000 -R "rusage[mem=32000]"'},
  }
}

1;