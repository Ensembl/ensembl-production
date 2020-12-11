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

package Bio::EnsEMBL::Production::Pipeline::GPAD::FindFile;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use File::Spec::Functions qw(catdir);

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub write_output {
  my ($self)  = @_;
  my $gpad_directory = $self->param_required('gpad_directory');
  my $gpad_dirname   = $self->param('gpad_dirname');
  my $species        = $self->param_required('species');

  my $filename = "annotations_ensembl-$species.gpa";

  my $file;
  if (defined $gpad_dirname) {
    $file = catdir($gpad_directory, $gpad_dirname, $filename);
  } else {
    my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $species, 'core' );
    my $division = $dba->get_MetaContainer->get_division();
    $file = catdir($gpad_directory, lc($division), $filename);
    $dba->dbc->disconnect_if_idle();
  }

  if (-e $file) {
    $self->dataflow_output_id(
      { 'gpad_file' => $file, 'species' => $species },
      2
    );
  }
}

1;
