=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FileDump::BlastDirectoryPaths;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::FileDump::Base');

use File::Spec::Functions qw/catdir/;
use Path::Tiny;
use Data::Dumper;
sub run {
  my ($self) = @_;

  my $analysis_types = $self->param_required('analysis_types');
  my $data_category  = $self->param_required('data_category');
  my $genome_uuid    = $self->param_required('genome_uuid');

  if (scalar(@$analysis_types) == 0) {
    $self->complete_early("No $data_category analyses specified");
  }

  my $dba = $self->dba;
  $self->param('species_name', $self->species_name($dba));
  $self->param('assembly', $self->assembly($dba));

  if ($data_category =~ /geneset|variation|homology/) {
    $self->param('geneset', $self->geneset($dba));
  }

  my ($output_dir, $timestamped_dir, $web_dir) =
    $self->directories($data_category);

  $self->param('output_dir', $output_dir);
  $self->param('timestamped_dir', $timestamped_dir);
  $self->param('web_dir', $web_dir);


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
    genome_uuid     => $self->param_required('genome_uuid'),
  );
  # if ($data_category =~ /geneset|variation|homology/) {
  #   $output{'geneset'} = $self->param('geneset');
  # }

  $self->dataflow_output_id(\%output, 3);
}

sub directories {
  my ($self, $data_category) = @_;

  my $dump_dir                    = $self->param_required('dump_dir');
  my $species_dirname             = $self->param_required('species_dirname');
  my $timestamped_dirname         = $self->param_required('timestamped_dirname');
  my $web_dirname                 = $self->param_required('web_dirname');
  my $species_production_name     = $self->param('species');
  my $assembly                    = $self->param('assembly');

  my $subdirs;
  my @data_categories = ("genome", "geneset", "rnaseq", "variation", "homology", "stats");
  if ( grep( /^$data_category$/, @data_categories ) ) {
    $subdirs = catdir(
      $self->param_required('genome_uuid'),
      #$self->param_required("${data_category}_dirname"), # uncommnet if subdirectory gene or genome needed
      # $species_production_name,
      # $assembly
    );
  }

  my $output_dir = catdir(
    $dump_dir,
    $subdirs
  );

  my $timestamped_dir = catdir(
    $dump_dir,
    $subdirs
    # $timestamped_dirname,
    # $subdirs
  );

  my $web_dir = catdir(
    $dump_dir,
    $subdirs
    #$web_dirname
  );

  return ($output_dir, $timestamped_dir, $web_dir);
}

1;
