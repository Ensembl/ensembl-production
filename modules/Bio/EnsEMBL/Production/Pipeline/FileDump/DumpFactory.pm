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

package Bio::EnsEMBL::Production::Pipeline::FileDump::DumpFactory;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::FileDump::Base');

use File::Spec::Functions qw/catdir/;
use Path::Tiny;

sub run {
  my ($self) = @_;

  my $gene_related = $self->param_required('gene_related');

  my $dba = $self->dba;
  $self->param('species_name', $self->species_name($dba));
  $self->param('assembly', $self->assembly($dba));
  if ($gene_related) {
    $self->param('geneset', $self->geneset($dba));
  }

  my ($output_dir, $timestamped_dir, $tools_dir, $ftp_dir) =
    $self->directories($gene_related);

  path($output_dir)->mkpath();
  path($timestamped_dir)->mkpath();
  path($tools_dir)->mkpath();

  $self->param('output_dir', $output_dir);
  $self->param('timestamped_dir', $timestamped_dir);
  $self->param('tools_dir', $tools_dir);
  $self->param('ftp_dir', $ftp_dir);
}

sub write_output {
  my ($self) = @_;

  my $gene_related = $self->param_required('gene_related');

  my %output = (
    gene_related    => $gene_related,
    species_name    => $self->param('species_name'),
    assembly        => $self->param('assembly'),
    output_dir      => $self->param('output_dir'),
    timestamped_dir => $self->param('timestamped_dir'),
    tools_dir       => $self->param('tools_dir'),
    ftp_dir         => $self->param('ftp_dir')
  );
  if ($gene_related) {
    $output{'geneset'} = $self->param_required('geneset');
  }

  $self->dataflow_output_id(\%output, 2);
}

sub directories {
  my ($self, $gene_related) = @_;

  my $dump_dir            = $self->param_required('dump_dir');
  my $species_dirname     = $self->param_required('species_dirname');
  my $timestamped_dirname = $self->param_required('timestamped_dirname');
  my $tools_dirname       = $self->param_required('tools_dirname');
  my $genome_dirname      = $self->param_required('genome_dirname');
  my $geneset_dirname     = $self->param_required('geneset_dirname');

  my $species_name = $self->param('species_name');
  my $assembly = $self->param('assembly');

  my $subdirs;
  if ($gene_related) {
    $subdirs = catdir(
      $species_dirname,
      $species_name,
      $assembly,
      $geneset_dirname,
      $self->param('geneset')
    );
  } else {
    $subdirs = catdir(
      $species_dirname,
      $species_name,
      $assembly,
      $genome_dirname
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

  my $tools_dir = catdir(
    $dump_dir,
    $tools_dirname
  );

  my $ftp_dir;
  if ($self->param_is_defined('ftp_root')) {
    $ftp_dir = catdir(
      $self->param('ftp_root'),
      $subdirs
    );
  }

  return ($output_dir, $timestamped_dir, $tools_dir, $ftp_dir);
}

1;
