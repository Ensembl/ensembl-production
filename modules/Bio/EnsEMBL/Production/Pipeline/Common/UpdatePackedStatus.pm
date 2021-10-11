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

Bio::EnsEMBL::Production::Pipeline::Common::UpdatePackedStatus

=head1 DESCRIPTION

In the metadata db we can track when species have been packed for website
display - packing can be time-consuming, and so it is useful to avoid
doing it unnecessarily. Some pipelines make changes that necessitate
repacking, so we need to be able to update the metadata db so that the
changes trigger a repack. Which is what this module does.

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::UpdatePackedStatus;

use strict;
use warnings;

use base('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    packed => 1,
  };
}

sub run {
  my ($self) = @_;

  my $metadata_host     = $self->param_required('metadata_host');
  my $metadata_port     = $self->param_required('metadata_port');
  my $metadata_user     = $self->param_required('metadata_user');
  my $metadata_pass     = $self->param_required('metadata_pass');
  my $metadata_dbname   = $self->param_required('metadata_dbname');
  my $species           = $self->param_required('species');
  my $packed            = $self->param_required('packed');
  my $ensembl_release   = $self->param('ensembl_release');
  my $secondary_release = $self->param('secondary_release');

  my $mdba = Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(
    -host    => $metadata_host,
    -port    => $metadata_port,
    -user    => $metadata_user,
    -pass    => $metadata_pass,
    -dbname  => $metadata_dbname,
    -species => 'multi',
    -group   => 'metadata',
  );
  my $gia  = $mdba->get_GenomeInfoAdaptor();

  if (defined $secondary_release) {
    $gia->set_ensembl_genomes_release($secondary_release);
  } elsif (defined $ensembl_release) {
    $gia->set_ensembl_release($ensembl_release);
  }

  foreach ( @{ $gia->fetch_by_name($species) } ) {
    $gia->update_website_packed($_, $packed);
  }
}

1;

