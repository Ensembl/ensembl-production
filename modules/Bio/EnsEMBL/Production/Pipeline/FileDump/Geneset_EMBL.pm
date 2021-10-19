=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_EMBL;

use strict;
use warnings;
use base qw(Bio::EnsEMBL::Production::Pipeline::FileDump::Base_Filetype);

use Bio::EnsEMBL::Utils::SeqDumper;
use Path::Tiny;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    data_type      => 'genes',
    file_type      => 'embl',
    per_chromosome => 0,
  };
}

sub run {
  my ($self) = @_;

  my $data_type      = $self->param_required('data_type');
  my $per_chromosome = $self->param_required('per_chromosome');
  my $filenames      = $self->param_required('filenames');

  my $dba = $self->dba;

  my $seq_dumper = $self->seq_dumper();

  my ($chr, $non_chr, $non_ref) = $self->get_slices($dba);

  my $filename = $$filenames{$data_type};

  if ($per_chromosome && scalar(@$chr)) {
    $self->print_to_file($chr, 'chr', $filename, '>', $seq_dumper);
    if (scalar(@$non_chr)) {
      $self->print_to_file($non_chr, 'non_chr', $filename, '>>', $seq_dumper);
    }
  } else {
    $self->print_to_file([@$chr, @$non_chr], undef, $filename, '>', $seq_dumper);
  }

  if (scalar(@$non_ref)) {
    my $non_ref_filename = $self->generate_non_ref_filename($filename);
    path($filename)->copy($non_ref_filename);
    $self->print_to_file($non_ref, undef, $non_ref_filename, '>>', $seq_dumper);
  }
}

sub print_to_file {
  my ($self, $slices, $region, $filename, $mode, $seq_dumper) = @_;

  my $fh = path($filename)->filehandle($mode);

  my $non_chr_fh;
  if ($region && $region eq 'non_chr') {
    my $non_chr_filename = $self->generate_non_chr_filename($filename);
    $non_chr_fh = path($non_chr_filename)->filehandle($mode);
  }

  while (my $slice = shift @{$slices}) {
    my $chr_fh;
    if ($region && $region eq 'chr') {
      my $chr_filename = $self->generate_chr_filename($filename, $slice);
      $chr_fh = path($chr_filename)->filehandle($mode);
    }

    $seq_dumper->dump_embl($slice, $fh);
    if ($region && $region eq 'chr') {
      $seq_dumper->dump_embl($slice, $chr_fh);
    } elsif ($region && $region eq 'non_chr') {
      $seq_dumper->dump_embl($slice, $non_chr_fh);
    }
  }
}

sub seq_dumper {
  my ($self) = @_;

  my $seq_dumper =
    Bio::EnsEMBL::Utils::SeqDumper->new({ chunk_factor => 100000 });

  $seq_dumper->disable_feature_type('similarity');
  $seq_dumper->disable_feature_type('genscan');
  $seq_dumper->disable_feature_type('variation');
  $seq_dumper->disable_feature_type('repeat');
  $seq_dumper->disable_feature_type('marker');

  return $seq_dumper;
}

1;
