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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Xrefs::DumpEnsembl

=head1 DESCRIPTION

Produces FASTA dumps of cDNA and peptide sequence for use in alignment for xrefs

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::DumpEnsembl;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

use Bio::EnsEMBL::Utils::IO::FASTASerializer;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use IO::File;


sub run {
  my ($self) = @_;
  my $species   = $self->param_required('species');
  my $base_path = $self->param_required('base_path');
  my $release   = $self->param_required('release');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();
  my $cdna_path = $self->get_path($base_path, $species, $release, "ensembl", 'transcripts.fa');
  my $pep_path = $self->get_path($base_path, $species, $release, "ensembl", 'peptides.fa');
  $self->param('cdna_path', $cdna_path);
  $self->param('pep_path', $pep_path);

  # Check if dumping has been done for this run before, to speed up development by not having to re-dump sequence.
  return if -e $cdna_path and -e $pep_path and -s $cdna_path and -s $pep_path;

  my $fh = IO::File->new($cdna_path ,'w') || throw("Cannot create filehandle $cdna_path");
  my $fasta_writer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new($fh);
  my $pep_fh = IO::File->new($pep_path ,'w') || throw("Cannot create filehandle $pep_path");
  my $pep_writer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new($pep_fh);

  my $registry = 'Bio::EnsEMBL::Registry';
  my $transcript_adaptor = $registry->get_adaptor($species, 'Core', 'Transcript');
  my $transcript_list = $transcript_adaptor->fetch_all();
  while (my $transcript = shift @$transcript_list) {
    my $seq = $transcript->seq();
    $seq->id($transcript->dbID());
    $fasta_writer->print_Seq($seq);
    my $translation = $transcript->translation;
    if ($translation) {
      $seq = $transcript->translate;
      $seq->id($translation->dbID());
      $pep_writer->print_Seq($seq);
    }
  }

  $fh->close;
  $pep_fh->close;

}

sub write_output {
  my ($self) = @_;
  my $species   = $self->param('species');
  my $cdna_path = $self->param('cdna_path');
  my $pep_path  = $self->param('pep_path');
  my $xref_url  = $self->param('xref_url');

  # Create jobs for peptide dumping and alignment
  my $dataflow_params = {
    species     => $species,
    file_path   => $pep_path,
    xref_url    => $xref_url,
    seq_type    => 'peptide',
  };
  $self->dataflow_output_id($dataflow_params, 2);

  # Create jobs for cdna dumping and alignment
  $dataflow_params = {
    species     => $species,
    file_path   => $cdna_path,
    xref_url    => $xref_url,
    seq_type    => 'dna',
  };
  $self->dataflow_output_id($dataflow_params, 2);

  # Create job for mapping
  $dataflow_params = {
    species     => $species,
    xref_url    => $xref_url,
  };
  $self->dataflow_output_id($dataflow_params, 1);
  return;
}


1;
