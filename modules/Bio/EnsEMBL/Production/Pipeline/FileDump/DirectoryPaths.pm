=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FileDump::DirectoryPaths;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::FileDump::Base');

use File::Spec::Functions qw/catdir/;
use Path::Tiny;

sub run {
  my ($self) = @_;

  my $analysis_types = $self->param_required('analysis_types');
  my $data_category  = $self->param_required('data_category');

  if (scalar(@$analysis_types) == 0) {
    $self->complete_early("No $data_category analyses specified");
  }

  my $dba = $self->dba;
  $self->param('species_name', $self->species_name($dba));
  $self->param('annotation_source', $self->annotation_source($dba));
  $self->param('assembly', $self->assembly($dba));
  if ($data_category eq 'geneset') {
    $self->param('geneset', $self->geneset($dba));
  }

  my ($output_dir, $timestamped_dir, $web_dir, $ftp_dir) =
    $self->directories($data_category);

  $self->param('output_dir', $output_dir);
  $self->param('timestamped_dir', $timestamped_dir);
  $self->param('web_dir', $web_dir);
  $self->param('ftp_dir', $ftp_dir);
}

sub write_output {
  my ($self) = @_;

  my $data_category = $self->param_required('data_category');

  my %output = (
    data_category   => $data_category,
    species_name    => $self->param('species_name'),
    assembly        => $self->param('assembly'),
    output_dir      => $self->param('output_dir'),
    timestamped_dir => $self->param('timestamped_dir'),
    web_dir         => $self->param('web_dir'),
    ftp_dir         => $self->param('ftp_dir'),
    annotation_source => $self->param_required('annotation_source')
  );
  if ($data_category eq 'geneset') {
    $output{'geneset'} = $self->param_required('geneset');
  }

  $self->dataflow_output_id(\%output, 3);
}

sub directories {
  my ($self, $data_category) = @_;

  my $dump_dir            = $self->param_required('dump_dir');
  my $species_dirname     = $self->param_required('species_dirname');
  my $timestamped_dirname = $self->param_required('timestamped_dirname');
  my $web_dirname         = $self->param_required('web_dirname');
  my $genome_dirname      = $self->param_required('genome_dirname');
  my $geneset_dirname     = $self->param_required('geneset_dirname');
  my $rnaseq_dirname      = $self->param_required('rnaseq_dirname');

  my $species_name = $self->param('species_name');
  my $assembly = $self->param('assembly');

  my $subdirs;
  if ($data_category eq 'genome') {
    $subdirs = catdir(
      $species_dirname,
      $species_name,
      $assembly,
      $genome_dirname,
      $self->param_required('annotation_source')
    );
  } elsif ($data_category eq 'geneset') {
    $subdirs = catdir(
      $species_dirname,
      $species_name,
      $assembly,
      $geneset_dirname,
      $self->param_required('annotation_source'),
      $self->param('geneset')
    );
  } elsif ($data_category eq 'rnaseq') {
    $subdirs = catdir(
      $species_dirname,
      $species_name,
      $assembly,
      $rnaseq_dirname,
      $self->param_required('annotation_source')
    );
  }

  my $output_dir = catdir(
    $dump_dir,
    $subdirs
  );

  my $timestamped_dir = catdir(
    $dump_dir,
    $timestamped_dirname,
    $subdirs
  );

  my $web_dir = catdir(
    $dump_dir,
    $web_dirname
  );

  my $ftp_dir;
  if ($self->param_is_defined('ftp_root')) {
    $ftp_dir = catdir(
      $self->param('ftp_root'),
      $subdirs
    );
  }

  return ($output_dir, $timestamped_dir, $web_dir, $ftp_dir);
}

1;
