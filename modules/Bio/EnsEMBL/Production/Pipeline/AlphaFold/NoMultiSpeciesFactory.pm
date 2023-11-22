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

 Bio::EnsEMBL::Production::Pipeline::AlphaFold::NoMultiSpeciesFactory

=head1 DESCRIPTION

 This is a specialized Common::DbFactory.
 Same as the DbFactory db_flow, we usually have one dataflow per species, but
 for species in collection DBs, there is only one flow per DB.
 Additionally, for non-collections, it fetches the assembly name for the species
 and passes it along.

=cut

package Bio::EnsEMBL::Production::Pipeline::AlphaFold::NoMultiSpeciesFactory;

use strict;
use warnings;

use parent 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory';

sub write_output {
  my ($self) = @_;

  my $dbs          = $self->param_required('dbs');

  my @dbnames = keys %$dbs;
  foreach my $dbname ( @dbnames ) {
    my @species_list = keys %{ $$dbs{$dbname} };

    my $species = $species_list[0];
    my $core_adaptor = $$dbs{$dbname}{$species};

    my $cs_version;

    # Fetch the cs_version (coordinate_system / assembly name and
    # version) for single species DBs. Ignore, if it's a collection DB.
    # This is used to query GIFTS later and there is no data for species in
    # collection DBs in GIFTS
    if (scalar @species_list == 1) {
        my $mca = $core_adaptor->get_MetaContainer();
        $cs_version = $mca->single_value_by_key('assembly.default');
    } else {
        $cs_version = undef;
    }

    my $dataflow_params = {
        'dbname'       => $dbname,
        'species_list' => \@species_list,
        'species'      => $species,
        'cs_version'   => $cs_version,
    };

    $self->dataflow_output_id($dataflow_params, 2);
  }
}

1;
