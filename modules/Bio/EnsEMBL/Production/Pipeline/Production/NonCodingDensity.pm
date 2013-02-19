package Bio::EnsEMBL::Production::Pipeline::Production::NonCodingDensity;

use base qw/Bio::EnsEMBL::Production::Pipeline::Production::DensityGenerator/;


use strict;
use warnings;


sub get_option {
  my ($self) = @_;
  return $self->get_biotype_group("noncoding");
}

1;


