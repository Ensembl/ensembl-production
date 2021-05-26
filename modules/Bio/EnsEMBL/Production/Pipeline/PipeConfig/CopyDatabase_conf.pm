=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::CopyDatabase_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

sub pipeline_create_commands {
  my ($self) = @_;
  return [
    @{$self->SUPER::pipeline_create_commands},

    $self->db_cmd('CREATE TABLE result (job_id int(10), output TEXT, PRIMARY KEY (job_id))'),
    $self->db_cmd('CREATE TABLE job_progress (job_progress_id int(11) NOT NULL AUTO_INCREMENT, job_id int(11) NOT NULL , message TEXT,  PRIMARY KEY (job_progress_id))'),
    $self->db_cmd('ALTER TABLE job_progress ADD INDEX (job_id)'),
    $self->db_cmd('ALTER TABLE job DROP KEY input_id_stacks_analysis'),
    $self->db_cmd('ALTER TABLE job MODIFY input_id TEXT')
  ];
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name      => 'copy_database',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::CopyDatabases::CopyDatabaseHive',
      -input_ids       => [ {} ],
      -max_retry_count => 0,
      -meadow_type     => 'LOCAL',
      -flow_into       => {
                            2 => [ '?table_name=result' ]
                          },
    }
  ];
}
1;
