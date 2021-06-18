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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    user  => $ENV{'USER'},
    email => $ENV{'USER'}.'@ebi.ac.uk',

    pipeline_dir => catdir( '/hps/nobackup/flicek/ensembl/production',
                            $self->o('user'),
                            $self->o('pipeline_name') ),

    scratch_small_dir => catdir( '/hps/scratch',
                                 $self->o('user'),
                                 $self->o('pipeline_name') ),

    scratch_large_dir => catdir( $self->o('pipeline_dir'), 'scratch' ),

    production_queue => 'production',
    datamover_queue => 'datamover',
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
    'default' => {LSF => '-q '.$self->o('production_queue')},
    'dm'      => {LSF => '-q '.$self->o('datamover_queue')},
     '1GB'    => {LSF => '-q '.$self->o('production_queue').' -M  1000 -R "rusage[mem=1000]"'},
     '2GB'    => {LSF => '-q '.$self->o('production_queue').' -M  2000 -R "rusage[mem=2000]"'},
     '4GB'    => {LSF => '-q '.$self->o('production_queue').' -M  4000 -R "rusage[mem=4000]"'},
     '8GB'    => {LSF => '-q '.$self->o('production_queue').' -M  8000 -R "rusage[mem=8000]"'},
    '16GB'    => {LSF => '-q '.$self->o('production_queue').' -M 16000 -R "rusage[mem=16000]"'},
    '32GB'    => {LSF => '-q '.$self->o('production_queue').' -M 32000 -R "rusage[mem=32000]"'},
  }
}

1;
