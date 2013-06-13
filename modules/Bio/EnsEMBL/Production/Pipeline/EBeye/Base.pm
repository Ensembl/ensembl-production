package Bio::EnsEMBL::Production::Pipeline::EBeye::Base;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

sub data_path {
  my ($self) = @_;

  return $self->get_dir('ebeye');
}

1;
