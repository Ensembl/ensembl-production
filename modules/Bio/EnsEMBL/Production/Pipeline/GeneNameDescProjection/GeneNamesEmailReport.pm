=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::GeneNamesEmailReport

=head1 DESCRIPTION

=head1 AUTHOR 

ckong

=cut
package Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::GeneNamesEmailReport;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::EmailReport');

sub fetch_input {
    my ($self) = @_;

    my $email                  = $self->param_required('email');
    my $subject                = $self->param('subject') || "An automatic message from your pipeline";
    my $output_dir             = $self->param('output_dir');
    my $flag_store_projections = $self->param_required('flag_store_projections');
    my $flag_GeneNames         = $self->param('flag_GeneNames');
    my $flag_GeneDescr         = $self->param('flag_GeneDescr');
    my $species                = $self->param('species');
    my $project_xrefs            = $self->param('project_xrefs');
    my $reports;

    foreach my $sp (@$species){
       my $dba   = Bio::EnsEMBL::Registry->get_adaptor($sp, 'core', 'Gene');
       my $dbh   = $dba->dbc()->db_handle();

       if(!$flag_store_projections){
	  $reports .= "Pipeline was run with a flag to prevent storing anything in the database.\n";
       }
       else {
         $reports .= $self->info_type_summary($dbh, $sp) if($flag_GeneNames);
         $reports .= $self->xref_type_summary($dbh, $sp) if($flag_GeneNames);
         $reports .= $self->geneDesc_summary($dbh, $sp)  if($flag_GeneDescr);
         $reports .= $self->info_type_summary_project_xrefs_xref($dbh, $sp) if ($flag_GeneNames and $project_xrefs)
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

    my $title   = "Summary of DB primary_acc display_xref projected, by info types: ($sp)";
    my $columns = $sth->{NAME};
    my $results = $sth->fetchall_arrayref();

return $self->format_table($title, $columns, $results);    
}

sub info_type_summary_project_xrefs_xref {
    my ($self, $dbh, $sp) = @_;

    my $sql = 'select distinct(db_name), count(*) 
                from xref LEFT JOIN external_db USING (external_db_id) 
                where info_type="PROJECTION" 
                group by db_name';

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $title   = "Summary of xref projected to $sp";
    my $columns = $sth->{NAME};
    my $results = $sth->fetchall_arrayref();

return $self->format_table($title, $columns, $results);    
}

sub xref_type_summary {
    my ($self, $dbh, $sp) = @_;

    my $sql = 'SELECT count(*),db_name 
                FROM gene LEFT JOIN xref ON display_xref_id = xref_id 
                LEFT JOIN external_db USING(external_db_id) 
                WHERE xref.info_type = "PROJECTION" group by db_name';

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $title   = "Summary of xref display_xref projected, by xref source: ($sp)";
    my $columns = $sth->{NAME};
    my $results = $sth->fetchall_arrayref();

return $self->format_table($title, $columns, $results);    
}

sub geneDesc_summary {
    my ($self, $dbh, $sp) = @_;

    my $sql = 'SELECT count(*) FROM gene LEFT JOIN xref ON display_xref_id = xref_id LEFT JOIN external_db USING(external_db_id) WHERE xref.info_type = "PROJECTION" and gene.description is not null';

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $from_species = $self->param_required('source');

    my $title   = "Count of genes with projected gene description: (from $from_species to $sp)";
    my $columns = $sth->{NAME};
    my $results = $sth->fetchall_arrayref();

return $self->format_table($title, $columns, $results);
}

sub write_output {
    my $self = shift @_;

    my $projection_list = $self->param('projection_list');

    if (keys %{$projection_list}){
      1;
    }
    else
    {
      $self->input_job->autoflow(0);
    }
}


1;
