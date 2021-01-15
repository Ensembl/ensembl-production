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

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::LoadUniProt;

use strict;
use warnings;

use File::Basename;

use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub run {
  my ($self) = @_;
  my $mapping_file = $self->param_required('mapping_file_local');
  my $uniprot_file = $self->param_required('uniprot_file_local');

  if (-e $mapping_file) {
    $self->run_cmd("gunzip $mapping_file");
    $mapping_file =~ s/\.gz$//;
    $self->run_cmd("grep UniParc $mapping_file | cut -f1,3 > $uniprot_file");
    
    my $dbh = $self->hive_dbh;
    my $sql = "LOAD DATA LOCAL INFILE '$uniprot_file' INTO TABLE uniprot";
    $dbh->do($sql) or self->throw($dbh->errstr);

    my $index_1 = 'ALTER TABLE uniprot ADD KEY upi_idx (upi)';
    $dbh->do($index_1) or self->throw($dbh->errstr);

  } else {
    $self->throw("Mapping file '$mapping_file' does not exist");
  }
}

1;
