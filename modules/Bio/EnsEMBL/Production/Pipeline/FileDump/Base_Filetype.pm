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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Base_Filetype;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::FileDump::Base');

use File::Spec::Functions qw/catdir/;
use Path::Tiny;
use Time::Piece;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    data_types  => [],
    timestamped => 0,
    overwrite   => 0,
  };
}

sub pre_cleanup {
  my ($self) = @_;

  # If the job fails and is subsequently re-run, we want to overwrite,
  # because the file could be incomplete, but would be skipped if the
  # file already existed (and overwriting was not already enabled).
  $self->param('overwrite', 1);
}

sub fetch_input {
  my ($self) = @_;

  my $filenames;

  my $custom_filenames = $self->param('custom_filenames');

  if (defined $custom_filenames) {
    $filenames = $custom_filenames;
  } else {
    my $overwrite = $self->param_required('overwrite');

    $filenames = $self->filenames();
    $self->param('output_filenames', []);

    if (! $overwrite) {
      # All files should be compressed - if there is an uncompressed file,
      # it's likely that it is partial, the result of an aborted
      # previous run. So safest approach is to recreate in that case.
      my $compressed = 0;
      foreach my $filename ( values %{$filenames} ) {
        if (-s "$filename.gz") {
          $compressed++;
        }
      }
      if (scalar(keys %{$filenames}) == $compressed) {
        $self->complete_early('Files exist and will not be overwritten');
      }
    }
  }

  $self->param('filenames', $filenames);
  $self->param('output_filenames', [ values %{$filenames} ]);
}

sub write_output {
  my ($self) = @_;

  foreach my $output_filename (@{$self->param('output_filenames')}) {    
    $self->dataflow_output_id(
      { output_filename => $output_filename },
      2
    );
  }
}

sub filenames {
  my ($self) = @_;

  my $data_type    = $self->param_required('data_type');
  my $data_types   = $self->param_required('data_types');
  my $file_type    = $self->param_required('file_type');
  my $timestamped  = $self->param_required('timestamped');
  my $species_name = $self->param_required('species_name');
  my $assembly     = $self->param_required('assembly');

  my $dir;
  if ($timestamped) {
    $dir = catdir(
      $self->param('timestamped_dir'),
      $data_type,
      $self->timestamp($self->dba),
    );
  } else {
    $dir = $self->param('output_dir');
  }
  path($dir)->mkpath();

  my %filenames;

  # If there is a single data_type, use that; otherwise use list.
  my @data_types = @$data_types;
  unless (scalar @$data_types){
    push @data_types, $data_type;
  }

  foreach my $data_type (@data_types) {
    my $filename;

    if ($self->param_is_defined('geneset')) {
      my $geneset = $self->param('geneset');
      $filename = catdir(
        $dir,
        "$species_name-$assembly-$geneset-$data_type.$file_type"
      );
    } else {
      $filename = catdir(
        $dir,
        "$species_name-$assembly-$data_type.$file_type"
      );
    }

    $filenames{$data_type} = $filename;
  }

  return \%filenames;
}

sub timestamp {
  my ($self, $dba) = @_;

  return Time::Piece->new->date("");;
}

sub generate_chr_filename {
  my ($self, $filename, $slice) = @_;

  my $chr_type = $slice->coord_system_name();
  $chr_type = 'chromosome' if $chr_type eq 'primary_assembly';
  my $chr_name = $slice->seq_region_name();
  (my $chr_filename = $filename) =~ s/(\.[^\.]+)$/\-$chr_type\_$chr_name$1/;

  my $output_filenames = $self->param('output_filenames');
  push @$output_filenames, $chr_filename;
  $self->param('output_filenames', $output_filenames);

  return $chr_filename;
}

sub generate_non_chr_filename {
  my ($self, $filename) = @_;

  (my $non_chr_filename = $filename) =~ s/(\.[^\.]+)$/\-non_chromosomal$1/;

  my $output_filenames = $self->param('output_filenames');
  push @$output_filenames, $non_chr_filename;
  $self->param('output_filenames', $output_filenames);

  return $non_chr_filename;
}

sub generate_non_ref_filename {
  my ($self, $filename) = @_;

  (my $non_ref_filename = $filename) =~ s/(\.[^\.]+)$/\-including_alt$1/;

  my $output_filenames = $self->param('output_filenames');
  push @$output_filenames, $non_ref_filename;
  $self->param('output_filenames', $output_filenames);

  return $non_ref_filename;
}

sub generate_custom_filename {
  my ($self, $output_dir, $basename, $file_type) = @_;

  my $filename = catdir($output_dir, "$basename.$file_type");

  my $output_filenames = $self->param('output_filenames');
  push @$output_filenames, $filename;
  $self->param('output_filenames', $output_filenames);

  return $filename;
}

sub create_blast_index {
  my ($self, $in, $out, $dbtype) = @_;
  my $blastdb_exe = $self->param_required('blastdb_exe');

  $self->assert_executable($blastdb_exe);

  my $title = path($out)->basename('.fa');
  my $cmd = "$blastdb_exe -in $in -out $out -dbtype $dbtype -title $title -input_type fasta";
  my ($rc, $output) = $self->run_cmd($cmd);

  if ($rc) {
    my $msg =
      "BLAST failed for '$out'\n".
      "Output: $output";
    $self->throw($msg);
  }
}

1;
