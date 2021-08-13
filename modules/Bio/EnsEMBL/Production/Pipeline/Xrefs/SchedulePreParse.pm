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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::SchedulePreParse;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;
  my $source_url       = $self->param_required('source_url');
  my $release          = $self->param('release');
  my $sql_dir          = $self->param('sql_dir');

  my ($user, $pass, $host, $port) = $self->parse_url($source_url);

  # Create central Xref database
  my $dbname = "xref_source_preparse_" . $release;
  my $xref_dbc = XrefParser::Database->new({
            host    => $host,
            dbname  => $dbname,
            port    => $port,
            user    => $user,
            pass    => $pass });
  $xref_dbc->create($sql_dir, 1, 1);

  # Retrieve list of sources to pre-parse from versioning database
  my ($source_user, $source_pass, $source_host, $source_port, $source_db) = $self->parse_url($source_url);
  my $dbi = $self->get_dbi($source_host, $source_port, $source_user, $source_pass, $source_db);
  my $select_source_sth = $dbi->prepare("SELECT distinct name, parser, uri, clean_uri, revision FROM source s, version v WHERE s.source_id = v.source_id and preparse = 1");
  my ($name, $parser, $dir, $clean_dir, $version_file);
  $select_source_sth->execute();
  $select_source_sth->bind_columns(\$name, \$parser, \$dir, \$clean_dir, \$version_file);

  my $dataflow_params;
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
        xref_url     => $source_url,
        file         => $file,
        dbname       => $dbname,
      };
      $self->dataflow_output_id($dataflow_params, 2);
    }
  }
}

1;

