=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::SchedulePreParse;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;
  my $source_url       = $self->param_required('source_url');
  my $sql_dir          = $self->param_required('sql_dir');
  my $source_xref      = $self->param('source_xref');
  my $skip_preparse    = $self->param('skip_preparse');

  my ($user, $pass, $host, $port) = $self->parse_url($source_url);
  my $dataflow_params;

  unless ($skip_preparse) {
    my ($xref_user, $xref_pass, $xref_host, $xref_port, $xref_dbname) = $self->parse_url($source_xref);

    # Create central Xref database
    my $xref_dbc = XrefParser::Database->new({
              host    => $xref_host,
              dbname  => $xref_dbname,
              port    => $xref_port,
              user    => $xref_user,
              pass    => $xref_pass });
    $xref_dbc->create($sql_dir, 1, 1);
  
    # Retrieve list of sources to pre-parse from versioning database
    my ($source_user, $source_pass, $source_host, $source_port, $source_db) = $self->parse_url($source_url);
    my $dbi = $self->get_dbi($source_host, $source_port, $source_user, $source_pass, $source_db);
    my $select_source_sth = $dbi->prepare("SELECT distinct name, parser, uri, clean_uri, revision, count_seen FROM source s, version v WHERE s.source_id = v.source_id and preparse = 1");
    my ($name, $parser, $dir, $clean_dir, $version_file, $priority);
    $select_source_sth->execute();
    $select_source_sth->bind_columns(\$name, \$parser, \$dir, \$clean_dir, \$version_file, \$priority);

    while ($select_source_sth->fetch()) {
      if (defined $clean_dir) { $dir = $clean_dir; }
      my @files = `ls $dir`;
      foreach my $file (@files) {
        $file =~ s/\n//;
        $file = $dir . "/" . $file;
        $dataflow_params = {
          parser       => $parser,
          name         => $name,
          version_file => $version_file,
          xref_url     => $source_xref,
          file         => $file,
        };
        $self->dataflow_output_id($dataflow_params, $priority+1);
      }
    }
  }

  $dataflow_params = {
    db_url => $source_url
  };
  $self->dataflow_output_id($dataflow_params, -1);
}

1;

