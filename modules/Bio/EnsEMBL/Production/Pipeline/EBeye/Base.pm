package Bio::EnsEMBL::Production::Pipeline::GTF::Base;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

sub data_path {
  my ($self) = @_;

  $self->throw("No 'species' parameter specified") 
    unless $self->param('species');

  return $self->get_dir('gtf', $self->param('species'));
}

1;
