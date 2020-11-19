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

package Bio::EnsEMBL::Production::Pipeline::FileDump::RNASeq_Exists;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::FileDump::Base);

use File::Spec::Functions qw/catdir/;

sub run {
  my ($self) = @_;

  my $output_dir = $self->param_required('output_dir');
  my $species    = $self->param_required('species');

  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'rnaseq');
  my $rnaseq_exists = defined $dba;

  if ($rnaseq_exists) {
    my $dfa = $dba->get_adaptor('DataFile');
    my $data_files = $dfa->fetch_all;

    my @missing;
    foreach my $data_file (@$data_files) {
      my $name = $data_file->name;
      my @paths;
      
      my $extensions = $dfa->DataFile_to_extensions($data_file);
      foreach my $ext (@{$extensions}) {
        my $filename = catdir($output_dir, "$name.$ext");
        push(@paths, $filename);
      }

      foreach my $path (@paths){
        if (! -e $path) {
          # .csi files are permitted in place of .bai files, but
          # this is not encoded in the core API.
          (my $new_path = $path) =~ s/bai$/csi/;
          if (! -e $new_path) {
            push @missing, $path;
          }
        }
      }
    }
    if (scalar(@missing)) {
      $self->throw('Missing data files: '.join(',', @missing));
    }
  }

  $self->param('rnaseq_exists', $rnaseq_exists);
}

sub write_output {
  my ($self) = @_;
  my $rnaseq_exists = $self->param_required('rnaseq_exists');

  if ($rnaseq_exists) {
    $self->dataflow_output_id({}, 2);
  }
}

1;
