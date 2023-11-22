=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License..

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::AdvisoryXrefReport;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;

  my $datacheck_name   = $self->param('datacheck_name');
  my $datacheck_output = $self->param('datacheck_output');
  my $datacheck_params = $self->param('datacheck_params');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();
  my $hive_dbi = $self->dbc;

  # Add report parameters into hive db
  my $dbname = $datacheck_params->{dba_params}->{-DBNAME};
  my $hive_sth = $hive_dbi->prepare("INSERT INTO advisory_dc_report (db_name, datacheck_name, datacheck_output) VALUES (?,?,?)");
  $hive_sth->execute($dbname, $datacheck_name, $datacheck_output);
}

1;
