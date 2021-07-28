=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::ScheduleCleanup;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;

  my $base_path = $self->param_required('base_path');
  my $db_url    = $self->param_required('db_url');

  # Connect to source db
  $self->dbc()->disconnect_if_idle() if defined $self->dbc();
  my ($user, $pass, $host, $port, $source_db) = $self->parse_url($db_url);
  my $dbi = $self->get_dbi($host, $port, $user, $pass, $source_db);

  # Get name and version file for each source
  my $sth = $dbi->prepare("select distinct(src.name),ver.revision from source src,version ver where src.source_id=ver.source_id");
  $sth->execute;

  my $dataflow_params;
  while (my $source = $sth->fetchrow_hashref()) {
    my $name = $source->{'name'};
    my $version_file = $source->{'revision'};

    if ($name !~ /^RefSeq/) {next;} # Only cleaning RefSeq for now

    # Send parameters into cleanup jobs for each source
    if (-d $base_path."/".$name) {
      my $branch = ($name =~ /^RefSeq_dna/ ? 2 : 3);
      $dataflow_params = {
        name         => $name,
        version_file => $version_file,
        db_url       => $db_url,
      };
      $self->dataflow_output_id($dataflow_params, $branch);
    }
  }

  # Send parameters to EmailNotification job
  $dataflow_params = {
    db_url    => $db_url,
    base_path => $base_path
  };
  $self->dataflow_output_id($dataflow_params, 1);
}

1;
