=pod

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

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Flatfile::ValidatorFactoryMethod - FlatFile validator factory

=head1 SYNOPSIS

  my $factory = Bio::EnsEMBL::Production::Pipeline::FlatFile::ValidatorFactoryMethod->new();
  my $embl_validator = $factory->create_instance('embl');

=head1 DESCRIPTION

Implementation of the factory method pattern to create instances of
Validator subclasses.
At the moment, the only supported type of validator is EMBL.

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Flatfile::ValidatorFactoryMethod;

use Bio::EnsEMBL::Production::Pipeline::Flatfile::EMBLValidator;
use Bio::EnsEMBL::Utils::Exception qw/throw/;


=head2 new

  Arg [...]  : None
  Description: Creates a new ValidatorFactoryMethod object.
  Returntype : Bio::EnsEMBL::Production::Pipeline::Flatfile::ValidatorFactoryMethod
  Exceptions : None
  Caller     : general
  Status     : Stable

=cut

sub new {
  my ($class, @args) = @_;
  my $self = bless {}, $class;
    
  return $self;
}

=head2 create_instance

  Arg [1]    : String; validator type
  Description: Build a validator for the file type specified as argument.
               Supported file types are:
               - embl
  Exceptions : If type not specified or unsupported file format
  Returntype : Subclass of Bio::EnsEMBL::Production::Pipeline::FlatFile::Validator
  Caller     : general
  Status     : Stable

=cut

sub create_instance {
  my ($self, $type) = @_;
  throw "Parser type not specified"
    unless $type;
  
  my $validator;

 SWITCH:
  {
    $validator = EMBLValidator->new(), last SWITCH
      if $type =~ /embl/i;

    throw "Unknown type $type for Validator";
  }

  return $validator;
}

1;
