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

package Bio::EnsEMBL::Production::Pipeline::AttributeAnnotation::FetchTSLFile;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Path::Tiny;

sub run {
  my ($self) = @_;
  my $tsl_url      = $self->param_required('tsl_url');
  my $pipeline_dir = $self->param_required('pipeline_dir');
  my $species      = $self->param_required('species');

  my $wget = "wget -m -np -nd -e robots=off -r $tsl_url -P $pipeline_dir -A tsv.gz";
  if ( system($wget) ) {
    $self->throw("Could not copy files from $tsl_url to $pipeline_dir");
  } else {
    $self->info("Copied files from $tsl_url to $pipeline_dir");
  }

  my $pattern;
  if ($species eq 'homo_sapiens') {
    $pattern = 'gencode.v\d+';
  } elsif ($species eq 'mus_musculus') {
    $pattern = 'gencode.vM\d+';
  } else {
    $self->throw("Species '$species' is not supported by TSL");
  }
  my @local_files = path("$pipeline_dir")->children(qr/$pattern/);
  
  my %files;
  my $most_recent = 0;
  foreach my $local_file (@local_files) {
    # Extract Gencode version and use that to pick most recent file.
    my ($version) = $local_file->stringify =~ /gencode\.vM?(\d+)/;

    if ($version > $most_recent) {
      print "$version > $most_recent\n";
      $most_recent = $version;
      $self->param('file', $local_file->stringify);
    }
  }
  $self->info("Most recent TSL file is version $most_recent");
}

sub write_output {
  my ($self) = @_;

  $self->dataflow_output_id({ 'file' => $self->param('file') }, 3);
}

1;
