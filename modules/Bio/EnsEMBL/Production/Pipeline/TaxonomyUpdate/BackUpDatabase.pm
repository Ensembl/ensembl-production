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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::TaxonomyUpdate::BackUpDatabase

=head1 DESCRIPTION

Backup table meta before taxonomy update 
=over 8

=item type - The format to parse

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::TaxonomyUpdate::BackUpDatabase;

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::DatabaseDumper/;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use POSIX qw(strftime);

sub fetch_input {
  my ($self) = @_;
  my $dbname = $self->param('dbname');
  my ($dba) = @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors_by_dbname($dbname) };
  if (! defined $dba){
      throw "Database $dbname not found in registry.";  
  }
  my $mca = $dba->get_MetaContainer();
  my $production_name = $mca->single_value_by_key('species.production_name');
  my $db_type = $mca->single_value_by_key('schema_type');
  $self->param('species', $production_name);
  $self->param('db_type', $db_type);
  $self->param('src_db_conn', $dba->dbc);
  $self->SUPER::fetch_input();
}

1;
