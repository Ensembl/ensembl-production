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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Symlink_RNASeq;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::FileDump::Base');

use File::Spec::Functions qw/catdir/;
use Path::Tiny;

sub run {
  my ($self) = @_;

  my $dump_dir   = $self->param_required('dump_dir');
  my $output_dir = $self->param_required('output_dir');
  my $web_dir    = $self->param_required('web_dir');

  if (-e $output_dir) {
    my $dba = $self->dba;
    my $mca = $dba->get_adaptor('MetaContainer');
    my $production_name = $mca->get_production_name;
    my $assembly_default = $mca->single_value_by_key('assembly.default');

    my $data_files_dir = catdir(
      $web_dir,
      'data_files',
      $production_name,
      $assembly_default
    );
    path($data_files_dir)->mkpath();
    path($data_files_dir)->chmod("g+w");

    my $relative_dir = catdir('..', '..', '..', '..', '..');
    $output_dir =~ s/$dump_dir/$relative_dir/;

    $self->create_symlink($output_dir, catdir($data_files_dir, 'rnaseq'));
  }
}

1;
