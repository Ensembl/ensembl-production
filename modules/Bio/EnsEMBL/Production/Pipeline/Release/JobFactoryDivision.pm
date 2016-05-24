=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::Release::JobFactoryDivision;

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::Release::JobFactoryDivision;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base('Bio::EnsEMBL::Production::Pipeline::Base');

sub fetch_input {
    my ($self) 	= @_;

return 0;
}

sub run {
    my ($self) = @_;

return 0;
}

sub write_output {
    my ($self)  = @_;

    my $sql_get_dbs  = q/SELECT db_name 
			 FROM division JOIN division_db USING (division_id) 
			 WHERE shortname=? and is_current=1/;

    my $division     = $self->param_required('division'),
    my %prod_db      = %{$self->param_required('prod_db')};
    my $dba          = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%prod_db);
    my $sql_helper   = $dba->dbc()->sql_helper();

    $sql_helper->execute_no_return(
          -SQL      => $sql_get_dbs,
          -PARAMS   => [$division],
          -CALLBACK => sub {
                my ($db ) = @{ shift @_ };

                $self->dataflow_output_id({ 'db' => $db },2) if ($db=~/^.+/);
          }
    );

return 0;
}

1;


