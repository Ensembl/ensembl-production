=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::LoadChecksums;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

sub run {
  my ($self) = @_;
  my $md5_checksum_file = $self->param_required('md5_checksum_file');
  
  if (! -e $md5_checksum_file) {
    $self->throw("Checksum file '$md5_checksum_file' does not exist");
  }
  
  my $hive_dbh = $self->hive_dbh;
  
  # Note that case-insensitivity is important, because the md5 checksums
  # from interpro use uppercase and those generated with perl are lowercase.
  my @load_sql = (
    "DROP TABLE IF EXISTS checksum;",
    "CREATE TABLE checksum (md5sum char(32) collate latin1_swedish_ci);",
    "LOAD DATA LOCAL INFILE '$md5_checksum_file' INTO TABLE checksum;",
    "CREATE INDEX md5sum_idx ON checksum (md5sum) using hash;"
	);
  
  foreach my $load_sql (@load_sql) {
    $hive_dbh->do($load_sql) or $self->throw("Failed to execute: $load_sql");
  }
}

1;
