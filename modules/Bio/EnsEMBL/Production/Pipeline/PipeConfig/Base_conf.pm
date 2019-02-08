=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
          %{$self->SUPER::default_options},
          pipeline_dir => $ENV{'PWD'}.'/'.$self->o('pipeline_name'),
          user => $ENV{'USER'},
          email => $ENV{'USER'}.'@ebi.ac.uk'
         };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  my $options = join(' ',
    $self->SUPER::beekeeper_extra_cmdline_options,
    "-reg_conf ".$self->o('registry'),
  );
  
  return $options;
}

sub resource_classes {
    my $self = shift;
    return {
	    %{$self->SUPER::resource_classes},
      'default' => { 'LSF' => '-q production-rh7'},
      'normal'  => { 'LSF' => '-q production-rh7 -M 500 -R "rusage[mem=500]"'},
      'mem'     => { 'LSF' => '-q production-rh7 -M 2000 -R "rusage[mem=2000]"'},
    }

}

1;
