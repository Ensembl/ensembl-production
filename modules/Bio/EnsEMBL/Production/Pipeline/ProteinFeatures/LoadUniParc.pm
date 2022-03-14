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

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::LoadUniParc;

use strict;
use warnings;

use File::Basename;

use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub run {
  my ($self) = @_;
  my $uniparc_file = $self->param_required('uniparc_file_local');

  if (-e $uniparc_file) {
    my $dbh = $self->hive_dbh;
    my $sql = "LOAD DATA LOCAL INFILE '$uniparc_file' INTO TABLE uniparc FIELDS TERMINATED BY ' '";
    $dbh->do($sql) or self->throw($dbh->errstr);

    my $index_1 = 'ALTER TABLE uniparc ADD KEY upi_idx (upi)';
    $dbh->do($index_1) or self->throw($dbh->errstr);

    my $index_2 = 'ALTER TABLE uniparc ADD KEY md5sum_idx (md5sum) USING HASH';
    $dbh->do($index_2) or self->throw($dbh->errstr);

  } else {
    $self->throw("Checksum file '$uniparc_file' does not exist");
  }
}

1;
