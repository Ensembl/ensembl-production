=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::GPAD::GPADEmailReport;

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::GPAD::GPADEmailReport;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::EmailReport');

sub fetch_input {
    my ($self) = @_;

    my $email                  = $self->param('email')   || die "'email' parameter is obligatory";
    my $subject                = $self->param('subject') || "An automatic message from your pipeline";
    my $output_dir             = $self->param('output_dir');
    #my $to_species             = $self->param_required('species');
    my $reports;

    #foreach my $sp (@$to_species){
    #   my $ga    = Bio::EnsEMBL::Registry->get_adaptor($sp, 'core', 'Gene');
    #   my $dbh   = $ga->dbc()->db_handle();

    #   $reports .= $self->info_type_summary($dbh, $ga, $sp);
    #   $reports .= $self->analysis_type_summary($dbh, $ga, $sp); 
    $reports   .= "\n$subject detail log file is available at $output_dir.\n";

    $self->param('text', $reports);
}

sub info_type_summary {
    my ($self, $dbh, $ga, $sp) = @_;

    my $sql = 'SELECT info_type,count(dbprimary_acc) as count_of_GO_accession 
                FROM xref x 
                JOIN object_xref ox USING (xref_id) 
                JOIN ontology_xref onx USING (object_xref_id) 
                WHERE x.external_db_id=1000 
                GROUP BY info_type';

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $from_species = $self->param_required('source');
    my $title        = "Summary of GO annotations, by info types: (projected from $from_species to $sp)";
    my $columns      = $sth->{NAME};
    my $results      = $sth->fetchall_arrayref();

return $self->format_table($title, $columns, $results);
}

sub analysis_type_summary {
    my ($self, $dbh, $ga, $sp) = @_;

    my $sql = 'SELECT a.logic_name,count(dbprimary_acc) as count_of_GO_accession 
                FROM xref x 
                JOIN object_xref ox USING (xref_id) 
                JOIN ontology_xref onx USING (object_xref_id) 
		JOIN analysis a USING (analysis_id)
                WHERE x.external_db_id=1000 
                GROUP BY ox.analysis_id';

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $from_species = $self->param_required('source');
    my $title        = "Summary of GO annotations, by analysis types: (projected from $from_species to $sp)";
    my $columns      = $sth->{NAME};
    my $results      = $sth->fetchall_arrayref();

return $self->format_table($title, $columns, $results);    
}

sub write_output {
    my $self = shift @_;

#    my $projection_list = $self->param('projection_list');

#    if (keys %{$projection_list}){
#      1;
#    }
#    else
#    {
#      $self->input_job->autoflow(0);
#    }
}

1;
