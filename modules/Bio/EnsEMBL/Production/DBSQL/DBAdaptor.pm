=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

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

use Bio::EnsEMBL::Utils::Exception qw( throw );
use base ('Bio::EnsEMBL::DBSQL::DBAdaptor');


sub new {
  my ($class, @args) = @_;

  #############################################################
  #
  # Temporary hack
  # 
  # Works for the local copy of ORM::EnsEMBL::Rose::Metadata,
  # before 04/10/2013 Harpreet update to ensembl-orm Metadata.pm,
  # where method trackable check for the following environment
  #
  # $ENV{ENS_NOTRACKING} = 1;
  #
  #############################################################

  my $self = $class->SUPER::new(@args) or
    throw "Unable to connect to DBA using parameters (".join(', ', @args).")\n";

  ORM::EnsEMBL::Rose::DbConnection->register_database({type      => 'production', 
						       database  => $self->dbc->dbname, 
						       host      => $self->dbc->host, 
						       port      => $self->dbc->port, 
						       username  => $self->dbc->username,
						       password  => $self->dbc->password,
						       trackable => 0});

  # this needs to be executed after the registration of the database,
  # otherwise we get a compilation error
  require ORM::EnsEMBL::DB::Production::Manager::Biotype;

  return $self;
}

sub get_available_adaptors {
  return {};
}

1;
