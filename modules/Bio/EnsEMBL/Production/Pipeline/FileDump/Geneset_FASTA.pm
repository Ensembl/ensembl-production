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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_FASTA;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::FileDump::Base_Filetype);

use Bio::EnsEMBL::Utils::IO::FASTASerializer;
use File::Spec::Functions qw/catdir/;
use Path::Tiny;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    data_type       => 'sequence',
    data_types      => ['cdna', 'cds', 'pep'],
    file_type       => 'fa',
    chunk_size      => 10000,
    line_width      => 60,
    blast_index     => 0,
    blastdb_exe     => 'makeblastdb',
    blast_dirname   => 'ncbi_blast',
  };
}

sub run {
  my ($self) = @_;

  my $blast_index = $self->param_required('blast_index');
  my $filenames   = $self->param_required('filenames');

  my $dba = $self->dba;

  my ($chr, $non_chr, $non_ref) = $self->get_slices($dba);

  my $cdna_filename = $$filenames{'cdna'};
  my $cds_filename  = $$filenames{'cds'};
  my $pep_filename  = $$filenames{'pep'};

  $self->print_to_file([@$chr, @$non_chr], $cdna_filename, $cds_filename, $pep_filename, '>');

  if (scalar(@$non_ref)) {
    my $non_ref_cdna_filename = $self->generate_non_ref_filename($cdna_filename);
    my $non_ref_cds_filename  = $self->generate_non_ref_filename($cds_filename);
    my $non_ref_pep_filename  = $self->generate_non_ref_filename($pep_filename);
    path($cdna_filename)->copy($non_ref_cdna_filename);
    path($cds_filename)->copy($non_ref_cds_filename);
    path($pep_filename)->copy($non_ref_pep_filename);
    $self->print_to_file($non_ref, $non_ref_cdna_filename, $non_ref_cds_filename, $non_ref_pep_filename, '>>');
  }

  if ($blast_index) {
    $self->blast_index($cdna_filename, 'nucl');
    $self->blast_index($cds_filename, 'nucl');
    $self->blast_index($pep_filename, 'prot');
  }
}

sub print_to_file {
  my ($self, $slices, $cdna_filename, $cds_filename, $pep_filename, $mode) = @_;

  my $cdna_serializer = $self->fasta_serializer($cdna_filename, $mode);
  my $cds_serializer  = $self->fasta_serializer($cds_filename, $mode);
  my $pep_serializer  = $self->fasta_serializer($pep_filename, $mode);

  while (my $slice = shift @{$slices}) {
    my $transcripts = $slice->get_all_Transcripts();
    while (my $transcript = shift @$transcripts) {
      my $cdna_seq = $transcript->seq;
      $cdna_seq->display_id($self->header($transcript, 'cdna'));
      $cdna_serializer->print_Seq($cdna_seq);
      
      if ($transcript->translateable_seq ne '') {
        my $cds_seq = $cdna_seq;
        $cds_seq->seq($transcript->translateable_seq);
        $cds_seq->display_id($self->header($transcript, 'cds'));
        $cds_serializer->print_Seq($cds_seq);

        my $pep_seq = $transcript->translate;
        if (defined $pep_seq) {
          $pep_seq->display_id($self->header($transcript, 'pep'));
          $pep_serializer->print_Seq($pep_seq);
        }
      }
    }
  }
}

sub fasta_serializer {
  my ($self, $filename, $mode) = @_;
  my $chunk_size = $self->param('chunk_size');
  my $line_width = $self->param('line_width');

  my $fh = path($filename)->filehandle($mode);
  my $serializer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new(
    $fh,
    undef,
    $chunk_size,
    $line_width,
  );

  return $serializer;
}

sub header {
  my ($self, $transcript, $seq_type) = @_;
  
  my @attributes = ();
  if ($seq_type eq 'cdna' || $seq_type eq 'cds') {
    push @attributes, $transcript->stable_id_version;
  } elsif ($seq_type eq 'pep') {
    push @attributes, $transcript->translation->stable_id_version;
  }

  push @attributes, $seq_type;

  if ($seq_type eq 'cdna') {
    push @attributes, join(':',
      $transcript->slice->coord_system->version,
      $transcript->seq_region_name,
      $transcript->seq_region_start,
      $transcript->seq_region_end,
      $transcript->strand,
    );
  } elsif ($seq_type eq 'cds' || $seq_type eq 'pep') {
    push @attributes, join(':',
      $transcript->slice->coord_system->version,
      $transcript->seq_region_name,
      $transcript->coding_region_start,
      $transcript->coding_region_end,
      $transcript->strand,
    );
  }

  my $gene = $transcript->get_Gene;

  push @attributes, 'gene:'.$gene->stable_id_version;

  if ($seq_type eq 'pep') {
    push @attributes, 'transcript:'.$transcript->stable_id_version;
  }

  push @attributes, 'gene_biotype:'.$gene->biotype;
  push @attributes, 'transcript_biotype:'.$transcript->biotype;

  my $xref = $gene->display_xref;
  if (defined $xref && defined $xref->display_id) {
    push @attributes, 'gene_symbol:'.$xref->display_id;
  }

  my $desc = $gene->description;
  if (defined $desc) {
    push @attributes, 'description:"'.$gene->description.'"';
  }

  return join(' ', @attributes);
}

sub blast_index {
  my ($self, $filename, $dbtype) = @_;

  my $web_dir = $self->param_required('web_dir');
  my $blast_dirname = $self->param_required('blast_dirname');
  my $file_type = $self->param_required('file_type');

  # New genesets should overwrite old ones; so remove the
  # geneset version from the name.
  my $basename = path($filename)->basename;
  $basename =~ s/\-[^-]+(\-[^-]+\.$file_type)$/$1/;

  my $blast_filename = catdir(
    $web_dir,
    $blast_dirname,
    'genes',
    $basename
  );
  path($blast_filename)->parent->mkpath();

  $self->create_blast_index($filename, $blast_filename, $dbtype);
}

1;
