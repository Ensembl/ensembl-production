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
Bio::EnsEMBL::Production::Pipeline::PipeConfig::SearchDumps_conf
=head1 DESCRIPTION
Pipeline to generate the Solr search, EBeye search and Advanced search indexes
=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::EnsemblSearchDumps_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    species     => [],
    division    => [],
    antispecies => [],
    run_all     => 0,

    use_pan_compara   => 0, 
    variant_length    => 1000000,
    probe_length      => 100000,
    regulatory_length => 100000,
    dump_variant      => 1,
    dump_regulation   => 1,
    resource_class    => '32GB',

    gene_search_reformat => 0,

    release => $self->o('ensembl_release'),
    exclude_xref_external_db_list => [
      'DBASS3',
      'DBASS5',
      'Ens_Hs_gene',
      'Ens_Hs_transcript',
      'Ens_Hs_translation',
      'Clone_based_ensembl_gene',
      'Clone_based_ensembl_transcript',
      'Clone_based_vega_gene',
      'Clone_based_vega_transcript',
      'goslim_goa',
      'KEGG_Enzyme',
      'LRG',
      'MetaCyc',
      'OTTG',
      'OTTT',
      'shares_CDS_and_UTR_with_OTTT',
      'shares_CDS_with_OTTT',
      'UniGene',
      'UniPathway',
      'Vega_transcript',
      'Vega_translation',
      'ENS_LRG_gene',
      'ENS_LRG_transcript',
    ]
	};
}

sub pipeline_wide_parameters {
  my $self = shift;
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },
    base_path => $self->o('base_path'),
    gene_search_reformat => $self->o('gene_search_reformat')
  };
}


sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},      
        'hive_use_param_stack'  => 1,
    };
}


sub pipeline_analyses {
  my $self = shift;

  return [

    {
      -logic_name => 'init_pipeline',
      -module => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids  => [{}],
      -flow_into  => {
        '1'    => 'GenomeFactory',
      },
      -rc_name    => 'default',
    },

    {
        -logic_name      => 'GenomeFactory',
        -module          => 'ensembl.production.hive.HiveGenomeFactory',
        -language        => 'python3',
        -rc_name         => 'default', 
        -parameters => {
                        'metadata_db_uri'    => $self->o('metadata_db_uri'),
                        'genome_uuid' => $self->o('genome_uuid'),
                        'released_genomes' => $self->o('released_genomes'),
                        'unreleased_genomes' => $self->o('unreleased_genomes'),
                        'organism_group_type' => $self->o('organism_group_type'),
                        'division' => $self->o('division'),
                        'unreleased_datasets' => $self->o('unreleased_datasets'),
                        'released_datasets' => $self->o('released_datasets'),
                        'dataset_source_type' => $self->o('dataset_source_type'),
                        'dataset_type' => $self->o('dataset_type'),
                        'anti_dataset_type' => $self->o('anti_dataset_type'),
                        'species' => $self->o('species'),
                        'antispecies' => $self->o('antispecies'),
                        'biosample_id' => $self->o('biosample_id'),
                        'anti_biosample_id' => $self->o('anti_biosample_id'),
                        'dataset_status' => $self->o('dataset_status'),
                        'batch_size' => $self->o('batch_size'),
                        'run_all' => $self->o('run_all'),
                        'query_param' => $self->o('query_param'),
                        'query' => $self->o('query'),
                        'dataset_uuid' => $self->o('dataset_uuid'),   
                        'update_dataset_status' => $self->o('update_dataset_status'),       
                      }, 
        -flow_into  => {
                        '2->A'    => ['UpdateDatasetStatusToSubmit'],
                        'A->2'    => 'UpdateDatasetStatus'   
                      },

    },
    {
      -logic_name      => 'UpdateDatasetStatusToSubmit',
      -module          => 'ensembl.production.hive.HiveDatasetFactory',
      -language        => 'python3',
      -rc_name         => 'default', 
      -parameters      => {
                            'metadata_db_uri'    => $self->o('metadata_db_uri'),
                            'request_method_params' => $self->o('request_method_params'),
                            'request_methods'    => $self->o('request_methods'),         
                          },   
      -flow_into  => {
                        '1'    => ['SpeciesFactory'],
                      },
    },    
    {
      -logic_name => 'SpeciesFactory',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
	    -flow_into  => {
                      '2' => [ 'DumpGenesJson' ], #core
                      '7' => ['DumpGenesJson'], #otherfeature
                     },
    },
    {
      -logic_name => 'DumpGenesJson',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenesJson',
      -parameters => { use_pan_compara => $self->o('use_pan_compara') , exclude_xref_external_db_list => $self->o('exclude_xref_external_db_list') },
      -flow_into  => {
                      -1 => 'DumpGenesJsonHighmem'
                     },
      -rc_name    => $self->o('resource_class'),
      -analysis_capacity => 10
    },
    {
      -logic_name => 'DumpGenesJsonHighmem',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenesJson',
      -parameters => { use_pan_compara => $self->o('use_pan_compara') },
      -rc_name    => '100GB',
      -analysis_capacity => 10
    },
    {
      -logic_name      => 'UpdateDatasetStatus',
      -module          => 'ensembl.production.hive.HiveDatasetFactory',
      -language        => 'python3',
      -rc_name         => 'default', 
      -parameters      => {
                            'metadata_db_uri'    => $self->o('metadata_db_uri'),
                            'request_method_params' => $self->o('request_method_params'),
                            'request_methods'    => $self->o('request_methods'),         
                          },   
    },
  ];
}

sub resource_classes {
  my ($self) = @_;
  return {
    %{$self->SUPER::resource_classes},
    '100GB' => {'LSF' => '-q '.$self->o('production_queue').' -M 100000 -R "rusage[mem=100000]"'},
  }
}

1;