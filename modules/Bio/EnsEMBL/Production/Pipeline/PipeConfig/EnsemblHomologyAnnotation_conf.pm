=head1 LICENSE
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2025] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::HomologyAnnotation_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Production::Pipeline::PipeConfig::EnsemblHomologyAnnotation_conf -host mysql-ens-compara-prod-X -port XXXX \
         -dataset_type  -dataset_status Submitted -metadata_db_uri mysql://localhost:3366/ensembl_genome_metadata

=head1 DESCRIPTION

The PipeConfig file for the pipeline that annotates gene members by homology

=cut


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::EnsemblHomologyAnnotation_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf;
use base ('Bio::EnsEMBL::Compara::PipeConfig::HomologyAnnotation_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # Inherit the generic ones
        #genome factory params
        'metadata_db_uri'       => $self->o('metadata_db_uri'),
        'genome_uuid'           => [],
        'dataset_uuid'          => [],
        'dataset_status'        => 'Submitted',
        'organism_group_type'   => 'DIVISION',
        'dataset_type'          => 'homology_compute',
        'antispecies'           => [],
        'batch_size'            => 50,
        'meta_filters'          => {},
        'update_dataset_status' => 'Processing', #updates dataset status in new metadata db
        #param to connect to old pipeline analysis name
    };
}
sub core_pipeline_analyses {
    my ($self) = @_;
    my %dc_parameters = (
        'datacheck_groups' => $self->o('dc_pipeline_grp'),
        'db_type'          => $self->o('db_type'),
        'old_server_uri'   => $self->o('old_server_uri'),
        'registry_file'    => undef,
    );

    my @core_compara_analyses = ();
    foreach my $hash (@{Bio::EnsEMBL::Compara::PipeConfig::HomologyAnnotation_conf::core_pipeline_analyses($self)}) {
        if ($hash->{'-logic_name'} eq 'core_species_factory') {
            $hash->{'-parameters'} = $hash->{'-input_ids'}->[0];
            delete $hash->{'-input_ids'};
        }
        push @core_compara_analyses, $hash;
    }

    my @production_factories = ();
    foreach my $hash (@{Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf::factory_analyses($self)}) {
        if ($hash->{'-logic_name'} eq 'GenomeFactory') {
            $hash->{'-parameters'}->{'division'} = []; # let it to empty array as it conflicts with the division defined in base class  Bio::EnsEMBL::Compara::PipeConfig::HomologyAnnotation_conf -> 'division' => 'homology_annotation',
            $hash->{'-parameters'}->{'dataset_uuid'} = $self->o('dataset_uuid');
            $hash->{'-rc_name'} = '2Gb_job';
            $hash->{'-flow_into'} = {
                      '3->A'    => { 'core_species_factory'  => INPUT_PLUS()  }, # logic name core_species_factory is from base class  Bio::EnsEMBL::Compara::PipeConfig::HomologyAnnotation_conf
                      'A->3'    => [{'UpdateDatasetStatus'=> INPUT_PLUS()}]
            },
        }
        push @production_factories, $hash;
    }
    return [
        @production_factories,
        @core_compara_analyses,
    ];
}


1;
