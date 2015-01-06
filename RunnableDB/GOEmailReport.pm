=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOEmailReport

=head1 DESCRIPTION

=head1 AUTHOR 

ckong

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOEmailReport;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EmailReport');

sub fetch_input {
    my ($self) = @_;

    my $email      = $self->param('email')   || die "'email' parameter is obligatory";
    my $subject    = $self->param('subject') || "An automatic message from your pipeline";
    my $output_dir = $self->param('output_dir');
    my $species    = $self->param_required('species');
    my $reports;

    foreach my $s (@$species){
       my $ga    = Bio::EnsEMBL::Registry->get_adaptor($s, 'core', 'Gene');
       my $dbh   = $ga->dbc()->db_handle();
       $reports .= $self->linkage_type_summary($dbh, $ga);
       $reports .= $self->info_type_summary($dbh, $ga);
    }
    $reports   .= "\n$subject detail log file is available at $output_dir.\n";

    $self->param('text', $reports);
}

sub linkage_type_summary {
    my ($self, $dbh, $ga) = @_;

    my $sql = 'SELECT onx.linkage_type,count(dbprimary_acc) as count_of_GO_accession 
                FROM xref x 
                JOIN object_xref ox USING (xref_id) 
                JOIN ontology_xref onx USING (object_xref_id) 
                WHERE x.external_db_id=1000 
                GROUP BY onx.linkage_type';

#    my $sql = 'SELECT onx.linkage_type,count(*) as count_of_GO_accession 
#    		FROM xref x 
#    		JOIN object_xref ox USING (xref_id) 
#   		JOIN ontology_xref onx USING (object_xref_id) 
#    		WHERE x.external_db_id=1000 
#                GROUP BY onx.linkage_type';

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    
    my $title = "Summary of GO annotations, by linkage types: (".$ga->dbc()->dbname().")";
    my $columns = $sth->{NAME};
    my $results = $sth->fetchall_arrayref();

return $self->format_table($title, $columns, $results);
}

sub info_type_summary {
    my ($self, $dbh, $ga) = @_;

    my $sql = 'SELECT info_type,count(dbprimary_acc) as count_of_GO_accession 
                FROM xref x 
                JOIN object_xref ox USING (xref_id) 
                JOIN ontology_xref onx USING (object_xref_id) 
                WHERE x.external_db_id=1000 
                GROUP BY info_type';

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $title = "Summary of GO annotations, by info types: (".$ga->dbc()->dbname().")";
    my $columns = $sth->{NAME};
    my $results = $sth->fetchall_arrayref();

return $self->format_table($title, $columns, $results);    
}

1;
