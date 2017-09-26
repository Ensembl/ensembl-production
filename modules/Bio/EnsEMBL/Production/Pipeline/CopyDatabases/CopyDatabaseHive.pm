=head1 LICENSE

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

=head1 NAME

  Bio::EnsEMBL::Production::Pipeline::CopyDatabases::CopyDatabaseHive;

=head1 DESCRIPTION

=head1 MAINTAINER

 maurel@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::CopyDatabases::CopyDatabaseHive; 

use base ('Bio::EnsEMBL::Hive::Process');
use strict;
use warnings;
use Bio::EnsEMBL::Production::Utils::CopyDatabase
  qw/copy_database/;
use JSON;
use Time::Duration;



sub run{


my $self = shift @_;

my $source_db_uri = $self->param_required('source_db_uri');
my $target_db_uri = $self->param_required('target_db_uri');
my $only_tables = $self->param('only_tables');
my $skip_tables = $self->param('skip_tables');
my $update = $self->param('update');
my $drop = $self->param('drop');
my $start_time = time();

copy_database($source_db_uri, $target_db_uri, $only_tables, $skip_tables, $update, $drop);

my $runtime =  duration(time() - $start_time);

my $output = {
		  source_db_uri=>$source_db_uri,
		  target_db_uri=>$target_db_uri,
		  runtime => $runtime
		 };
$self->dataflow_output_id({
			       job_id=>$self->input_job()->dbID(),
			       output=>encode_json($output)
			      }, 2);

return;
}

1;