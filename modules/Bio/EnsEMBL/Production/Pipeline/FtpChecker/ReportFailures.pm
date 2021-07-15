=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FtpChecker::ReportFailures;

use strict;
use warnings;

use base qw/
  Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail
  Bio::EnsEMBL::Production::Pipeline::Common::Base
/;

sub fetch_input {
  my $self = shift;

  my $pipeline_name = $self->param_required('pipeline_name');
  my $failures_file = $self->param_required('failures_file');

  my $subject = "ftp checker pipeline completed ($pipeline_name)";
  $self->param('subject', $subject);

  $self->write_failures_file($failures_file);

  my $text =
    "The $pipeline_name pipeline has completed successfully.\n\n".
    "Failures were stored in: $failures_file\n";

  if (-s $failures_file < 2e6) {
    push @{$self->param('attachments')}, $failures_file;
    $text .= "(File also attached to this email.)\n"
  } else {
    $text .= "(File not attached because it exceeds 2MB limit)";
  }

  $self->param('text', $text);
}

sub write_failures_file {
  my ($self, $file) = @_;

  open my $out, ">", $file || $self->throw("Could not open $file");
  my $n = 0;
  $self->hive_dbc()->sql_helper()->execute_no_return(
    -SQL      => q/select * from failures/,
    -CALLBACK => sub {
                      my $row = shift;
                      print $out join("\t", @$row);
                      print $out "\n";
                      $n++;
                      return;         
                     }                
  );
  close $out;
}

1;
