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


=pod

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_plants_conf

=head1 DESCRIPTION

Gene name and description projection

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_plants_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_conf');

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'exclude_species' => $self->o('antispecies')
    };
}


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options()},

        compara_division => 'plants',

        gene_name_source => [ 'TAIR_SYMBOL', 'UniProtKB/Swiss-Prot', 'Uniprot_gn' ],
        antispecies      => [ 'ciona_savignyi', 'homo_sapiens', 'caenorhabditis_elegans', 'drosophila_melanogaster', 'saccharomyces_cerevisiae' ],
        gd_config        => [
            {
                source      => 'arabidopsis_thaliana',
                taxons      => [ 'eudicotyledons' ],
                antispecies => [ 'arabidopsis_thaliana' ],
            },
            {
                source      => 'oryza_sativa',
                taxons      => [ 'Liliopsida' ],
                antispecies => [ 'oryza_sativa' ],
            },
            {
                source      => 'arabidopsis_thaliana',
                taxons      => [ 'Liliopsida' ],
                antispecies => [ 'oryza_sativa' ],
            },
            {
                source      => 'oryza_sativa',
                taxons      => [ 'eudicotyledons' ],
                antispecies => [ 'arabidopsis_thaliana' ],
            },
        ],
    };
}
1;
