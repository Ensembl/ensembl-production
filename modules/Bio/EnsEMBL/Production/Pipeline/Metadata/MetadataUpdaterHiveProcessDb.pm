=head1 LICENSE

Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
 Bio::EnsEMBL::MetaData::Pipeline::MetadataUpdaterHiveProcessDb;

=head1 DESCRIPTION
 Process database submission and flow into core analysis, compara or other databases

=head1 MAINTAINER

 maurel@ebi.ac.uk 

=cut
package Bio::EnsEMBL::MetaData::Pipeline::MetadataUpdaterHiveProcessDb; 

use base ('Bio::EnsEMBL::Hive::Process');
use strict;
use warnings;

sub run {
my ($self) = @_;
my $database_uri = $self->param_required('database_uri');
my $output_hash;
my $e_release = $self->param('e_release');
if (!defined $e_release){
  $output_hash={
            'metadata_uri' => $self->param_required('metadata_uri'),
            'database_uri' => $database_uri,
            'comment' => $self->param('comment'),
            'source' => $self->param('source'),
            'email' => $self->param_required('email'),
            'timestamp' => $self->param('timestamp')
          };
}
else{
  $output_hash={
          'metadata_uri' => $self->param_required('metadata_uri'),
          'database_uri' => $database_uri,
          'release_date' => $self->param('release_date'),
          'e_release' => $e_release,
          'eg_release' => $self->param('eg_release'),
          'current_release' => $self->param('current_release'),
          'comment' => $self->param('comment'),
          'source' => $self->param('source'),
          'email' => $self->param_required('email'),
          'timestamp' => $self->param('timestamp')
        };
}
my $database = Bio::EnsEMBL::Hive::Utils::URL::parse($database_uri);
if ($database->{dbname} =~ m/_core_/){
  $self->dataflow_output_id($output_hash, 2);
}
elsif ($database->{dbname} =~ m/_compara_/){
  $self->dataflow_output_id($output_hash, 4);
}
else {
  $self->dataflow_output_id($output_hash, 3);
}
return;
}

1;
