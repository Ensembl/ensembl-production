=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::Xref_update_vertebrates_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Xref_update_conf');

sub default_options {
    my ($self) = @_;

    return {
           %{ $self->SUPER::default_options() },
           'division'    => ['EnsemblVertebrates'],
           'antispecies' => [qw/mus_musculus_129s1svimj mus_musculus_aj mus_musculus_akrj mus_musculus_balbcj mus_musculus_c3hhej mus_musculus_c57bl6nj mus_musculus_casteij mus_musculus_cbaj mus_musculus_dba2j mus_musculus_fvbnj mus_musculus_lpj mus_musculus_nodshiltj mus_musculus_nzohlltj mus_musculus_pwkphj mus_musculus_wsbeij drosophila_melanogaster caenorhabditis_elegans saccharomyces_cerevisiae/],
    };
}

1;
