=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Chromosome_TSV; 

use strict;
use warnings;
use feature 'say';
use base qw(Bio::EnsEMBL::Production::Pipeline::FileDump::Base_Filetype);

use Path::Tiny;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    data_type => 'chromosomes',
    file_type => 'tsv',
  };
}

sub run {
  my ($self) = @_;

  my $data_type = $self->param_required('data_type');
  my $filenames = $self->param_required('filenames');

  my $dba = $self->dba;

  my $filename = $$filenames{$data_type};

  # Don't strictly need to check for presence of chromosomes,
  # but it speeds things up a lot for cases where we don't.
  if ($self->has_chromosomes($dba)) {
    my $fh = path($filename)->filehandle('>');
    my ($chr, undef, undef) = $self->get_slices($dba);
    foreach my $slice (@$chr) {
      say $fh join("\t", ($slice->seq_region_name, $slice->length));
    }
  } else {
    $self->complete_early('Species does not have chromosomes');
  }

  $dba->dbc->disconnect_if_idle();
}

1;
