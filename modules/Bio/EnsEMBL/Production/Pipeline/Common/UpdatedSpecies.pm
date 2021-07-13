
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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::Common::UpdatedSpecies;

=head1 DESCRIPTION

Parse json output report_genomes.pl script, in order to determine
a list of species which require processing.
For example, Fasta DNA files need to be created for species that
have new/updated assemblies or genesets, or have been renamed.

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::UpdatedSpecies;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use JSON;
use Path::Tiny;

sub write_output {
  my ($self) = @_;

  my $species = $self->param_required('species');
  my $report_json = $self->param_required('report_json');

  my %species_report;

  my $json = path($report_json)->slurp;
  my %report = %{ JSON->new->decode($json) };

  my $division = $self->core_dba->get_adaptor("MetaContainer")->get_division;
  $division = lc$division;
  $division =~ s/ensembl//;

  $species_report{new_genome} = exists $report{$division}{'new_genomes'}{$species} || 0;
  $species_report{updated_assembly} = exists $report{$division}{'updated_assemblies'}{$species} || 0;
  $species_report{updated_annotation} = exists $report{$division}{'updated_annotations'}{$species} || 0;
  $species_report{renamed_genome} = exists $report{$division}{'renamed_genomes'}{$species} || 0;

  $self->dataflow_output_id( \%species_report, 3 );
}

1;
