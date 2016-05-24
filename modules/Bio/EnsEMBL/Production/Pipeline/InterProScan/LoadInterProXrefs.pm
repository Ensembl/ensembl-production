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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::LoadInterProXrefs;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR 

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::LoadInterProXrefs;

use strict;
use DBI;
use DBD::Oracle qw(:ora_types);
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreFeaturesBase');

sub fetch_input {
    my ($self) 	 = @_;
    my $core_dbh = $self->core_dbh;

    if (!exists $ENV{'ORACLE_HOME'}) {
   	$ENV{'ORACLE_HOME'} = $self->param_required('oracle_home');
    }

    # Connection to VIPREAD, to collect InterPro entries
    my $dsn   = 'DBI:Oracle:host=ora-dlvm5-018.ebi.ac.uk;sid=VIPREAD;port=1531';
    my $user  = 'proteomes_prod';
    my $pass  = 'pprod';
    my $dbh   = DBI->connect($dsn, $user, $pass, {PrintError => 1, RaiseError => 1}) or die "Cannot connect to server: " . DBI->errstr;
    my $sql   = "SELECT entry_ac, name, short_name FROM interpro.entry WHERE checked = 'Y'";
    my $stmt  = $dbh->prepare("$sql") or die "Couldn't prepare statement:" . $dbh->errstr;

    $self->param('core_dbh', $core_dbh);
    $self->param('stmt', $stmt);

return 0;
}

sub write_output {
    my ($self)  = @_;

return 0;
}

sub run {
    my ($self)   = @_;
    my ($interpro_accession, $interpro_description, $interpro_name);

    my $core_dbh       = $self->param('core_dbh');
    my $core_dba       = $self->core_dba;
    my $stmt           = $self->param('stmt'); 
    my $external_dbId  = $self->fetch_external_db_id($core_dbh, 'Interpro');

    $stmt->execute();

    while (my $result = $stmt->fetchrow_arrayref) {
      $interpro_accession   = $result->[0];
      $interpro_description = $result->[1];
      $interpro_name        = $result->[2]; 

      if (!$self->xref_exists($core_dbh,$interpro_accession,$external_dbId)){
         $self->insert_xref($core_dbh, {
            external_db_id => $external_dbId,
            dbprimary_acc  => $interpro_accession,
            display_label  => $interpro_name,
            description    => $interpro_description,
         });
     }
   }

   $core_dba->dbc->disconnect_if_idle();

return 0;
}

1;


