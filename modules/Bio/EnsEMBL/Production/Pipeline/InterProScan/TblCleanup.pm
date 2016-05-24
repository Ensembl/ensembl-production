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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::TblCleanup;

=head1 DESCRIPTION

  This module will
  - truncate 'interpro' table
  - cleanup orphan records in dependent_xref & ontology_xref tables
  - modify 'dbprimary_acc' column in 'xref' table if required 

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::TblCleanup;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::Base');

my ($analysis_string);

sub fetch_input {
    my ($self) 	= @_;

    my $sql_trunc_interpro  = 'TRUNCATE TABLE interpro';

    # Cleanup orphan records in dependent_xref & ontology_xref tables.
    #  Their corresponding object_xref records should have been deleted
    #  during 'Analysis_Setup' analysis
    my $sql_del_xref  = 'DELETE dx.* FROM dependent_xref dx 
		        LEFT JOIN object_xref ox USING (object_xref_id)
		        WHERE ox.object_xref_id IS NULL';

    my $sql_del_xref2 = 'DELETE onx.* FROM ontology_xref onx 
		         LEFT JOIN object_xref ox USING (object_xref_id)
		         WHERE ox.object_xref_id IS NULL';

    # Query to remove duplicates interpro_xrefs 
    my $sql_del_xref3 = 'DELETE FROM xref WHERE external_db_id=1200 AND info_text LIKE "%interpro%"';

    # Query to check dbprimary_acc type before deciding to alter the column size
    my $sql_check_xrefTbl = 'DESCRIBE xref dbprimary_acc';
    
    # Query to alter dbprimary_acc for xref table to cater for long KEGG_id
    my $sql_alter_xrefTbl = 'ALTER TABLE xref MODIFY dbprimary_acc varchar(128)';

    $self->param('sql_trunc_interpro',  $sql_trunc_interpro);
    $self->param('sql_del_xref',  $sql_del_xref);
    $self->param('sql_del_xref2', $sql_del_xref2);
    $self->param('sql_del_xref3', $sql_del_xref3);
    $self->param('sql_check_xrefTbl', $sql_check_xrefTbl);
    $self->param('sql_alter_xrefTbl', $sql_alter_xrefTbl);

return 0;
}

sub write_output {
    my ($self)  = @_;

    $self->dataflow_output_id({}, 1 );

return 0;
}

sub run {
    my ($self)       = @_;

    my $helper = Bio::EnsEMBL::Utils::SqlHelper->new( -DB_CONNECTION => $self->core_dbc() );

    my $sql_trunc_interpro = $self->param_required('sql_trunc_interpro');
    my $sql_del_xref       = $self->param_required('sql_del_xref');
    my $sql_del_xref2      = $self->param_required('sql_del_xref2');
    my $sql_del_xref3      = $self->param_required('sql_del_xref3');
    my $sql_check_xrefTbl  = $self->param_required('sql_check_xrefTbl');
    my $sql_alter_xrefTbl  = $self->param_required('sql_alter_xrefTbl');

    $helper->execute_update(-SQL => $sql_trunc_interpro);
    $helper->execute_update(-SQL => $sql_del_xref);
    $helper->execute_update(-SQL => $sql_del_xref2);
    $helper->execute_update(-SQL => $sql_del_xref3);

    # Alter xref.dbprimary_acc column size only if 
    # current size is < 128
    my $hash_ref = $helper->execute_into_hash(-SQL => $sql_check_xrefTbl);
    my $col_type = $hash_ref->{'dbprimary_acc'}; # varchar(128);
    my $col_size = $1 if($col_type=~/.+\((\d.+)\)/);
    $helper->execute_update(-SQL => $sql_alter_xrefTbl)if($col_size < 128);

    $self->core_dbc()->disconnect_if_idle();
    
return 0;
}



1;


