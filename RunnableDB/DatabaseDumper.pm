=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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


=pod

=head1 NAME

Bio::EnsEMBL::EGPipeline::Common::DatabaseDumper

=head1 DESCRIPTION

This is a simple wrapper around the Hive module; all it's really doing
is creating an appropriate dbconn for that module.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper;

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Path qw(make_path);

use base (
  'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
  'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base'
);

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    'db_type'   => 'core',
    'overwrite' => 0,
  };
  
}

sub fetch_input {
  my $self = shift @_;
  
  my $output_file = $self->param('output_file');
  if (defined $output_file) {
    if (-e $output_file) {
      if ($self->param('overwrite')) {
        $self->warning("Output file '$output_file' already exists, and will be overwritten.");
      } else {
        $self->warning("Output file '$output_file' already exists, and won't be overwritten.");
        $self->param('skip_dump', 1);
      }
    } else {
      my $output_dir = dirname($output_file);
      if (!-e $output_dir) {
        $self->warning("Output directory '$output_dir' does not exist. I shall create it.");
        make_path($output_dir) or $self->throw("Failed to create output directory '$output_dir'");
      }
    }
  }
  
  my $db_type = $self->param('db_type');
  if ($db_type eq 'hive') {
    $self->param('src_db_conn', $self->dbc);
  } else {
    $self->param('exclude_ehive', 1);
    $self->param('src_db_conn', $self->get_DBAdaptor($db_type)->dbc);
  }
  
  $self->SUPER::fetch_input();
  
}

1;
