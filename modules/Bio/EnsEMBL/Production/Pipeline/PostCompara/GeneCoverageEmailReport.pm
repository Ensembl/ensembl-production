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

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneCoverageEmailReport

=head1 DESCRIPTION

=head1 AUTHOR 

ckong

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneCoverageEmailReport;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EmailReport');

sub fetch_input {
    my ($self) = @_;

    my $compara  = $self->param_required('compara');
    my $gdba     = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", "GenomeDB");
    my $all_gdbs = $gdba->fetch_all();
    my $reports;

    foreach my $gdb (@$all_gdbs){
       #next unless $gdb->name()=~/theobroma_cacao|vitis_vinifera/;
       my $ga         = Bio::EnsEMBL::Registry->get_adaptor($gdb->name(), 'core', 'Gene');
       my $dbh        = $ga->dbc()->db_handle();
       my $email      = $self->param('email')   || die "'email' parameter is obligatory";
       my $subject    = $self->param('subject') || "An automatic message from your pipeline";
       my $output_dir = $self->param('output_dir');
       $reports .= $self->info_type_summary($dbh, $ga->dbc());
    }
       $self->param('text', $reports);
}

sub info_type_summary {
    my ($self, $dbh, $dbc) = @_;

    my $sql = 'SELECT code, count(*) as count_of_gene_attrib
	        FROM gene_attrib 
                INNER JOIN attrib_type USING (attrib_type_id)
  		WHERE code in ("protein_coverage", "consensus_coverage") 
                GROUP BY code';

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $title   = "Summary of Gene attribs , by code: (".$dbc->dbname().")";
    my $columns = $sth->{NAME};
    my $results = $sth->fetchall_arrayref();

return $self->format_table($title, $columns, $results);    
}

1;
