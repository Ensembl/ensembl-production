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
limitations under the License.

=head1 NAME
Bio::EnsEMBL::Production::Pipeline::FileDump::RNASeq_Missing

=head1 DESCRIPTION
Send an email listing missing rnaseq files.

=cut

package Bio::EnsEMBL::Production::Pipeline::FileDump::RNASeq_Missing;

use strict;
use warnings;
use feature 'say';

use base ('Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail');

sub fetch_input {
  my ($self) = @_;

  my $missing = $self->param_required('missing');
  my $rnaseq_db = $self->param_required('rnaseq_db');

  my $subject = "Missing rnaseq files ($rnaseq_db)";
  $self->param('subject', $subject);

  my $text =
    "The Rapid Release file dumping pipeline could not find the ".
    "files below, which are expected based on the data in the ".
    "$rnaseq_db database. Please copy the files to these ".
    "locations, or amend the data in the rnaseq database. The ".
    "files will be synchronised the next time the file dumping ".
    "pipeline is run.\n\n";
  $text .= "Missing files:\n" . join("\n", @$missing);

  $self->param('text', $text);
}

1;
