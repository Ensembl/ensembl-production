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

=pod

=head1 NAME

Bio::EnsEMBL::RDF::Pipeline::PipeConfig::RDF_conf

=head1 DESCRIPTION

Simple pipeline to dump RDF for all core species. Needs a LOD mapping file to function,
and at least 100 GB of scratch space.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::SearchDumps_non_vert;
use strict;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
#use parent 'Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf';
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');
# use base ('Bio::EnsEMBL::Hive::PipeConfig::Base_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;

use Data::Dumper;

sub default_options {
    my $self = shift;
    return {
        %{$self->SUPER::default_options()},
        species         => [],
        division        => [],
        antispecies     => [],
        run_all         => 0, #always run every species
        use_pan_compara => 0, 
        variant_length  => 1000000,
        probe_length    => 100000,
        regulatory_length => 100000,
        dump_variant    => 0,
        dump_regulation => 0,
        release => software_version(),
        eg_release => $self->o('eg_release')
    };
}

# sub process_options {
#     warn Dumper(">>>>>>> In process_options");
#     return;
# }

sub pipeline_wide_parameters {
    my $self = shift;
    return { %{$self->SUPER::pipeline_wide_parameters()},
        base_path => $self->o('base_path')}; 
}

sub pipeline_analyses {
    my $self = shift;
    my @variant_analyses = $self->o('dump_variant') == 1 ? [ 'VariantDumpFactory', 'StructuralVariantDumpFactory', 'DumpPhenotypesJson' ] : [ 'DumpPhenotypesJson' ] ;
    my @regulation_analyses = $self->o('dump_regulation') == 1 ? [ 'RegulationDumpFactory', 'ProbeDumpFactory' ] : [ 'ProbeDumpFactory' ];
    
    return [
        {
            -logic_name => 'SpeciesFactory',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            -input_ids  => [ {} ], # required for automatic seeding
            -parameters => { species => $self->o('species'),
                antispecies          => $self->o('antispecies'),
                division             => $self->o('division'),
                run_all              => $self->o('run_all') },
            -rc_name    => '4g',
            -flow_into  => {
                        '2->A' => [ 'DumpGenomeJson' ],
                        'A->1' => [ 'WrapGenomeEBeye' ]
                        }
        },
        {
            -logic_name => 'WrapGenomeEBeye',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::WrapGenomeEBeye',
            -rc_name    => '1g',
            -parameters =>
                        {
                        division        => $self->o('division'),
                        release         => $self->o('eg_release'),
                        },
            #-flow_into  => 'CompressXML'
        },
        {
            -logic_name    => 'DumpGenomeJson',
            -module        =>
                'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenomeJson',
            -parameters    => {},
            -analysis_capacity => 10,
            -rc_name       => '1g',
            -flow_into     => {
                2 => [ 'DumpGenesJson' ],
                7 => [ 'DumpGenesJson' ],
                4 => @variant_analyses, 
                6 => @regulation_analyses,
            }
        },
        {
            -logic_name => 'ValidateXMLFileEBeye',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ValidateXMLFileEBeye',
            -rc_name    => '1g',
            -parameters =>
                        {
                        division        => $self->o('division'),
                        release         => $self->o('eg_release'),
                        },
            -flow_into  => 
                        {
                    1 => ['CompressEBeyeXMLFile'], 
                2 => [ '?accu_name=genome_files&accu_address={species}&accu_input_variable=genome_valid_file']
                        },
        },
        {
             -logic_name => 'CompressEBeyeXMLFile',
             -module =>
                'Bio::EnsEMBL::Production::Pipeline::Search::CompressEBeyeXMLFile',
             -parameters =>
                        {
                        division        => $self->o('division'),
                        release         => $self->o('eg_release'),
                        },
             -analysis_capacity => 4,
        },
        {
            -logic_name    => 'DumpGenesJson',
            -module        =>
                'Bio::EnsEMBL::Production::Pipeline::Search::DumpGenesJson',
            -parameters    => {
                use_pan_compara => $self->o('use_pan_compara')
            },
            -analysis_capacity => 10,
            -rc_name       => '32g',
            -flow_into     => {
                1 => [
                    'ReformatGenomeAdvancedSearch',
                    'ReformatGenomeSolr',
                    'ReformatGenomeEBeye'
                ]
            }
        },
        {
            -logic_name    => 'DumpRegulationJson',
            -module        =>
                'Bio::EnsEMBL::Production::Pipeline::Search::DumpRegulationJson',
            -parameters    => {},
            -analysis_capacity => 10,
            -rc_name       => '32g',
            -flow_into     => {
                2 => [
                    '?accu_name=motifs_dump_file&accu_address=[]',
                    '?accu_name=regulatory_features_dump_file&accu_address=[]',
                    '?accu_name=mirna_dump_file&accu_address=[]',
                    '?accu_name=external_features_dump_file&accu_address=[]',
                    '?accu_name=peaks_dump_file&accu_address=[]',
                    '?accu_name=transcription_factors_dump_file&accu_address=[]',
                    '?accu_name=species'
                ],
            }
        },
        {
            -logic_name => 'RegulationDumpMerge',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::DumpRegulationMerge',
            -rc_name    => '1g',
            -flow_into  =>
                {
                    2 => ['ReformatRegulationSolr','ReformatRegulationAdvancedSearch'],
                }
        },
        {
            -logic_name => 'VariantDumpFactory',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
            -parameters => {
                type   => 'variation',
                table  => 'variation',
                column => 'variation_id',
                length => $self->o('variant_length') },
            -rc_name    => '1g',
            -flow_into  =>
                { 
                '2->A' => 'DumpVariantJson', 
                'A->1' => 'VariantDumpMerge' 
            }
        },
        {
            -logic_name    => 'DumpVariantJson',
            -analysis_capacity => 20,
            -module        =>
                'Bio::EnsEMBL::Production::Pipeline::Search::DumpVariantJson',
            -rc_name       => '32g',
            -flow_into     => {
                2 => [
                    '?accu_name=dump_file&accu_address=[]',
                    '?accu_name=species'
                ],

            }
        },
        {
            -logic_name => 'VariantDumpMerge',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpMerge',
            -parameters => { file_type => 'variants' },
            -rc_name    => '1g',
            -flow_into  =>
                {
                    1 => [
                        'ReformatVariantsSolr',
                        'ReformatGenomeEBeye',
                        'ReformatVariantsEBeye',
                        'ReformatVariantsAdvancedSearch'
                    ]
                }
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
            -rc_name    => '1g',
            -flow_into  => {
                '2->A' => 'DumpStructuralVariantJson',
                'A->1' => 'StructuralVariantDumpMerge',
            }
        },
        {
            -logic_name    => 'DumpStructuralVariantJson',
            -analysis_capacity => 10,
            -module        =>
                'Bio::EnsEMBL::Production::Pipeline::Search::DumpStructuralVariantJson',
            -rc_name       => '32g',
            -flow_into     => {
                2 => [
                    '?accu_name=dump_file&accu_address=[]',
                    '?accu_name=species'
                ],

            }
        },
        {
            -logic_name => 'StructuralVariantDumpMerge',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpMerge',
            -parameters => { file_type => 'structuralvariants' },
            -rc_name    => '1g',
            -flow_into  => {
                1 => 'ReformatStructuralVariantsSolr' }
        },
        {
            -logic_name    => 'DumpPhenotypesJson',
            -module        =>
                'Bio::EnsEMBL::Production::Pipeline::Search::DumpPhenotypesJson',
            -parameters    => {},
            -analysis_capacity => 10,
            -rc_name       => '1g',
            -flow_into     => {
                2 => 'ReformatPhenotypesSolr'
            }
        },
        {
            -logic_name => 'ProbeDumpFactory',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
            -parameters => { type => 'funcgen',
                table             => 'probe',
                column            => 'probe_id',
                length            => $self->o('probe_length') },
            -rc_name    => '1g',
            -flow_into  =>
                {
                    '2->A' => 'DumpProbeJson', 'A->1' => 'ProbeDumpMerge'
                }
        },
        {
            -logic_name => 'RegulationDumpFactory',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory',
            -parameters => { type => 'funcgen',
                table             => 'motif_feature',
                column            => 'motif_feature_id',
                length            => $self->o('regulatory_length') },
            -rc_name    => '1g',
            -flow_into  =>
                {
                    '2->A' => 'DumpRegulationJson', 'A->1' => 'RegulationDumpMerge'
                }
        },
        {
            -logic_name    => 'DumpProbeJson',
            -analysis_capacity => 10,
            -module        =>
                'Bio::EnsEMBL::Production::Pipeline::Search::DumpProbesJson',
            -rc_name       => '32g',
            -flow_into     => {
                2 => [
                    '?accu_name=probes_dump_file&accu_address=[]',
                    '?accu_name=probesets_dump_file&accu_address=[]',
                    '?accu_name=species'
                ],
            }
        },
        {
            -logic_name => 'ProbeDumpMerge',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::DumpProbesMerge',
            -rc_name    => '1g',
            -flow_into  =>
                {
                    2 => ['ReformatProbesSolr','ReformatProbesAdvancedSearch'],
                    3 => ['ReformatProbeSetsSolr','ReformatProbesetsAdvancedSearch'],
                }
        },
        {
            -logic_name => 'ReformatGenomeAdvancedSearch',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeAdvancedSearch',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatVariantsAdvancedSearch',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatVariantsAdvancedSearch',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatRegulationAdvancedSearch',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatRegulationAdvancedSearch',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatProbesAdvancedSearch',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatProbesAdvancedSearch',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatProbesetsAdvancedSearch',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatProbesetsAdvancedSearch',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatGenomeSolr',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeSolr',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatGenomeEBeye',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeEBeye',
            -rc_name    => '1g',
            -flow_into  => 'ValidateXMLFileEBeye'
        },
        {
            -logic_name => 'ReformatVariantsSolr',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatVariantsSolr',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatVariantsEBeye',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatVariantsEBeye',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatStructuralVariantsSolr',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatStructuralVariantsSolr',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatPhenotypesSolr',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatPhenotypesSolr',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatProbesSolr',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatProbesSolr',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatProbeSetsSolr',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatProbeSetsSolr',
            -rc_name    => '1g',
            -flow_into  => {}
        },
        {
            -logic_name => 'ReformatRegulationSolr',
            -module     =>
                'Bio::EnsEMBL::Production::Pipeline::Search::ReformatRegulationSolr',
            -rc_name    => '1g',
            -flow_into  => {}
        }
    ];
} ## end sub pipeline_analyses

sub beekeeper_extra_cmdline_options {
    my $self = shift;
    return "-reg_conf " . $self->o("registry");
}

sub resource_classes {
    my $self = shift;
    return {
        '32g' => { LSF => '-q production-rh74 -M 32000 -R "rusage[mem=32000]"' },
        '16g' => { LSF => '-q production-rh74 -M 16000 -R "rusage[mem=16000]"' },
        '8g'  => { LSF => '-q production-rh74 -M 16000 -R "rusage[mem=8000]"' },
        '4g'  => { LSF => '-q production-rh74 -M 4000 -R "rusage[mem=4000]"' },
        '1g'  => { LSF => '-q production-rh74 -M 1000 -R "rusage[mem=1000]"' } };
}

1;
