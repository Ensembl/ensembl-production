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

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScanVersionCheck;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub run {
  my ($self) = @_;
  my $interproscan_version = $self->param_required('interproscan_version');
  my $interproscan_exe     = $self->param_required('interproscan_exe');
  
  my $interpro_cmd = "$interproscan_exe --version";
  my $version_info = `$interpro_cmd` or $self->throw("Failed to run ".$interpro_cmd);
  
  if ($version_info =~ /InterProScan version (\S+)/) {
    if ($1 ne $interproscan_version) {
      $self->throw("InterProScan version mismatch\nConf file: $interproscan_version\n$interproscan_exe: $1");
    }
  } else {
    $self->throw("Could not find version in output from $interpro_cmd:\n$version_info");
  }
}

1;
