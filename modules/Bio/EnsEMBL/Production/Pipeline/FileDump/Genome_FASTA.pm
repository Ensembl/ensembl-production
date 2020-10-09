=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Genome_FASTA;

use strict;
use warnings;
use base qw(Bio::EnsEMBL::Production::Pipeline::FileDump::Base_Filetype);

use Bio::DB::HTS::Faidx;
use Bio::EnsEMBL::PaddedSlice;
use Bio::EnsEMBL::Utils::IO::FASTASerializer;
use File::Spec::Functions qw/catdir/;
use Path::Tiny;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    data_type      => 'sequence',
    data_types     => ['unmasked', 'softmasked', 'hardmasked'],
    file_type      => 'fa',
    timestamped    => 1,
    per_chromosome => 0,
    chunk_size     => 30000,
    line_width     => 60,
    blast_index    => 0,
    blastdb_exe    => 'makeblastdb',
    blast_dirname  => 'ncbi_blast'
  };
}

sub run {
  my ($self) = @_;

  my $per_chromosome = $self->param_required('per_chromosome');
  my $blast_index    = $self->param_required('blast_index');
  my $filenames      = $self->param_required('filenames');

  my $dba = $self->dba;

  my $repeat_analyses = $dba->get_MetaContainer->list_value_by_key('repeat.analysis');

  my ($chr, $non_chr, $non_ref) = $self->get_slices($dba);

  my $um_filename = $$filenames{'unmasked'};
  my $sm_filename = $$filenames{'softmasked'};
  my $hm_filename = $$filenames{'hardmasked'};

  if ($per_chromosome && scalar(@$chr)) {
    $self->print_to_file($chr, 'chr', $sm_filename, '>', $repeat_analyses);
    if (scalar(@$non_chr)) {
      $self->print_to_file($non_chr, 'non_chr', $sm_filename, '>>', $repeat_analyses);
    }
  } else {
    $self->print_to_file([@$chr, @$non_chr], undef, $sm_filename, '>', $repeat_analyses);
  }

  $self->unmask($sm_filename, $um_filename);
  $self->hardmask($sm_filename, $hm_filename);

  if (scalar(@$non_ref)) {
    my $um_non_ref_filename = $self->generate_non_ref_filename($um_filename);
    my $sm_non_ref_filename = $self->generate_non_ref_filename($sm_filename);
    my $hm_non_ref_filename = $self->generate_non_ref_filename($hm_filename);
    path($sm_filename)->copy($sm_non_ref_filename);

    $self->print_to_file($non_ref, undef, $sm_non_ref_filename, '>>', $repeat_analyses);

    $self->unmask($sm_non_ref_filename, $um_non_ref_filename);
    $self->hardmask($sm_non_ref_filename, $hm_non_ref_filename);
  }

  if ($blast_index) {
    $self->blast_index($um_filename, 'nucl');
    $self->blast_index($sm_filename, 'nucl');
    $self->blast_index($hm_filename, 'nucl');
  }
}

sub timestamp {
  my ($self, $dba) = @_;

  return $self->repeat_mask_date($dba);
}

sub print_to_file {
  my ($self, $slices, $region, $sm_filename, $mode, $repeat_analyses) = @_;

  my $serializer = $self->fasta_serializer($sm_filename, $mode);

  # If per-chromosome files are required, to reduce duplication and
  # filespace usage, only soft-masked versions of those files are made.
  my $non_chr_serializer;
  if ($region && $region eq 'non_chr') {
    my $non_chr_filename = $self->generate_non_chr_filename($sm_filename);
    $non_chr_serializer = $self->fasta_serializer($non_chr_filename, $mode);
  }

  while (my $slice = shift @{$slices}) {
    my $chr_serializer;
    if ($region && $region eq 'chr') {
      my $chr_filename = $self->generate_chr_filename($sm_filename, $slice);
      $chr_serializer = $self->fasta_serializer($chr_filename, $mode);
    }

    my $masked_slice = $slice->get_repeatmasked_seq($repeat_analyses, 1);
    my $padded_slice = Bio::EnsEMBL::PaddedSlice->new(-SLICE => $masked_slice);

    $serializer->print_Seq($padded_slice);
    if ($region && $region eq 'chr') {
      $chr_serializer->print_Seq($padded_slice);
    } elsif ($region && $region eq 'non_chr') {
      $non_chr_serializer->print_Seq($padded_slice);
    }
  }
}

sub fasta_serializer {
  my ($self, $filename, $mode) = @_;
  my $chunk_size = $self->param('chunk_size');
  my $line_width = $self->param('line_width');
  
  my $header_function = $self->header_function();

  my $fh = path($filename)->filehandle($mode);
  my $serializer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new(
    $fh,
    $header_function,
    $chunk_size,
    $line_width,
  );

  return $serializer;
}

sub header_function {
  my ($self) = @_;

  return sub {
    my $slice = shift;

    if (! $slice->isa('Bio::EnsEMBL::Slice')) {
      return $slice->display_id;
    }

    my $data_type;
    if ($slice->isa('Bio::EnsEMBL::RepeatMaskedSlice')) {
      $data_type = $slice->soft_mask ? 'softmasked' : 'hardmasked';
    } else {
      $data_type = 'unmasked';
    }
    my $name = $slice->seq_region_name;
    my $cs_name = $slice->coord_system->name;
    if ($slice->is_chromosome && $cs_name eq 'primary_assembly') {
      $cs_name = 'chromosome';
    }
    my $location = $slice->name;
    my $ref = $slice->assembly_exception_type;
    if ($ref ne 'REF') {
      $location = $slice->seq_region_Slice->name . ' ' . $ref;
    }
    $location =~ s/^$cs_name://;

    return "$name $data_type:$cs_name $location";
  };
}

sub unmask {
  my ($self, $sm_filename, $um_filename) = @_;

  my $convert = sub {
    if (index($_, '>') == 0) {
      $_ =~ s/softmasked/unmasked/;
    } else {
      $_ =~ tr/[a-z]/[A-Z]/;
    }
  };

  path($sm_filename)->copy($um_filename);
  path($um_filename)->edit_lines($convert);
}

sub hardmask {
  my ($self, $sm_filename, $hm_filename) = @_;

  my $convert = sub {
    if (index($_, '>') == 0) {
      $_ =~ s/softmasked/hardmasked/;
    } else {
      $_ =~ tr/[a-z]/N/;
    }
  };

  path($sm_filename)->copy($hm_filename);
  path($hm_filename)->edit_lines($convert);
}

sub blast_index {
  my ($self, $filename, $dbtype) = @_;

  my $tools_dir = $self->param_required('tools_dir');
  my $blast_dirname = $self->param_required('blast_dirname');

  my $blast_filename = catdir(
    $tools_dir,
    $blast_dirname,
    'genomes',
    path($filename)->basename
  );
  path($blast_filename)->parent->mkpath();

  $self->create_blast_index($filename, $blast_filename, $dbtype);
}

1;
