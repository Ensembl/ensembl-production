=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License..

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::EmailAdvisoryXrefReport;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
          'Bio::EnsEMBL::Production::Pipeline::Xrefs::Base');

sub fetch_input {
  my ($self) = @_;

  my $pipeline_name = $self->param('pipeline_name');
  my $base_path     = $self->param('base_path');

  my %reports;
  my $msg;
  my $reports_failure = 0;

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();
  my $hive_dbi = $self->dbc;

  # Get DC report parameters from hive db
  my $hive_sth = $hive_dbi->prepare("SELECT db_name,datacheck_name,datacheck_output FROM advisory_dc_report");
  $hive_sth->execute;
  while (my $report = $hive_sth->fetchrow_hashref()) {
    $reports_failure = 1;
    $reports{$report->{'db_name'}}{$report->{'datacheck_name'}} = $report->{'datacheck_output'};
  }

  # Construct email report
  if ($reports_failure) {
    my $failures_file = $base_path."/dc_report_".$pipeline_name."_".time().".txt";
    open(my $out_fh, ">", $failures_file) || $self->throw("Could not open $failures_file");

    $msg = "Some advisory datachecks have failed for the following species in the xref pipeline run ($pipeline_name).<br>\n";
    $msg .= "<ul>\n";
      while (my ($db_name, $dc_values) = each %reports) {
        print $out_fh "\nFor $db_name\n\n";
        $msg .= "<li>".substr($db_name, 0, index($db_name, '_core_'))."</li>\n";

        while (my ($dc_name, $dc_output) = each %{$dc_values}) {
          print $out_fh "Datacheck $dc_name failed. See full output below:\n";
          print $out_fh $dc_output."\n\n";
        }
      }
    $msg .= "</ul>\n";
    $msg .= "DC failures details attached in this email\n";

    close($out_fh);

    push @{$self->param('attachments')}, $failures_file;
  } else {
    $msg = "Advisory datachecks have all succeeded for all species in the xref pipeline run ($pipeline_name).<br><br>\n";
  }

  $self->param('subject', "Advisory DC Report");
  $self->param('text', $msg);
  $self->param('is_html', 1);
}

1;

