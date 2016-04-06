=head1 LICENSE

Copyright [1999-2015] EMBL-European Bioinformatics Institute
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

=cut

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::EmailTranscriptomeReport;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EmailReport');

use MIME::Lite;
use Path::Tiny qw(path);

sub fetch_input {
  my ($self) = @_;
  my $fasta_file   = $self->param_required('fasta_file');
  my $xml_file     = $self->param_required('xml_file');
  my $tsv_file     = $self->param_required('tsv_file');
  my $solr_file    = $self->param_required('solr_file');
  my $with_domains = $self->param_required('with_domains');
  
  my ($transcripts, $total_bases) = $self->statistics($fasta_file);
  
  my $with_domains_pc = sprintf("%.1f", $with_domains * 100 / $transcripts);
  my $mean_length_kb = sprintf("%.1f", $total_bases / (1000 * $transcripts));
  my $total_bases_mb = sprintf("%.1f", $total_bases / (1000 * 1000));
  
  print '| '.join(' | ', $fasta_file, $transcripts, $total_bases_mb, $mean_length_kb, $with_domains_pc.'%')." |\n";
  
  my $text = "The InterProScan annotation is complete for the file '$fasta_file'.\n\n";
  $text .= "The file has $transcripts transcripts, and is ~$total_bases_mb Mb, giving a mean transcript length of ~$mean_length_kb Kb.\n\n";
  $text .= "$with_domains_pc% ($with_domains/$transcripts) of the transcripts have at least one protein domain.\n\n";
  $text .= "Result files are saved in the following locations.\n";
  $text .= "  XML format: $xml_file\n";
  $text .= "  TSV format: $tsv_file\n";
  $text .= "  SOLR format: $solr_file\n";
  
  $self->param('text', $text);
}

sub run {
  my ($self) = @_;
  my $email   = $self->param_required('email');
  my $subject = $self->param_required('subject');
  my $text    = $self->param_required('text');
  
  my $msg = MIME::Lite->new(
    From    => $email,
    To      => $email,
    Subject => $subject,
    Type    => 'multipart/mixed',
  );
  
  $msg->attach(
    Type => 'TEXT',
    Data => $text,
  );
  
  $msg->send;
}

sub statistics {
  my ($self, $fasta_file) = @_;
  
  my $file_obj = path($fasta_file);
  my $data = $file_obj->slurp;
  my $transcripts = () = $data =~ /^(>)/gm;
  
  $data =~ s/^>.*\n//gm;
  $data =~ s/\n//gm;
  my $total_bases = length($data);
  
  return ($transcripts, $total_bases);
}

1;
