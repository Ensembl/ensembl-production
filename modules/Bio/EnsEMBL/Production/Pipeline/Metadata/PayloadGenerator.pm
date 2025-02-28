=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2025] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Metadata::PayloadGenerator;

use strict;
use warnings;
#use JSON;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub run {
    my ($self) = @_;
    my $species = $self->param_required('species');
    my $core_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
    my $core_dbc = $core_adaptor->dbc;
    my $user =  $core_dbc->user;
    my $password = $core_dbc->password;
    my $host = $core_dbc->host;
    my $port = $core_dbc->port;
    my $dbname = $core_dbc->dbname;

    my $comment = $self->param_required('comment');
    my $database_uri = 'mysql://'.$user.':'.$password.'@'.$host.':'.$port.'/'.$dbname;
    my $email = $self->param_required('email');
    my $metadata_uri = $self->param_required('metadata_uri');
    my $source = $self->param_required('source');
    my $timestamp = scalar(localtime);

    my $payload = '{
"id": 1,
"input": {
	"comment": "' . $comment . '",
	"database_uri": "' . $database_uri . '",
	"email": "' . $email . '",
	"metadata_uri": "' . $metadata_uri . '",
	"source": "' . $source . '",
	"timestamp": "' . $timestamp . '"},
"status": "complete"}';

    $self->dataflow_output_id({ payload => $payload }, 3);
}
1;