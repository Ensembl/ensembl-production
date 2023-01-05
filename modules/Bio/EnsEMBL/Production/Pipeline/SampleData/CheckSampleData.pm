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

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::SampleData::CheckSampleData

=head1 DESCRIPTION

Determine if we need to add sample data to the meta table.

For gene-related samples, mere presence of existing data is not enough
information to proceed - to enable tests on the staging site,
a placeholder might be used, which we want to replace with a 'better'
example post-handover, once we have xref and comparative data.
At the same time, some species will have manually curated examples
that we never want to overwrite.

For VEP samples, it's a bit simpler. If they exist, do nothing;
if not, generate them.

=cut

package Bio::EnsEMBL::Production::Pipeline::SampleData::CheckSampleData;

use strict;
use warnings;

use base('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    new_genesets_only => 1,
  };
}

sub run {
  my ($self) = @_;

  my $release = $self->param_required('release');
  my $species = $self->param_required('species');
  my $new_genesets_only = $self->param_required('new_genesets_only');

  my $dba = $self->core_dba();
  my $mca = $dba->get_adaptor('MetaContainer');

  my $generate = 0;
  if ($new_genesets_only) {
    my $division = $mca->get_division();
    my $mdba = $self->get_DBAdaptor('metadata');
    my $gia  = $mdba->get_GenomeInfoAdaptor();

    $gia->set_ensembl_release($release - 1);
    my $prev_genome;
    foreach ( @{ $gia->fetch_by_name($species) } ) {
      $prev_genome = $_ if ($_->division eq $division);
    }

    if (defined $prev_genome) {
      $gia->set_ensembl_release($release);
      my $genome;
      foreach ( @{ $gia->fetch_by_name($species) } ) {
        $genome = $_ if ($_->division eq $division);
      }

      if ($genome->genebuild ne $prev_genome->genebuild) {
        # Existing species, updated geneset
        $generate = 1;
      }
    } else {
      # New species, new geneset
      $generate = 1;
    }
    
    $mdba->dbc && $mdba->dbc->disconnect_if_idle();
  } else {
    $generate = 1;
  }
  $self->param('generate', $generate);

  my $gene_keep = $mca->single_value_by_key('sample.gene_keep') || 0;
  $self->param('gene_keep', $gene_keep);

  # VEP examples do not necessarily already exist; if they don't
  # the 'keep' status is irrelevant, we will want to add examples.
  my $vep_exists = $mca->single_value_by_key('sample.vep_ensembl');
  if (defined $vep_exists) {
    my $vep_keep = $mca->single_value_by_key('sample.vep_keep') || 0;
    $self->param('vep_keep', $vep_keep);
  } else {
    $self->param('vep_keep', 0);
  }

  $dba->dbc && $dba->dbc->disconnect_if_idle();
}

sub write_output {
  my ($self) = @_;

  my $species   = $self->param_required('species');
  my $generate  = $self->param_required('generate');
  my $gene_keep = $self->param_required('gene_keep');
  my $vep_keep  = $self->param_required('vep_keep');

  if ($generate) {
    if ($gene_keep) {
      $self->dataflow_output_id( {}, 3 );
    } else {
      $self->dataflow_output_id( {}, 4 );
    }
    if ($vep_keep) {
      $self->dataflow_output_id( {}, 5 );
    } else {
      $self->dataflow_output_id( {}, 6 );
    }
  }
}

1;
