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

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::SampleData::CopySampleData

=head1 DESCRIPTION

Determine if we need to copy sample data to the meta table.

Due to the vagaries of overlapping releases, it's possible to
populate the server for release n+1 before running the pipeline
to generate sample data for release n. So that we're not constantly
generating sample data, we need to check for species that have the
same genebuild in the two releases, but missing or different sample
metadata values.

=cut

package Bio::EnsEMBL::Production::Pipeline::SampleData::CopySampleData;

use strict;
use warnings;

use base('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Bio::EnsEMBL::Utils::URI qw/parse_uri/;

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    gene_samples => [
                      'sample.gene_param',
                      'sample.gene_text',
                      'sample.transcript_param',
                      'sample.transcript_text',
                      'sample.location_param',
                      'sample.location_text',
                      'sample.search_text',
                    ],
    vep_samples  => [
                      'sample.vep_ensembl',
                      'sample.vep_hgvs',
                      'sample.vep_id',
                      'sample.vep_pileup',
                      'sample.vep_vcf',
                     ],
  };
}

sub run {
  my ($self) = @_;

  my $release = $self->param_required('release');
  my $species = $self->param_required('species');

  my $dba = $self->core_dba();
  my $mca = $dba->get_adaptor('MetaContainer');

  my $gene_keep = $mca->single_value_by_key('sample.gene_keep') || 0;

  # VEP examples do not necessarily already exist; if they don't
  # the 'keep' status is irrelevant, we will want to copy examples.
  my $vep_keep = 0;
  my $vep_exists = $mca->single_value_by_key('sample.vep_ensembl');
  if (defined $vep_exists) {
    $vep_keep = $mca->single_value_by_key('sample.vep_keep') || 0;
  }

  my $data_copied = 0;

  unless ($gene_keep and $vep_keep) {
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

      if ($genome->genebuild eq $prev_genome->genebuild) {
        # Only copy data if the genebuild matches.
        my @samples = ();
        if (! $gene_keep) {
          push @samples, @{ $self->param_required('gene_samples') };
        }
        if (! $vep_keep) {
          push @samples, @{ $self->param_required('vep_samples') };
        }
        $self->copy_sample_data($dba, $mca, $species, $prev_genome, \@samples);
        $data_copied = 1;
      }
    }

    $mdba->dbc && $mdba->dbc->disconnect_if_idle();
  }
  $self->param('data_copied', $data_copied);

  $dba->dbc && $dba->dbc->disconnect_if_idle();
}

sub write_output {
  my ($self) = @_;

  my $data_copied = $self->param_required('data_copied');

  if ($data_copied) {
    $self->dataflow_output_id( {}, 3 );
  }
}

sub copy_sample_data {
  my ($self, $dba, $mca, $species, $prev_genome, $samples) = @_;

  my $prev_server_url = $self->param_required('prev_server_url');

  # Need to jump through some hoops to get old and new DB
  # adaptors alongside each other in the registry...
  my $uri = parse_uri($prev_server_url);
  my %params = $uri->generate_dbsql_params();
  $params{'-DBNAME'}     = $prev_genome->dbname;
  $params{'-SPECIES_ID'} = $prev_genome->species_id;
  $params{'-SPECIES'}    = $species.'_prev';
  $params{'-GROUP'}      = $dba->group;
  if ($dba->is_multispecies) {
    $params{'-MULTISPECIES_DB'} = 1;
  }
  my $old_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%params);
  my $old_mca = $old_dba->get_adaptor('MetaContainer');

  foreach my $meta_key (@$samples) {
    my $meta_value = $old_mca->single_value_by_key($meta_key);
    if (defined $meta_value) {
      $mca->delete_key($meta_key);
      $mca->store_key_value($meta_key, $meta_value);
    }
  }

  $old_dba->dbc && $old_dba->dbc->disconnect_if_idle();
}

1;
