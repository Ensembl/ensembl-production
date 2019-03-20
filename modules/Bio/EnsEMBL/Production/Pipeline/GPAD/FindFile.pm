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

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::GPAD::FindFile;

=head1 DESCRIPTION

=head1 AUTHOR

maurel@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::GPAD::FindFile;

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub run {
    my ($self)  = @_;
    # Parse filename to get $target_species
    my $species = $self->param_required('species');

    my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $species, 'core' );
    my $hive_dbc = $self->dbc;
    $hive_dbc->disconnect_if_idle() if defined $self->dbc;
    my $division = $dba->get_MetaContainer->get_division();
    $division =~ s/Ensembl//;
    $division = lc($division);
    my $file = $self->param_required('gpad_directory').'/ensembl'.$division.'/annotations_ensembl-'.$species.'.gpa';

    if (-e $file){
      $self->log()->info("Found $file for $species");
      $self->dataflow_output_id( { 'gpad_file' => $file, 'species' => $species }, 2);      
    }
    else{
      $self->log()->info("Cannot find $file for $species");
    }
    $dba->dbc->disconnect_if_idle();
    
    return;
  }

1;
