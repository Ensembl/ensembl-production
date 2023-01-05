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

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScanVersionCheck;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use File::Fetch;
use File::Spec::Functions qw(catdir);
use Path::Tiny;

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    interproscan_version => 'current',
  };
}

sub run {
  my ($self) = @_;
  my $interproscan_path    = $self->param_required('interproscan_path');
  my $interproscan_version = $self->param_required('interproscan_version');
  my $local_computation    = $self->param_required('local_computation');

  my $service_version_file = 'http://www.ebi.ac.uk/interpro/match-lookup/version';

  my $interproscan_exe = catdir($interproscan_path, $interproscan_version, 'interproscan.sh');
  my $interpro_cmd = "$interproscan_exe --version";
  my $version_info = `$interpro_cmd` or $self->throw("Failed to run ".$interpro_cmd);

  if ($version_info =~ /InterProScan version (\S+)/) {
    my $cmd_version = $1;

    if (! $local_computation) {
      my $temp_dir = Path::Tiny->tempdir();
      my $ff = File::Fetch->new(uri => $service_version_file);
      my $file = $ff->fetch(to => $temp_dir->stringify);
      my $data = path($file)->slurp;
      if ($data =~ /SERVER:(\S+)/) {
        my $service_version = $1;
        if ($service_version ne $cmd_version) {
          $self->throw("InterProScan version mismatch\n$interproscan_exe: $cmd_version\n$service_version_file: $service_version");
        }
      } else {
        $self->throw("Could not find version in service file:\n$service_version_file\n$data");
      }
    }

    # To guard against the 'current' version changing during pipeline
    # execution, we explicitly use the version in the excutable path.
    $interproscan_exe = catdir($interproscan_path, "interproscan-$cmd_version", 'interproscan.sh');
    $interpro_cmd = "$interproscan_exe --version";
    `$interpro_cmd` or $self->throw("Failed to run ".$interpro_cmd);

    $self->param('interproscan_exe', $interproscan_exe);
    $self->param('interproscan_version', $cmd_version);

  } else {
    $self->throw("Could not find version in output from $interpro_cmd:\n$version_info");
  }
}

sub write_output {
  my ($self) = @_;

  $self->dataflow_output_id(
    {
        interproscan_exe     => $self->param('interproscan_exe'),
        interproscan_version => $self->param('interproscan_version'),
    }, 3 );
}

1;
