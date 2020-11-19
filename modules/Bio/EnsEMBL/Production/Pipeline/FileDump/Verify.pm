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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Verify;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::FileDump::Base');

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    check_unzipped => 1,
  };
}

sub run {
  my ($self) = @_;

  my $output_dir     = $self->param_required('output_dir');
  my $check_unzipped = $self->param_required('check_unzipped');

  my @errors;

  my $empty_dir_cmd = "find '$output_dir' -type d -empty";
  my (undef, $empty_dir) = $self->run_cmd($empty_dir_cmd);
  push @errors, map { "Empty directory: $_" } split(/\n/, $empty_dir);

  my $empty_file_cmd = "find '$output_dir' -type f -empty";
  my (undef, $empty_file) = $self->run_cmd($empty_file_cmd);
  push @errors, map { "Empty file: $_" } split(/\n/, $empty_file);

  my $broken_symlink_cmd = "find '$output_dir' -xtype l";
  my (undef, $broken_symlink) = $self->run_cmd($broken_symlink_cmd);
  push @errors, map { "Broken symlink: $_" } split(/\n/, $broken_symlink);

  if ($check_unzipped) {
    my $unzipped_file_cmd = "find '$output_dir' -type f ! -name 'README' ! -name 'md5sum.txt' ! -name '*.gz*'";
    my (undef, $unzipped_file) = $self->run_cmd($unzipped_file_cmd);
    push @errors, map { "Unzipped file: $_" } split(/\n/, $unzipped_file);
  }

  if (scalar(@errors)) {
    $self->throw(join("\n", @errors));
  }
}

1;
