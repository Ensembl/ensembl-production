=head1 LICENSE

Copyright [1999-2015] EMBL-European Bioinformatics Institute
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

Bio::EnsEMBL::EGPipeline::ProteinFeatures::DumpInterProXrefs

=head1 DESCRIPTION

Get InterPro xrefs from a core db.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::DumpInterProXrefs;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

sub run {
  my ($self) = @_;
  
  my $filename = $self->param_required('filename');
  open my $fh, '>', $filename or $self->throw("Could not open $filename for writing");
  
  my $dbh = $self->core_dbh();
  my $sql = '
    SELECT
      x.external_db_id,
      x.dbprimary_acc,
      x.display_label,
      x.version,
      x.description,
      x.info_type,
      x.info_text
    FROM
      xref x INNER JOIN 
      interpro i ON x.dbprimary_acc = i.interpro_ac INNER JOIN
      external_db edb USING (external_db_id)
    WHERE edb.db_name = "Interpro";
  ';
  my $sth = $dbh->prepare($sql);
  $sth->execute;
  
  while (my @row = $sth->fetchrow_array) {
    print $fh join("\t", @row)."\n";
  }
	$fh->close();
}

sub write_output {
  my ($self)  = @_;
  
  $self->dataflow_output_id({'filename' => $self->param('filename')}, 1);
}

1;
