=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::EmailNotification;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
	  'Bio::EnsEMBL::Production::Pipeline::Xrefs::Base');

sub fetch_input {
  my ($self) = @_;
  my $pipeline_part = $self->param_required('pipeline_part');
  my $db_url = $self->param('db_url');
  my $base_path = $self->param('base_path');
  my $clean_files  = $self->param('clean_files');

  # Start with stats about hive
  $self->dbc()->disconnect_if_idle() if defined $self->dbc();
  my $msg = "The Xref ".ucfirst($pipeline_part)." pipeline has completed its run.<br><br>\n".
  	"## eHive Info ##<br><br>\n";

  my $hive_dbi = $self->dbc;
  my $hive_sth = $hive_dbi->prepare("select analysis_id, status, total_job_count, done_job_count, failed_job_count from analysis_stats");
  $hive_sth->execute;

  # Get totals for analyses and jobs
  my ($total_analyses, $done_analyses, $failed_analyses) = (0, 0, 0);
  my ($total_jobs, $done_jobs, $failed_jobs) = (0, 0, 0);
  while (my $analysis = $hive_sth->fetchrow_hashref()) {
  	$total_analyses++;

  	my $status = $analysis->{'status'};
    if ($status eq 'FAILED') {$failed_analyses++;}
    else {$done_analyses++;}

  	$total_jobs += $analysis->{'total_job_count'};
  	$done_jobs += $analysis->{'done_job_count'};
  	$failed_jobs += $analysis->{'failed_job_count'};
  }

  # Adding current job (this assumes it suceeds)
  $done_jobs++;

  $msg .= "<b>Analyses</b><br>\n";
  $msg .= "\tTotal: ".$total_analyses."<br>\n";
  $msg .= "\tSuccessful: ".$done_analyses."<br>\n";
  $msg .= "\tFailed: ".$failed_analyses."<br>\n";
  $msg .= "<b>Jobs</b><br>\n";
  $msg .= "\tTotal: ".$total_jobs."<br>\n";
  $msg .= "\tSuccessful: ".$done_jobs."<br>\n";
  $msg .= "\tFailed: ".$failed_jobs."<br>\n";

  # Get error totals
  my ($pipeline_errors, $worker_errors) = (0, 0, 0);
  $hive_sth = $hive_dbi->prepare("select
    count(case when message_class='PIPELINE_ERROR' then 1 end) as pipeline_error_count,
    count(case when message_class='WORKER_ERROR' then 1 end) as worker_error_count
  	from log_message;");
  $hive_sth->execute;
  my $counts = $hive_sth->fetchrow_hashref();
  $pipeline_errors = $counts->{'pipeline_error_count'};
  $worker_errors = $counts->{'worker_error_count'};

  $msg .= "<b>Errors</b><br>\n";
  $msg .= "\tTotal: ".($pipeline_errors + $worker_errors)."<br>\n";
  $msg .= "\tPipeline errors: ".$pipeline_errors."<br>\n";
  $msg .= "\tWorker errors: ".$worker_errors."<br>\n";

  $msg .= "<br>## Pipeline Info ##<br><br>\n";

  # Different pipeline info depending on pipeline type (downlaod or process)
  if ($pipeline_part eq 'download') {
    my ($user, $pass, $host, $port, $source_db) = $self->parse_url($db_url);
    my $dbi = $self->get_dbi($host, $port, $user, $pass, $source_db);

    my $total_sources = 0;
    my $temp_msg = '';

    # Get names and number of downlaoded sources
    my $sources_sth = $dbi->prepare("select name from source order by source_id");
    $sources_sth->execute;

    $temp_msg .= "<ul>\n";
    while (my $source = $sources_sth->fetchrow_hashref()) {
      $temp_msg .= "<li>".$source->{'name'}."</li>\n";
      $total_sources++;
    }
    $temp_msg .= "</ul>\n";

    $msg .= "Files successfully downloaded from a total of ".$total_sources." sources:<br>\n".
      $temp_msg;

    # Get names and number of cleaned up sources
    if ($clean_files) {
      my $clean_files_directory = $base_path."/clean_files";
      my @sources = `ls $clean_files_directory`;

      $msg .= "<br>Files successfully cleaned up from a total of ".scalar(@sources)." sources:<br>\n".
        "<ul>\n";
      foreach my $source (@sources) {
        $msg .= "<li>".$source."</li>\n";
      }
      $msg .= "</ul>\n";
    }

    # Adding some parameters that can be used in next pipeline (process)
    $msg .= "<br>Useful parameters to use in Xref Process pipeline:<br>\n";
    $msg .= "<b>-base_path</b> ".$base_path."<br>\n";
    $msg .= "<b>-source_url</b> ".$db_url;

    my $skip_preparse = $self->param('skip_preparse');
    if (!$skip_preparse) {
      $msg .= "<br>\n";
      $msg .= "<b>-source_xref</b> ".$self->param('source_xref');
    }
  } elsif ($pipeline_part eq 'process') {
    my $total_species = 0;
    my $temp_msg = '';

    # Get names of species updated
    my $species_sth = $hive_dbi->prepare("SELECT species_name FROM updated_species ORDER BY species_name");
    $species_sth->execute;

    $temp_msg .= "<ul>\n";
    while (my $species_name = $species_sth->fetchrow()) {
      $temp_msg .= "<li>".$species_name."</li>\n";
      $total_species++;
    }
    $temp_msg .= "</ul>\n";

    $msg .= "A total of ".$total_species." species were successfully updated:<br>\n".
      $temp_msg;
  }

  $self->param('text', $msg);
  $self->param('is_html', 1);

  return;
}

1;
