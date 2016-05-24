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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::PrePipelineChecks;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::PrePipelineChecks;

use strict;
use Carp;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::Base');

sub run {
    my $self = shift @_;

    my $species              = $self->param('species')             || die "'species' is an obligatory parameter";
    my $required_analysis    = $self->param('required_analysis')   || die "'required_analysis' is an obligatory parameter";
    my $required_externalDb  = $self->param('required_externalDb') || die "'required_externalDb' is an obligatory parameter";

    my $all_checks_passed    = 1;
    my (@error_message, $entry_ok, $err_msg);
	    
    ($entry_ok, $err_msg) = $self->all_analyses_present({
	species           => $species,
	required_analysis => $required_analysis
    });

    if (!$entry_ok) {
	$all_checks_passed = 0;
	push @error_message, $err_msg
    }
    
    my ($entry_ok, $err_msg) = $self->one_external_db_entry_exists('Interpro');

    if (!$entry_ok) {
	$all_checks_passed = 0;
	push @error_message, $err_msg
    }

    foreach my $externalDb_name (@{$required_externalDb}) {
       my ($entry_ok, $err_msg) = $self->one_external_db_entry_exists($externalDb_name);

       if (!$entry_ok) {
         $all_checks_passed = 0;
         push @error_message, $err_msg;
       }
    }

    if (!$all_checks_passed) {
	my $pre_pipeline_check_warning
	    = "\n\n----- Pre pipeline checks failed ! ------\n\n"
	    . (join "\n", @error_message)
	    . "\n\n-----------------------------------------\n\n";

	$self->warning($pre_pipeline_check_warning);
	die($pre_pipeline_check_warning);
    }

    $self->dataflow_output_id({}, 1 );
}

sub all_analyses_present {
    my $self = shift;
    my $param = shift;

    my $species           = $param->{species};
    my $required_analysis = $param->{required_analysis};

    my @missing_analysis  = $self->find_missing_analyses({
	 species           => $species,
	 required_analysis => $required_analysis
    });
    
    my $err_msg;
    my $entry_ok = 1;

    if (@missing_analysis) {
	$entry_ok = 0;
	my @bulletpointed_missing_analyses = map { '    - ' . $_ } @missing_analysis;
    	$err_msg = 
    		"The following analyses are missing in the analysis table:\n\n"
    		. (join "\n", @bulletpointed_missing_analyses)
    		. "\n\nPlease add them to the "
    		. "core database "
    		. $self->core_database_string_for_user
    		. " before running this pipeline.\n\n"
		. "For a quick and dirty solution you can use the commands below. Note that these don't populate any columns other than logic_name and no entry to the analysis_description table is made.\n\n"
                ;

	my $mysql_cmd = $self->mysql_command_line_connect_do_db();

	my @sql;
 	foreach my $current_missing_analysis (@missing_analysis) {
	    push
		@sql,
		qq($mysql_cmd -e "INSERT INTO analysis (logic_name) VALUES('$current_missing_analysis');");
	}
	$err_msg .= "\n\n".(join "\n", @sql)."\n\n";
    }

return ($entry_ok, $err_msg);
}

sub find_missing_analyses {
    my $self  = shift;
    my $param = shift;

    my $species           = $param->{species};
    my $required_analysis = $param->{required_analysis};

    confess('Type error!') unless (ref $required_analysis eq 'ARRAY');
    my $analysis_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Analysis');
    my @missing_analysis;
    
    if (@$required_analysis==0) {
    	$self->warning("No required analysis were defined, not checking anything!");
    }
    
    foreach my $current_analysis (@$required_analysis) {
       my $current_logic_name = $current_analysis->{logic_name}; 
       my $analysis = $analysis_adaptor->fetch_by_logic_name($current_logic_name);
    	
       if (!defined $analysis || !$analysis->isa('Bio::EnsEMBL::Analysis')) {    		
      	  push @missing_analysis, $current_logic_name;    		
       }
   }

return @missing_analysis;
}

sub one_external_db_entry_exists {
    my ($self, $external_db_name) = @_;

    my $sql = "select * from external_db where db_name = ?;";
    my $ref = $self->core_dbh->selectall_arrayref($sql, {}, $external_db_name);
    my $err_msg;
    my $entry_ok = 1;

    if (@$ref>1) {
	$err_msg = "There is more than one ".$external_db_name." entry in the external_db table.";
	$entry_ok = 0;
    }
    if (@$ref<1) {
	$err_msg = "Missing an entry for ".$external_db_name." in the external_db table! This is necessary for the pipeline.";
	$entry_ok = 0;
    }

return ($entry_ok, $err_msg);
}

1;

