=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Production::DBSQL::DBAdaptor

=head1 SYNOPSIS

  $db = Bio::EnsEMBL::Production::DBSQL::DBAdaptor->new(
    -user   => 'root',
    -dbname => 'pog',
    -host   => 'caldy',
    -driver => 'mysql'
  );


=head1 DESCRIPTION

A specialised database adaptor which allows to set up the environment for 
interfacing to a production database using the EnsEMBL::ORM framework.

=head1 METHODS

=cut

package Bio::EnsEMBL::Production::DBSQL::DBAdaptor;

use strict;
use warnings;

use ORM::EnsEMBL::Rose::DbConnection;
use ORM::EnsEMBL::DB::Production::Manager::Biotype;

use Bio::EnsEMBL::Utils::Exception qw( throw );
use base ('Bio::EnsEMBL::DBSQL::DBAdaptor');


sub new {
  my ($class, @args) = @_;

  my $self = $class->SUPER::new(@args) or
    throw "Unable to connect to DBA using parameters (".join(', ', @args).")\n";

  ORM::EnsEMBL::Rose::DbConnection->register_database({domain    => 'ensembl',
						       type      => 'production', 
						       database  => $self->dbc->dbname, 
						       host      => $self->dbc->host, 
						       port      => $self->dbc->port, 
						       username  => $self->dbc->username,
						       password  => $self->dbc->password,
						       trackable => 0});

  # require ORM::EnsEMBL::DB::Production::Manager::Biotype;

  return $self;
}

sub get_available_adaptors {
  return {};
}

sub get_biotype_manager {
  my $self = shift;
  
  return 'ORM::EnsEMBL::DB::Production::Manager::Biotype';
}

1;
