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

package Bio::EnsEMBL::Production::Pipeline::FileDump::README;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::FileDump::Base');

use File::Spec::Functions qw/catdir/;
use Path::Tiny;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    root_readmes => {
      geneset => ['README.txt'],
      genome  => ['README.txt'],
      rnaseq  => [],
    },
  };
}

sub run {
  my ($self) = @_;
  my $root_readmes  = $self->param_required('root_readmes');
  my $data_category = $self->param_required('data_category');
  my $ftp_root      = $self->param_required('ftp_root');
  my $ftp_dir       = $self->param_required('ftp_dir');

  foreach my $readme (@{ $$root_readmes{$data_category} }) {
    # Sync README to the root of the ftp directory; it probably
    # will not have changed, but doing it here means we don't need
    # to rely on another pipeline/process for updating it.
    my $readme_location = $self->readme_location($readme);
    my $rsync_cmd = "rsync -aW $readme_location $ftp_root";
    $self->run_cmd($rsync_cmd);
    path(catdir($ftp_root, $readme))->chmod("g+w");

    my $relative_dir;
    if ($data_category eq 'geneset') {
      $relative_dir = catdir('..', '..', '..', '..', '..');
    } else {
      $relative_dir= catdir('..', '..', '..', '..');
    }

    my $from = catdir($relative_dir, $readme);
    my $to = catdir($ftp_dir, $readme);

    $self->create_symlink($from, $to);
  }
}

sub readme_location {
  my ($self, $readme) = @_;

  my $repo_location = $self->repo_location();

  my $readme_location = catdir(
    $repo_location,
    'modules/Bio/EnsEMBL/Production/Pipeline/FileDump',
    $readme
  );
}

1;
