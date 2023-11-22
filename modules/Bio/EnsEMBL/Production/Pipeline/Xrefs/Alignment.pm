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

=cut

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Xrefs::Alignment

=head1 DESCRIPTION

Configures and runs Exonerate according to the chunk parameters given to it

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::Alignment;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my $self = shift;

  my $max_chunks    = $self->param_required('max_chunks');
  my $chunk         = $self->param_required('chunk');
  my $source        = $self->param_required('source_file');
  my $target        = $self->param_required('target_file');
  my $seq_type      = $self->param_required('seq_type');
  my $method        = $self->param_required('align_method');
  my $query_cutoff  = $self->param_required('query_cutoff');
  my $target_cutoff = $self->param_required('target_cutoff');
  my $base_path     = $self->param_required('base_path');
  my $xref_url      = $self->param_required('xref_url');
  my $map_file      = $self->param_required('map_file');
  my $job_index     = $self->param_required('job_index');
  my $source_id     = $self->param_required('source_id');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();
  my ($user, $pass, $host, $port, $dbname) = $self->parse_url($xref_url);
  my $dbc = $self->get_dbc($host, $port, $user, $pass, $dbname);
  $dbc->disconnect_if_idle();
  my $job_sth = $dbc->prepare("insert into mapping_jobs (map_file, status, out_file, err_file, array_number, job_id) values (?,?,?,?,?,?)");
  my $mapping_sth = $dbc->prepare("insert into mapping (job_id, method, percent_query_cutoff, percent_target_cutoff) values (?,?,?,?)");

  my $out_file = "xref_".$seq_type.".".$max_chunks."-".$chunk.".out";
  my $job_id = $source_id . $job_index . $chunk;
  $job_sth->execute($map_file, 'SUBMITTED', $out_file, $out_file, $chunk, $job_id);
  $mapping_sth->execute($job_id, $seq_type, $query_cutoff, $target_cutoff);
  $job_sth->finish();
  $mapping_sth->finish();

  my $fh = IO::File->new($map_file, 'w') or throw("Couldn't open". $map_file ." for writing: $!\n");

  my $ryo = "xref:%qi:%ti:%ei:%ql:%tl:%qab:%qae:%tab:%tae:%C:%s\n";
  my $exe = `which exonerate`;
  $exe =~ s/\n//g;
  my $command_string = sprintf ("%s --showalignment FALSE --showvulgar FALSE --ryo '%s' --gappedextension FALSE --model 'affine:local' %s --subopt no --query %s --target %s --querychunktotal %s --querychunkid %s", $exe, $ryo, $method, $source, $target, $max_chunks, $chunk);
  my $output = `$command_string`;
  my @hits = grep {$_ =~ /^xref/} split "\n", $output; # not all lines in output are alignments

  while (my $hit = shift @hits) {
    print $fh $hit . "\n";
  }

  $fh->close();
}

1;
