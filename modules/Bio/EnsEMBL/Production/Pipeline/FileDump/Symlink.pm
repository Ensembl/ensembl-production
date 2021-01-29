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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Symlink;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::FileDump::Base');

use File::Spec::Functions qw/catdir/;
use Path::Tiny;

sub run {
  my ($self) = @_;

  my $dump_dir        = $self->param_required('dump_dir');
  my $data_category   = $self->param_required('data_category');
  my $output_dir      = $self->param_required('output_dir');
  my $output_filename = $self->param_required('output_filename');

  my $source_file = "$output_filename.gz";
  if (! -e $source_file) {
    $self->throw("Source file does not exist: $source_file");
  }

  my $relative_dir;
  if ($data_category eq 'geneset') {
    $relative_dir = catdir('..', '..', '..', '..', '..');
  } else {
    $relative_dir = catdir('..', '..', '..', '..');
  }

  $source_file =~ s/$dump_dir/$relative_dir/;

  my $basename = path($source_file)->basename;
  my $target_file = catdir($output_dir, $basename);

  $self->create_symlink($source_file, $target_file);
}

1;
