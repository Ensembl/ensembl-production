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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::FileDumpCore_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::FileDump_conf');

sub default_options {
	my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    genome_types => [
      'Assembly_Chain',
      'Chromosome_TSV',
      'Genome_FASTA',
    ],
    geneset_types => [
      'Geneset_EMBL',
      'Geneset_FASTA',
      'Geneset_GFF3',
      'Geneset_GTF',
      'Xref_TSV',
    ],
    rnaseq_types => [
      'RNASeq_Exists',
    ],

    dump_metadata => 1,

    blast_index => 1,
	};
}

1;
