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

    scratch_small_dir => catdir( '/hps/scratch/flicek/ensembl',
                                 $self->o('user'),
                                 $self->o('pipeline_name') ),

    scratch_large_dir => catdir( $self->o('pipeline_dir'), 'scratch' ),
    work_dir => catdir( '/hps/software/users/ensembl/repositories/', $self->o('user') ),
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
  my $pq = ' --partition=standard';
  my $dq = ' --partition=datamover';

  my $hour = ' --time=1:00:00';
  my $day = ' --time=1-00:00:00';
  my $week = ' --time=7-00:00:00';

  my $mem_100 = ' --mem=100m';
  my $mem_200 = ' --mem=200m';
  my $mem_500 = ' --mem=500m';
  my $mem_1G = ' --mem=1g';
  my $mem_2G = ' --mem=2g';
  my $mem_3G = ' --mem=3g';
  my $mem_4G = ' --mem=4g';
  my $mem_8G = ' --mem=8g';
  my $mem_16G = ' --mem=16g';
  my $mem_32G = ' --mem=32g';



  return {
    'default' => {LSF => '-q '.$self->o('production_queue'), SLURM => $pq.$hour.$mem_100},
    'default_D' => {LSF => '-q '.$self->o('production_queue'), SLURM => $pq.$day.$mem_100},
    'default_W' => {LSF => '-q '.$self->o('production_queue'), SLURM => $pq.$week.$mem_100},
    'dm'      => {LSF => '-q '.$self->o('datamover_queue'), SLURM => $dq.$hour.$mem_100},
    'dm_D'      => {LSF => '-q '.$self->o('datamover_queue'), SLURM => $dq.$day.$mem_100},
    'dm_W'      => {LSF => '-q '.$self->o('datamover_queue'), SLURM => $dq.$week.$mem_100},
    '200M'    => {LSF => '-q '.$self->o('production_queue').' -M 200 -R "rusage[mem=200]"', SLURM => $pq.$hour.$mem_200 },
    '200M'    => {LSF => '-q '.$self->o('production_queue').' -M 200 -R "rusage[mem=200]"', SLURM => $pq.$day.$mem_200 },
    '200M'    => {LSF => '-q '.$self->o('production_queue').' -M 200 -R "rusage[mem=200]"', SLURM => $pq.$week.$mem_200 },
    '500M'    => {LSF => '-q '.$self->o('production_queue').' -M 500 -R "rusage[mem=500]"', SLURM => $pq.$hour.$mem_500 },
    '500M'    => {LSF => '-q '.$self->o('production_queue').' -M 500 -R "rusage[mem=500]"', SLURM => $pq.$day.$mem_500 },
    '500M'    => {LSF => '-q '.$self->o('production_queue').' -M 500 -R "rusage[mem=500]"', SLURM => $pq.$week.$mem_500 },
    '1GB'     => {LSF => '-q '.$self->o('production_queue').' -M 1000 -R "rusage[mem=1000]"', SLURM => $pq.$hour.$mem_1G },
    '1GB'     => {LSF => '-q '.$self->o('production_queue').' -M 1000 -R "rusage[mem=1000]"', SLURM => $pq.$day.$mem_1G },
    '1GB'     => {LSF => '-q '.$self->o('production_queue').' -M 1000 -R "rusage[mem=1000]"', SLURM => $pq.$week.$mem_1G },
    '2GB'     => {LSF => '-q '.$self->o('production_queue').' -M 2000 -R "rusage[mem=2000]"', SLURM => $pq.$hour.$mem_2G },
    '2GB'     => {LSF => '-q '.$self->o('production_queue').' -M 2000 -R "rusage[mem=2000]"', SLURM => $pq.$day.$mem_2G },
    '2GB'     => {LSF => '-q '.$self->o('production_queue').' -M 2000 -R "rusage[mem=2000]"', SLURM => $pq.$week.$mem_2G },
    '3GB'     => {LSF => '-q '.$self->o('production_queue').' -M 3000 -R "rusage[mem=3000]"', SLURM => $pq.$hour.$mem_3G },
    '3GB'     => {LSF => '-q '.$self->o('production_queue').' -M 3000 -R "rusage[mem=3000]"', SLURM => $pq.$day.$mem_3G },
    '3GB'     => {LSF => '-q '.$self->o('production_queue').' -M 3000 -R "rusage[mem=3000]"', SLURM => $pq.$week.$mem_3G },
    '4GB'     => {LSF => '-q '.$self->o('production_queue').' -M 4000 -R "rusage[mem=4000]"', SLURM => $pq.$hour.$mem_4G },
    '4GB'     => {LSF => '-q '.$self->o('production_queue').' -M 4000 -R "rusage[mem=4000]"', SLURM => $pq.$day.$mem_4G },
    '4GB'     => {LSF => '-q '.$self->o('production_queue').' -M 4000 -R "rusage[mem=4000]"', SLURM => $pq.$week.$mem_4G },
    '8GB'     => {LSF => '-q '.$self->o('production_queue').' -M 8000 -R "rusage[mem=8000]"', SLURM => $pq.$hour.$mem_8G },
    '8GB'     => {LSF => '-q '.$self->o('production_queue').' -M 8000 -R "rusage[mem=8000]"', SLURM => $pq.$day.$mem_8G },
    '8GB'     => {LSF => '-q '.$self->o('production_queue').' -M 8000 -R "rusage[mem=8000]"', SLURM => $pq.$week.$mem_8G },
    '16GB'    => {LSF => '-q '.$self->o('production_queue').' -M 16000 -R "rusage[mem=16000]"', SLURM => $pq.$hour.$mem_16G },
    '16GB'    => {LSF => '-q '.$self->o('production_queue').' -M 16000 -R "rusage[mem=16000]"', SLURM => $pq.$day.$mem_16G },
    '16GB'    => {LSF => '-q '.$self->o('production_queue').' -M 16000 -R "rusage[mem=16000]"', SLURM => $pq.$week.$mem_16G },
    '32GB'    => {LSF => '-q '.$self->o('production_queue').' -M 32000 -R "rusage[mem=32000]"', SLURM => $pq.$day.$mem_32G },
    '32GB'    => {LSF => '-q '.$self->o('production_queue').' -M 32000 -R "rusage[mem=32000]"', SLURM => $pq.$hour.$mem_32G },
    '32GB'    => {LSF => '-q '.$self->o('production_queue').' -M 32000 -R "rusage[mem=32000]"', SLURM => $pq.$week.$mem_32G },
  }
}

1;
