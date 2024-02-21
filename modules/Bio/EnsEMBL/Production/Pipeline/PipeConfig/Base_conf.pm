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

        user              => $ENV{'USER'},
        email             => $ENV{'USER'} . '@ebi.ac.uk',

        pipeline_dir      => catdir('/hps/nobackup/flicek/ensembl/production',
            $self->o('user'),
            $self->o('pipeline_name')),

        scratch_small_dir => catdir('/hps/scratch/flicek/ensembl',
            $self->o('user'),
            $self->o('pipeline_name')),

        scratch_large_dir => catdir($self->o('pipeline_dir'), 'scratch'),
        work_dir          => catdir('/hps/software/users/ensembl/repositories/', $self->o('user')),
        production_queue  => 'production',
        datamover_queue   => 'datamover',

        #ensembl genome factory and dataset factory default params
        'metadata_db_uri'    => $self->o('metadata_db_uri'),

        #genome factory params
        'genome_uuid' => [],
        'released_genomes' => 0,
        'unreleased_genomes' => 0,
        'organism_group_type' => 'DIVISION',
        'division' => [],
        'unreleased_datasets' => 0,
        'released_datasets' => 0,
        'dataset_source_type' => [],
        'dataset_type' => [],
        'anti_dataset_type' =>[],
        'species' => [],
        'anti_species' => [],
        'biosample_id' => [],
        'anti_biosample_id' => [],
        'dataset_status' => [],
        'batch_size' => 50,
        'run_all' => 0,
        'antispecies' => [],
        'query_param' => undef,
        'query' => undef,
        'dataset_uuid' => undef, 
        'meta_filters' => {},   
        'update_dataset_status' => 0,

        #dbfactory params   
        'request_methods'    => ['update_dataset_status'],
        'request_method_params' => {'update_dataset_status' => { 'dataset_uuid' => $self->o('dataset_uuid'), 'status'=> $self->o('dataset_status')}},
    };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
    my ($self) = @_;

    my $options = join(' ',
        $self->SUPER::beekeeper_extra_cmdline_options,
        "-reg_conf " . $self->o('registry'),
    );

    return $options;
}

sub resource_classes {
    my $self = shift;


    ## Sting it together
    my %time = (H => ' --time=1:00:00',
        D         => ' --time=1-00:00:00',
        W         => ' --time=7-00:00:00',);

    my %memory = ('100M' => '100',
        '200M'           => '200',
        '500M'           => '500',
        '1GB'            => '1000',
        '2GB'            => '2000',
        '3GB'            => '3000',
        '4GB'            => '4000',
        '8GB'            => '8000',
        '16GB'           => '16000',
        '32GB'           => '32000',);

    my $pq = ' --partition=standard';
    my $dq = ' --partition=datamover';

    my %output = (
        #Default is a duplicate of 100M
        'default'   => { 'LSF' => '-q ' . $self->o('production_queue'), 'SLURM' => $pq . $time{'H'} . ' --mem=' . $memory{'100M'} . 'm' },
        'default_D' => { 'LSF' => '-q ' . $self->o('production_queue'), 'SLURM' => $pq . $time{'D'} . ' --mem=' . $memory{'100M'} . 'm' },
        'default_W' => { 'LSF' => '-q ' . $self->o('production_queue'), 'SLURM' => $pq . $time{'W'} . ' --mem=' . $memory{'100M'} . 'm' },
        #Data mover nodes
        'dm'        => { 'LSF' => '-q ' . $self->o('datamover_queue'), 'SLURM' => $dq . $time{'H'} . ' --mem=' . $memory{'100M'} . 'm' },
        'dm_D'      => { 'LSF' => '-q ' . $self->o('datamover_queue'), 'SLURM' => $dq . $time{'D'} . ' --mem=' . $memory{'100M'} . 'm' },
        'dm_W'      => { 'LSF' => '-q ' . $self->o('datamover_queue'), 'SLURM' => $dq . $time{'W'} . ' --mem=' . $memory{'100M'} . 'm' },
    );
    #Create a dictionary of all possible time and memory combinations. Format would be:
    #2G={
    #   'SLURM' => ' --partition=standard --time=1:00:00  --mem=2000m',
    #   'LSF' => '-q $self->o(production_queue) -M 2000 -R "rusage[mem=2000]"'
    # };

    while ((my $time_key, my $time_value) = each(%time)) {
        while ((my $memory_key, my $memory_value) = each(%memory)) {
            if ($time_key eq 'H') {
                $output{$memory_key} = { 'LSF' => '-q ' . $self->o('production_queue') . ' -M ' . $memory_value . ' -R "rusage[mem=' . $memory_value . ']"',
                    'SLURM'                    => $pq . $time_value . '  --mem=' . $memory_value . 'm' }
            }
            else {
                $output{$memory_key . '_' . $time_key} = { 'LSF' => '-q ' . $self->o('production_queue') . ' -M ' . $memory_value . ' -R "rusage[mem=' . $memory_value . ']"',
                    'SLURM'                                      => $pq . $time_value . '  --mem=' . $memory_value . 'm' }
            }
        }
    }

    return \%output;

}

1;
