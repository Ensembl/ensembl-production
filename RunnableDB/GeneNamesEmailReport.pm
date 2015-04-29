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

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesEmailReport

=head1 DESCRIPTION

=head1 AUTHOR 

ckong

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesEmailReport;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EmailReport');

sub fetch_input {
    my ($self) = @_;

    my $email                  = $self->param_required('email');
    my $subject                = $self->param('subject') || "An automatic message from your pipeline";
    my $output_dir             = $self->param('output_dir');
    my $flag_store_projections = $self->param_required('flag_store_projections');
    my $flag_GeneNames         = $self->param('flag_GeneNames');
    my $flag_GeneDescr         = $self->param('flag_GeneDescr');
    my $species                = $self->param_required('species');

    my $reports;

    foreach my $sp (@$species){
       my $dba   = Bio::EnsEMBL::Registry->get_adaptor($sp, 'core', 'Gene');
       my $dbh   = $dba->dbc()->db_handle();

       if(!$flag_store_projections){
	  $reports .= "Pipeline was run with a flag to prevent storing anything in the database.\n";
       }
       else {
         $reports .= $self->info_type_summary($dbh, $sp) if($flag_GeneNames);
         $reports .= $self->geneDesc_summary($dbh, $sp)  if($flag_GeneDescr);
	 #if(!$flag_GeneDesc){
	 #   $reports .= $self->info_type_summary($dbh, $sp);
	 #}
	 #   $reports .= $self->geneDesc_summary($dbh, $sp);
      }
   }

   $reports   .= "\n$subject detail log file is available at $output_dir.\n";

   $self->param('text', $reports);
}

sub info_type_summary {
    my ($self, $dbh, $sp) = @_;

    my $sql = 'SELECT info_type,count(dbprimary_acc) as count_of_primary_acc 
                FROM gene g INNER JOIN xref x
                ON (g.display_xref_id=x.xref_id)
                GROUP BY info_type';

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $title   = "Summary of DB primary_acc, by info types: ($sp)";
    my $columns = $sth->{NAME};
    my $results = $sth->fetchall_arrayref();

return $self->format_table($title, $columns, $results);    
}

sub geneDesc_summary {
    my ($self, $dbh, $sp) = @_;

    my $sql = 'SELECT count(*) AS Total FROM gene WHERE description rlike "projected" OR description rlike "Projected"';

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $from_species = $self->param_required('source');

    my $title   = "Count of genes with projected gene description: (from $from_species to $sp)";
    my $columns = $sth->{NAME};
    my $results = $sth->fetchall_arrayref();

return $self->format_table($title, $columns, $results);
}


1;
