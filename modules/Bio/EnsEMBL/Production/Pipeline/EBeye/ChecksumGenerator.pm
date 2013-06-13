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

Bio::EnsEMBL::Production::Pipeline::EBeye::ChecksumGenerator

=head1 DESCRIPTION

Creates a CHECKSUMS file in the given directory which is produced from running
the sum command over every file in the directory. This excludes the CHECKSUMS
file, parent directory or any hidden files.

=cut

package Bio::EnsEMBL::Production::Pipeline::EBeye::ChecksumGenerator;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::ChecksumGenerator Bio::EnsEMBL::Production::Pipeline::EBeye::Base/;

sub fetch_input {
  my ($self) = @_;

  my $dir = $self->data_path();
  $self->param('dir', $dir);

  $self->SUPER::fetch_input();

  return;
}

1;
