package Bio::EnsEMBL::Production::Pipeline::Production::ShortNonCodingDensity;

use base qw/Bio::EnsEMBL::Production::Pipeline::Production::DensityGenerator/;


use strict;
use warnings;


sub get_option {
  my ($self) = @_;
  return $self->get_biotype_group("snoncoding");
}

1;


