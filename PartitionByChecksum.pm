=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::PartitionByChecksum;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

use Bio::SeqIO;
use DBI qw(:sql_types);
use Digest::MD5 qw(md5_hex);
use File::Basename qw(dirname fileparse);
use File::Path qw(make_path);

sub fetch_input {
  my ($self) = @_;
  
  my $fasta_file = $self->param_required('fasta_file');
  my $out_dir    = $self->param('out_dir');
  
  if (!-e $fasta_file) {
    $self->throw("Fasta file '$fasta_file' does not exist");
  }
  
  if (!defined $out_dir) {
    $out_dir = dirname($fasta_file);
    $self->param('out_dir', $out_dir);
  } else {
    if (!-e $out_dir) {
      $self->warning("Output directory '$out_dir' does not exist. I shall create it.");
      make_path($out_dir) or $self->throw("Failed to create output directory '$out_dir'");
    }
  }
}

sub run {
  my ($self) = @_;
  
  my $fasta_file = $self->param_required('fasta_file');
  my $out_dir    = $self->param('out_dir');
  
  my ($basename, undef, undef) = fileparse($fasta_file, qr/\.[^.]*/);
  my $checksum_dir   = "$out_dir/checksum";
  my $nochecksum_dir = "$out_dir/nochecksum";
  
  if (!-e $checksum_dir) {
    make_path($checksum_dir) or $self->throw("Failed to create directory '$checksum_dir'");
  }
  
  if (!-e $nochecksum_dir) {
    make_path($nochecksum_dir) or $self->throw("Failed to create directory '$nochecksum_dir'");
  }
  
  my $checksum_file   = "$checksum_dir/$basename.fa";
  my $nochecksum_file = "$nochecksum_dir/$basename.fa";
  $self->param('checksum_file', $checksum_file);
  $self->param('nochecksum_file', $nochecksum_file);
  
  my $all        = Bio::SeqIO->new(-format => 'Fasta', -file => $fasta_file);
  my $checksum   = Bio::SeqIO->new(-format => 'Fasta', -file => ">$checksum_file");
  my $nochecksum = Bio::SeqIO->new(-format => 'Fasta', -file => ">$nochecksum_file");
  
  my $sth = $self->hive_dbh->prepare("select 1 from checksum where md5sum=? limit 1;")
    or self->throw("Hive DB connection error: ".$self->hive_dbh->errstr);
  
  while (my $seq = $all->next_seq) {
    if ($self->has_checksum($sth, md5_hex($seq->seq))) {
      my $success = $checksum->write_seq($seq);
      $self->throw("Failed to write sequence to '$checksum_file'") unless $success;
    } else {
      my $success = $nochecksum->write_seq($seq);
      $self->throw("Failed to write sequence to '$nochecksum_file'") unless $success;
    }
  }
}

sub write_output {
  my ($self) = @_;
  
  $self->dataflow_output_id({'checksum_file' => $self->param('checksum_file')}, 1);
  $self->dataflow_output_id({'nochecksum_file' => $self->param('nochecksum_file')}, 2);
}

sub has_checksum {
  my ($self, $sth, $md5sum) = @_;
  
  $sth->bind_param(1, $md5sum, SQL_CHAR);
  $sth->execute();
  my $result = $sth->fetchrow_arrayref;
  
  return defined($result) ? 1 : 0;
}

1;
