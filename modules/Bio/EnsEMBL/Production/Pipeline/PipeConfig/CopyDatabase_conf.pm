=pod 
=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION  

=head1 LICENSE
    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2017] EMBL-European Bioinformatics Institute
    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
         http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.
=head1 CONTACT
    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates
=cut


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::CopyDatabase_conf;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub resource_classes {
    my ($self) = @_;
    return { 'default' => { 'LSF' => '-q production-rh7' }};
}

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        'pipeline_name' => "copy_database",

    }
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
    @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

            # additional tables needed for long multiplication pipeline's operation:
    $self->db_cmd('CREATE TABLE result (job_id int(10), output TEXT, PRIMARY KEY (job_id))'),
    $self->db_cmd('ALTER TABLE job DROP KEY input_id_stacks_analysis'),
    $self->db_cmd('ALTER TABLE job MODIFY input_id TEXT')
    ];
  }

=head2 pipeline_analyses
=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   
            -logic_name => 'copy_database',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::CopyDatabases::CopyDatabaseHive',
            -input_ids => [],
            -parameters => {
        },
	 -meadow_type => 'LOCAL',
            -flow_into     => {
                   2 => [ '?table_name=result']      
                  },
        }
        ];
}
1;