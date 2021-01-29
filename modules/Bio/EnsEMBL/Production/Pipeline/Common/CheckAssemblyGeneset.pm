
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

 Bio::EnsEMBL::Production::Pipeline::Common::CheckAssemblyGeneset;

=head1 DESCRIPTION

 Module to check if a species has an updated assembly or geneset for a given release
 The module uses the metadata database and compare given release with previous release

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::CheckAssemblyGeneset;

use strict;
use warnings;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use Bio::EnsEMBL::MetaData::Base qw(process_division_names fetch_and_set_release check_assembly_update check_genebuild_update);
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub write_output {
  my ($self) = @_;
  my $release = $self->param_required('release');
  my $species = $self->param_required('species');
  my $skip_metadata_check = $self->param('skip_metadata_check');
  my $metadatadba = Bio::EnsEMBL::Registry->get_DBAdaptor("multi", "metadata");
  my $gdba = $metadatadba->get_GenomeInfoAdaptor();
  my $rdba = $metadatadba->get_DataReleaseInfoAdaptor();
  my ($division,$division_name)=process_division_names($self->division());
  my $new_assembly = 0;
  my $new_genebuild = 0;
  if (!$skip_metadata_check){
    #Get the release
    my $release_info;
    ($rdba,$gdba,$release,$release_info) = fetch_and_set_release($release,$rdba,$gdba);
    # Get the genome for the given species, release and division
    my $genomes = $gdba->fetch_by_name($species);
    my $genome;
    foreach my $gen (@{$genomes}){
      $genome = $gen if ($gen->division() eq $division_name);
    }
    #Get the previous release
    if ($division eq "vertebrates") {
      my $prev_ens = $gdba->data_release()->ensembl_version()-1;
      $gdba->set_ensembl_release($prev_ens);
    } else {
      my $prev_eg = $gdba->data_release()->ensembl_genomes_version()-1;
      $gdba->set_ensembl_genomes_release($gdba->data_release()->ensembl_genomes_version()-1);
    }
    #Get the genome of the previous release for the given species and division
    my $prev_genomes = $gdba->fetch_by_name($species);
    my $prev_genome;
    foreach my $prev_gen (@{$prev_genomes}){
      $prev_genome = $prev_gen if ($prev_gen->division() eq $division_name);
    }
    $metadatadba->dbc()->disconnect_if_idle();

    # If can't find last release genome then it's a new species.
    if (!defined($prev_genome)){
      $new_assembly=1;
      $new_genebuild=1;
    }
    # Check if the assembly or genebuild has changed
    else{
      my $updated_assembly=check_assembly_update($genome,$prev_genome);
      my $updated_genebuild=check_genebuild_update($genome,$prev_genome);
      if ($updated_assembly) {
        $new_assembly=1;
      } elsif ($updated_genebuild) {
        $new_genebuild=1;
      }
    }
  }
  else{
    $new_assembly=1;
    $new_genebuild=1;
  }
  $self->dataflow_output_id( {species => $species,new_assembly => $new_assembly,new_genebuild =>$new_genebuild} );
}
1;