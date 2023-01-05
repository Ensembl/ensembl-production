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


=pod

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::FetchFile

=head1 DESCRIPTION

Download files from local filesystem or ftp site.

=cut

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::FetchFile;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::FetchExternal');

use File::Spec::Functions qw(catdir);

sub run {
  my ($self) = @_;
  my $ebi_path    = $self->param_required('ebi_path');
  my $ftp_uri     = $self->param_required('ftp_uri');
  my $remote_file = $self->param_required('remote_file');
  my $local_file  = $self->param_required('local_file');

  my $ebi_file = catdir($ebi_path, $remote_file);

  if (-e $ebi_file) {
    $self->fetch_ebi_file($ebi_file, $local_file);
  } else {
    my $ftp = $self->get_ftp($ftp_uri);
    $self->fetch_ftp_file($ftp, $remote_file, $local_file);
  }
}

# Override inherited method, no action required.
sub write_output {
  my ($self) = @_;
}

1;
