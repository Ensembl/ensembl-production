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

=head1 NAME

    ValidateRDF - Hive module to test and validate RDF dumps

=head1 DESCRIPTION
    This module run the turtle binary java programs that can be found on the following website: https://jena.apache.org/download/index.cgi
    Please note that this program requires Java 1.8 to run. 
=cut

package Bio::EnsEMBL::Production::Pipeline::RDF::ValidateRDF;

use strict;
use warnings;

use parent ('Bio::EnsEMBL::Production::Pipeline::Base');

sub fetch_input {
  my ($self) = @_;

  $self->throw("No 'filename' specified") unless $self->param('filename');

  return;
}

sub run {
  my ($self) = @_;

  my $filename = $self->param('filename');
  # Run the turtle validator java program and grab the output
  my $validator_output= `riot --validate --syntax=turtle $filename 2>&1`;
  # If there is any error
  if ($validator_output)
  {
    $self->warning("The file contains the following error: $validator_output");
  }
  return;
}

1;

