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

=cut

=head1 SYNOPSIS

=head1 DESCRIPTION

    Hive pipeline to load all required ontologies into a dedicated mysql database
    The pipeline will create a database named from current expected release number, load expected ontologies from OLS,
    Check and compute terms closure.

=head1 LICENSE

    Copyright [2016-2019] EMBL-European Bioinformatics Institute
    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
         http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

=head1 CONTACT

    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates

=cut


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::OLSLoadAll_conf;

use strict;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::OLSLoad_conf');
use warnings FATAL => 'all';

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        'wipe_all'   => 1,
        'ontologies'    => ['GO', 'SO', 'PATO', 'HP', 'VT', 'EFO', 'PO', 'EO', 'TO', 'CHEBI', 'PR', 'FYPO', 'PECO', 'BFO',
                          'BTO', 'CL', 'CMO', 'ECO', 'MOD', 'MP', 'OGMS', 'UO', 'MONDO', 'PHI']
    }
}

1;
