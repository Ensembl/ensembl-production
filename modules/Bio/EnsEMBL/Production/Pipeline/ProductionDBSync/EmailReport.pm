=head1 LICENSE
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
Bio::EnsEMBL::DataCheck::Pipeline::EmailReport

=head1 DESCRIPTION
Send an email with the overall result of the datachecks,
and links to output files, if they were created.

=cut

package Bio::EnsEMBL::Production::Pipeline::ProductionDBSync::EmailReport;

use strict;
use warnings;
use feature 'say';

use base ('Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail');

sub fetch_input {
  my $self = shift;

  my $pipeline_name = $self->param('pipeline_name');
  my $history_file  = $self->param('history_file');
  my $output_dir    = $self->param('output_dir');

  my $subject = "Production DB Sync pipeline completed ($pipeline_name)";
  $self->param('subject', $subject);

  my $text =
    "The $pipeline_name pipeline has completed successfully.\n\n".
    "Critical datachecks have passed, and separate emails ".
    "will have been sent about any advisory datacheck failures.\n\n";

  if (defined $history_file) {
    $text .= "The datacheck results were stored in a history file: $history_file.\n";
  } else {
    $text .= "The datacheck results were not stored in a history file.\n";
  }

  if (defined $output_dir) {
    $text .= "The datacheck output files were stored in: $output_dir.\n";
  } else {
    $text .= "The datacheck output files were not saved.\n";
  }

  $self->param('text', $text);
}

1;
