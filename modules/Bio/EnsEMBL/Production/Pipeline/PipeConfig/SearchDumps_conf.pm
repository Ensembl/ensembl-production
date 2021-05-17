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

=pod

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PipeConfig::SearchDumps_conf

=head1 DESCRIPTION

Pipeline to generate the Solr search, EBeye search and Advanced search indexes

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::SearchDumps_conf;

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

    release => $self->o('ensembl_release')
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

sub pipeline_analyses {
  my $self = shift;

  my @variant_analyses = [ 'VariantDumpFactory' ] if $self->o('dump_variant') == 1;
  my @regulation_analyses = $self->o('dump_regulation') == 1 ? [ 'RegulationDumpFactory', 'ProbeDumpFactory' ] : [ 'ProbeDumpFactory' ];

  return [
    {
      -logic_name => 'SpeciesFactory',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -input_ids  => [ {} ],
      -parameters => {
                      species     => $self->o('species'),
                      antispecies => $self->o('antispecies'),
                      division    => $self->o('division'),
                      run_all     => $self->o('run_all'),
                     },
	    -flow_into  => {
                      '2->A' => [ 'DumpGenomeJson' ],
                      'A->1' => [ 'WrapGenomeEBeye' ]
                     },
    },
    {
      -logic_name => 'WrapGenomeEBeye',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::WrapGenomeEBeye',
      -parameters => {
                      division => $self->o('division'),
                      release  => $self->o('release'),
                     },
      -flow_into => [ 'ValidateXMLFileWrappedGenomesEBeye' ],
    },
    {
      -logic_name => 'DumpGenomeJson',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenomeJson',
      -flow_into  => {
                      2 => [ 'DumpGenesJson' ],
                      7 => [ 'DumpGenesJson' ],
                      4 => @variant_analyses, 
                      6 => @regulation_analyses,
                     },
      -analysis_capacity => 10,
    },
    {
      -logic_name => 'ValidateXMLFileEBeye',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ValidateXMLFileEBeye',
      -parameters => {
                      division => $self->o('division'),
                      release  => $self->o('release'),
                     },
      -flow_into  => {
                      1 => [ 'CompressEBeyeXMLFile' ],
                      2 => [ '?accu_name=genome_files&accu_address={species}&accu_input_variable=genome_valid_file' ]
                     },
    },
    {
      -logic_name => 'ValidateXMLFileVariantEBeye',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ValidateXMLFileEBeye',
      -parameters => {
                      division => $self->o('division'),
                      release  => $self->o('release'),
                     },
      -flow_into  => [ 'CompressVariantEBeyeXMLFile' ],
    },
    {
      -logic_name => 'ValidateXMLFileWrappedGenomesEBeye',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ValidateXMLFileEBeye',
      -parameters => {
                      division => $self->o('division'),
                      release  => $self->o('release'),
                     },
      -flow_into  => [ 'CompressWrappedGenomesEBeyeXMLFile' ],
    },
    {
      -logic_name => 'CompressEBeyeXMLFile',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::CompressEBeyeXMLFile',
      -parameters => {
                      division => $self->o('division'),
                      release  => $self->o('release'),
                     },
      -analysis_capacity => 4,
    },
    {
      -logic_name => 'CompressWrappedGenomesEBeyeXMLFile',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::CompressEBeyeXMLFile',
      -parameters => {
                      division => $self->o('division'),
                      release  => $self->o('release'),
                     },
      -analysis_capacity => 4,
    },
    {
      -logic_name => 'CompressVariantEBeyeXMLFile',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::CompressEBeyeXMLFile',
      -parameters => {
                      division => $self->o('division'),
                      release  => $self->o('release'),
                     },
      -analysis_capacity => 4,
    },
    {
      -logic_name => 'DumpGenesJson',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenesJson',
      -parameters => { use_pan_compara => $self->o('use_pan_compara') },
      -flow_into  => {
                      1 =>
                        WHEN ('#gene_search_reformat#' =>
                          [
                            'ReformatGenomeAdvancedSearch',
                            'ReformatGenomeEBeye'
                          ],
                        ELSE ['ReformatGenomeEBeye'],
                      ),
                      -1 => 'DumpGenesJsonHighmem'
                     },
      -rc_name    => $self->o('resource_class'),
      -analysis_capacity => 10
    },
    {
      -logic_name => 'DumpGenesJsonHighmem',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenesJson',
      -parameters => { use_pan_compara => $self->o('use_pan_compara') },
      -flow_into  => {
                      1 =>
                        WHEN ('#gene_search_reformat#' =>
                          [
                            'ReformatGenomeAdvancedSearch',
                            'ReformatGenomeEBeye'
                          ],
                        ELSE ['ReformatGenomeEBeye'],
                      ),
                     },
      -rc_name    => '100GB',
      -analysis_capacity => 10
    },
    {
      -logic_name => 'DumpRegulationJson',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpRegulationJson',
      -flow_into  => {
                      2 => [
                        '?accu_name=motifs_dump_file&accu_address=[]',
                        '?accu_name=regulatory_features_dump_file&accu_address=[]',
                        '?accu_name=mirna_dump_file&accu_address=[]',
                        '?accu_name=external_features_dump_file&accu_address=[]',
                        '?accu_name=peaks_dump_file&accu_address=[]',
                        '?accu_name=transcription_factors_dump_file&accu_address=[]',
                        '?accu_name=species'
                      ]
                     },
      -rc_name    => $self->o('resource_class'),
      -analysis_capacity => 10
    },
    {
      -logic_name => 'RegulationDumpMerge',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpRegulationMerge',
      -flow_into  => {
                      2 => WHEN ('#gene_search_reformat#' => ['ReformatRegulationAdvancedSearch']),
                     }
    },
    {
      -logic_name => 'VariantDumpFactory',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
      -parameters => {
                      type   => 'variation',
                      table  => 'variation',
                      column => 'variation_id',
                      length => $self->o('variant_length')
                     },
      -flow_into  => {
                      '2->A' => 'DumpVariantJson',
                      'A->1' => 'VariantDumpMerge'
                     }
    },
    {
      -logic_name => 'DumpVariantJson',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpVariantJson',
      -flow_into  => {
                      2 => [
                        '?accu_name=dump_file&accu_address=[]',
                        '?accu_name=species'
                      ],
                     },
      -rc_name    => $self->o('resource_class'),
      -analysis_capacity => 20,
    },
    {
      -logic_name => 'VariantDumpMerge',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpMerge',
      -parameters => { file_type => 'variants' },
      -flow_into  => {
                      1 =>
                        WHEN ('#gene_search_reformat#' =>
                          [
                            'ReformatVariantsEBeye',
                            'ReformatVariantsAdvancedSearch'
                          ],
                        ELSE ['ReformatVariantsEBeye',],
                      ),
                     },
    },
    {
      -logic_name => 'StructuralVariantDumpFactory',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
      -parameters => {
                      type   => 'variation',
                      table  => 'structural_variation',
                      column => 'structural_variation_id',
                      length => $self->o('variant_length')
                     },
      -flow_into  => {
                      '2->A' => 'DumpStructuralVariantJson',
                      'A->1' => 'StructuralVariantDumpMerge',
                     },
    },
    {
      -logic_name => 'DumpStructuralVariantJson',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpStructuralVariantJson',
      -flow_into  => {
                      2 => [
                        '?accu_name=dump_file&accu_address=[]',
                        '?accu_name=species'
                      ],
                     },
      -rc_name    => $self->o('resource_class'),
      -analysis_capacity => 10,
    },
    {
      -logic_name => 'StructuralVariantDumpMerge',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpMerge',
      -parameters => { file_type => 'structuralvariants' },
    },
    {
      -logic_name => 'DumpPhenotypesJson',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpPhenotypesJson',
      -analysis_capacity => 10,
    },
    {
      -logic_name => 'ProbeDumpFactory',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
      -parameters => {
                      type   => 'funcgen',
                      table  => 'probe',
                      column => 'probe_id',
                      length => $self->o('probe_length')
                     },
      -flow_into  => {
                      '2->A' => 'DumpProbeJson',
                      'A->1' => 'ProbeDumpMerge'
                     },
    },
    {
      -logic_name => 'RegulationDumpFactory',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
      -parameters => {
                      type   => 'funcgen',
                      table  => 'motif_feature',
                      column => 'motif_feature_id',
                      length => $self->o('regulatory_length') },
      -flow_into  => {
                      '2->A' => 'DumpRegulationJson',
                      'A->1' => 'RegulationDumpMerge'
                     },
    },
    {
      -logic_name => 'DumpProbeJson',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpProbesJson',
      -flow_into  => {
                      2 => [
                        '?accu_name=probes_dump_file&accu_address=[]',
                        '?accu_name=probesets_dump_file&accu_address=[]',
                        '?accu_name=species'
                      ],
                     },
      -rc_name    => $self->o('resource_class'),
      -analysis_capacity => 10,
    },
    {
      -logic_name => 'ProbeDumpMerge',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpProbesMerge',
      -flow_into  => {
                      2 => WHEN ('#gene_search_reformat#' => ['ReformatProbesAdvancedSearch']),
                      3 => WHEN ('#gene_search_reformat#' => ['ReformatProbesetsAdvancedSearch']),
                     },
    },
    {
      -logic_name => 'ReformatGenomeAdvancedSearch',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeAdvancedSearch',
      -analysis_capacity => 10,
    },
    {
      -logic_name => 'ReformatVariantsAdvancedSearch',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatVariantsAdvancedSearch',
    },
    {
      -logic_name => 'ReformatRegulationAdvancedSearch',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatRegulationAdvancedSearch',
    },
    {
      -logic_name => 'ReformatProbesAdvancedSearch',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatProbesAdvancedSearch',
    },
    {
      -logic_name => 'ReformatProbesetsAdvancedSearch',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatProbesetsAdvancedSearch',
    },
    {
      -logic_name => 'ReformatGenomeSolr',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeSolr',
    },
    {
      -logic_name => 'ReformatGenomeEBeye',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeEBeye',
      -flow_into  => 'ValidateXMLFileEBeye'
      -rc_name    => '4GB',
      -analysis_capacity => 10,
    },
    {
      -logic_name => 'ReformatVariantsSolr',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatVariantsSolr',
    },
    {
      -logic_name => 'ReformatVariantsEBeye',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatVariantsEBeye',
      -flow_into  => 'ValidateXMLFileVariantEBeye'
    },
    {
      -logic_name => 'ReformatStructuralVariantsSolr',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatStructuralVariantsSolr',
    },
    {
      -logic_name => 'ReformatPhenotypesSolr',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatPhenotypesSolr',
    },
    {
      -logic_name => 'ReformatProbesSolr',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatProbesSolr',
    },
    {
      -logic_name => 'ReformatProbeSetsSolr',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatProbeSetsSolr',
    },
    {
      -logic_name => 'ReformatRegulationSolr',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::ReformatRegulationSolr',
    }
  ];
}

sub resource_classes {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::resource_classes},
    '100GB' => {'LSF' => '-q production -M 100000 -R "rusage[mem=100000]"'},
  }
}

1;
