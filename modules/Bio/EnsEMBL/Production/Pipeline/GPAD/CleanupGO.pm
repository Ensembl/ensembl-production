=head1 LICENSE

Copyright [2009-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::GPAD::CleanupGO;

=head1 DESCRIPTION

=head1 AUTHOR

maurel@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::GPAD::CleanupGO;

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use base qw/Bio::EnsEMBL::Production::Pipeline::GPAD::Base/;

sub param_defaults {
    return {
     delete_existing => 1,
    };
}

sub run {
    my ($self)  = @_;
    # Parse filename to get $target_species
    my $file    = $self->param_required('gpad_file');
    my $species = $self->param_required('species');
    my $hive_dbc = $self->dbc;
    $hive_dbc->disconnect_if_idle() if defined $self->dbc;

    $self->log()->info("Loading $species from $file");

    my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $species, 'core' );

    # Remove existing projected GO annotations from GOA
    if ($self->param_required('delete_existing')) {
      $self->cleanup_GO($dba);
    }

    $dba->dbc->disconnect_if_idle();
    $self->dataflow_output_id( { 'gpad_file' => $file, 'species' => $species }, 2);
  
    return;
  }

1;