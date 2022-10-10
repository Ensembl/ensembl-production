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

=cut
package Bio::EnsEMBL::Production::Pipeline::Common::MetadataCSVersion;

use strict;
use warnings;

use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Registry;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub run {
    my ($self) = @_;
    # Parse filename to get $target_species
    my $species = $self->param('species');
    my $core_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
    my $mca = $core_adaptor->get_MetaContainer();
    my $cs_version = $mca->single_value_by_key('assembly.default');
    my $core_dbc = $core_adaptor->dbc;

    $self->dataflow_output_id({
        'core_dbhost' => $core_dbc->host,
        'core_dbname' => $core_dbc->dbname,
        'core_dbport' => $core_dbc->port,
        'core_dbuser' => $core_dbc->user,
        'core_dbpass' => $core_dbc->pass,
        'cs_version'  => $cs_version,
        'species'     => $species,
    },
        2
    );
}

1;
