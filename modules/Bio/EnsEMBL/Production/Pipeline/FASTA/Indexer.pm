=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FASTA::Indexer;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::FASTA::Base/;

use File::Copy qw/copy/;
use File::Spec;
use Bio::EnsEMBL::Utils::Exception qw/throw/;

sub param_defaults {
  my ($self) = @_;
  return {
    program => 'xdformat',
    blast_dir => 'blast',
    skip => 0,
    index_masked_files => 1,
  };
}


sub decompress {
  my ($self) = @_;
  my $source = $self->param('file');
  my $target_dir = $self->target_dir();
  my ($vol, $dir, $file) = File::Spec->splitpath($source);
  my $target = File::Spec->catdir($target_dir, $file);
  my $gunzipped_target = $target;
  $gunzipped_target =~ s/.gz$//;
  $self->info('Copying from %s to %s', $source, $target);
  copy($source, $target) or throw "Cannot copy $source to $target: $!";
  $self->info('Decompressing %s to %s', $source, $gunzipped_target);
  system("gunzip -f $target") and throw sprintf('Could not gunzip. Exited with code %d', ($? >>8));
  return $gunzipped_target;
}

sub repeat_mask_date {
  my ($self) = @_;
  my $res = $self->get_DBAdaptor()->dbc()->sql_helper()->execute_simple(
    -SQL => <<'SQL',
select max(date_format( created, "%Y%m%d"))
from analysis a join meta m on (a.logic_name = lower(m.meta_value))
where meta_key =?
SQL
    -PARAMS => ['repeat.analysis']
  );
  return $res->[0] if @$res;
  return q{};
}

sub run {
  my ($self) = @_;
  return if ! $self->ok_to_index_file();
  my $decompressed = $self->decompress();
  $self->index_file($decompressed);
  if(-f $decompressed) {
    $self->info("Cleaning up the file '${decompressed}' from the file system");
    unlink $decompressed or $self->throw("Cannot unlink '$decompressed' from the file system: $!");
  }
  $self->cleanup_DBAdaptor();
  return;
}

sub index_file {
  die "Implement";
}

sub target_dir {
  die "Implement";
}

sub ok_to_index_file {
  my ($self) = @_;
  return 0 if $self->param('skip');
  my $source = $self->param('file');
  # If it was a masked DNA file & we asked not to index them then skip
  return 0 if $self->param('index_masked_files') && $source =~ /\.dna_[sr]m\./;
  return 1;
}

1;
