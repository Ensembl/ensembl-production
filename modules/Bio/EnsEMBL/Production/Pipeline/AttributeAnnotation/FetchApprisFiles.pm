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

package Bio::EnsEMBL::Production::Pipeline::AttributeAnnotation::FetchApprisFiles;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Path::Tiny;

sub run {
  my ($self) = @_;
  my $appris_url   = $self->param_required('appris_url');
  my $pipeline_dir = $self->param_required('pipeline_dir');

  my $wget = "wget -nd -r $appris_url -P $pipeline_dir -A txt";
  if ( system($wget) ) {
    $self->throw("Could not copy files from $appris_url to $pipeline_dir");
  } else {
    $self->info("Copied files from $appris_url to $pipeline_dir");
  }

  my @local_files = path("$pipeline_dir")->children(qr/appris/);

  my %files;
  my %skip;
  foreach my $local_file (@local_files) {
    my ($species, $version) = $local_file->basename =~ /^(\w+).*e(\d+)\.appris/;
    $species = lc($species);

    # If the species is not in the registry that the pipeline
    # is using, we don't need to process it.
    next if exists $skip{$species};
    eval { 
      Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
    };
    if ($@) {
      $self->warning("Skipping $species, not in registry");
      $skip{$species} = 1;
      next;
    }

    # There may be files for multiple versions, so pick the most recent.
    if (exists $files{$species}) {
      if ($version > $files{$species}{'version'}) {
        $files{$species}{'file'} = $local_file->stringify;
        $files{$species}{'version'} = $version;
      }
    } else {
      $files{$species}{'file'} = $local_file->stringify;
      $files{$species}{'version'} = $version;
    }
  }

  foreach my $species (keys %files) {
    $self->info("Most recent APPRIS file for $species is version ".$files{$species}{'version'});
  }

  $self->param('files', \%files);
}

sub write_output {
  my ($self) = @_;
  my %files = %{ $self->param('files') };

  foreach my $species (keys %files) {
    $self->dataflow_output_id(
    {
      'species'  => $species,
      'file'     => $files{$species}{'file'}
    }, 2);
  }
}

1;
