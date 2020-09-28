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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GTF;

use strict;
use warnings;
use base qw(Bio::EnsEMBL::Production::Pipeline::FileDump::Base_Filetype);

use Bio::EnsEMBL::Utils::IO::GTFSerializer;
use Path::Tiny;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    data_type           => 'genes',
    file_type           => 'gtf',
    per_chromosome      => 0,
    gtf_to_genepred_exe => 'gtfToGenePred',
    genepred_check_exe  => 'genePredCheck',
  };
}

sub run {
  my ($self) = @_;

  my $data_type      = $self->param_required('data_type');
  my $per_chromosome = $self->param_required('per_chromosome');
  my $filenames      = $self->param_required('filenames');

  my $dba = $self->dba;

  my ($chr, $non_chr, $non_ref) = $self->get_slices($dba);

  my $filename = $$filenames{$data_type};

  if ($per_chromosome && scalar(@$chr)) {
    $self->print_to_file($chr, 'chr', $filename, '>', $dba);
    if (scalar(@$non_chr)) {
      $self->print_to_file($non_chr, 'non_chr', $filename, '>>', $dba);
    }
  } else {
    $self->print_to_file([@$chr, @$non_chr], undef, $filename, '>', $dba);
  }

  if (scalar(@$non_ref)) {
    my $non_ref_filename = $self->generate_non_ref_filename($filename);
    path($filename)->copy($non_ref_filename);
    $self->print_to_file($non_ref, undef, $non_ref_filename, '>>', $dba);
  }

  my $output_filenames = $self->param('output_filenames');
  foreach (@$output_filenames) {
    $self->validate($_);
  }
}

sub print_to_file {
  my ($self, $slices, $region, $filename, $mode, $dba) = @_;

  my $header = $mode eq '>' ? 1 : 0;
  my $serializer = $self->gtf_serializer($filename, $mode, $header, $dba);

  my $non_chr_serializer;
  if ($region && $region eq 'non_chr') {
    my $non_chr_filename = $self->generate_non_chr_filename($filename);
    $non_chr_serializer = $self->gtf_serializer($non_chr_filename, $mode, 1, $dba);
  }

  while (my $slice = shift @{$slices}) {
    my $chr_serializer;
    if ($region && $region eq 'chr') {
      my $chr_filename = $self->generate_chr_filename($filename, $slice);
      $chr_serializer = $self->gtf_serializer($chr_filename, $mode, 1, $dba);
    }

    my $genes = $slice->get_all_Genes(undef, undef, 1);
    while (my $gene = shift @$genes) {
      $serializer->print_Gene($gene);
      if ($region && $region eq 'chr') {
        $chr_serializer->print_Gene($gene);
      } elsif ($region && $region eq 'non_chr') {
        $non_chr_serializer->print_Gene($gene);
      }
    }
  }
}

sub gtf_serializer {
  my ($self, $filename, $mode, $header, $dba) = @_;

  my $fh = path($filename)->filehandle($mode);
  my $serializer = Bio::EnsEMBL::Utils::IO::GTFSerializer->new($fh);
  if ($header) {
    $serializer->print_main_header($dba);
  }

  return $serializer;
}

sub validate {
  my ($self, $filename) = @_;
  my $gtf_to_genepred_exe = $self->param_required('gtf_to_genepred_exe');
  my $genepred_check_exe  = $self->param_required('genepred_check_exe');

  $self->assert_executable($gtf_to_genepred_exe);
  $self->assert_executable($genepred_check_exe);

  my $info_temp = Path::Tiny->tempfile();
  my $genepred_temp = Path::Tiny->tempfile();

  my $cmd_1 = 
    "$gtf_to_genepred_exe -infoOut=$info_temp -genePredExt $filename $genepred_temp";
  $self->run_cmd($cmd_1);

  my $cmd_2 = "$genepred_check_exe $genepred_temp";
  my ($rc, $output) = $self->run_cmd($cmd_2);

  unless ($output =~ /failed: 0/) {
    my $msg =
      "GTF file '$filename' failed validation with $genepred_check_exe\n".
      "Output: $output";
    $self->throw($msg);
  }
}

1;
