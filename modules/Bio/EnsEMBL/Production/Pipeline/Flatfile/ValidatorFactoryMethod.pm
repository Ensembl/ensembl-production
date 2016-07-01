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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Flatfile::ValidatorFactoryMethod - FlatFile validator factory

=head1 SYNOPSIS

  my $factory = Bio::EnsEMBL::Production::Pipeline::FlatFile::ValidatorFactoryMethod->new();
  my $embl_validator = $factory->create_instance('embl');

=head1 DESCRIPTION

Implementation of the factory method pattern to create instances of
Validator subclasses.
At the moment, the only supported types of validator are embl/genbank.

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Flatfile::ValidatorFactoryMethod;

use Bio::EnsEMBL::Production::Pipeline::Flatfile::EMBLValidator;
use Bio::EnsEMBL::Production::Pipeline::Flatfile::GenbankValidator;
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
    $validator = Bio::EnsEMBL::Production::Pipeline::Flatfile::EMBLValidator->new(), last SWITCH
      if $type =~ /embl/i;

    $validator = Bio::EnsEMBL::Production::Pipeline::Flatfile::GenbankValidator->new(), last SWITCH
      if $type =~ /genbank/i;

    throw "Unknown type $type for Validator";
  }

  return $validator;
}

1;
