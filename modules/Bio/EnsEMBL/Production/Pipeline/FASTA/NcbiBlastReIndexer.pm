=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::FASTA::NcbiBlastReIndexer

=head1 DESCRIPTION

Overrides the NcbiBlastIndexer to provide indexing based only on a file name generated
by the FASTA pipeline for FTP dumps.

Allowed parameters are:

=over 8

=item file - The file to index. All other parameters are derrived from this

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::FASTA::NcbiBlastReIndexer;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::FASTA::NcbiBlastIndexer/;
use File::Basename;

sub param_defaults {
  my ($self) = @_;
  return $self->SUPER::param_defaults();
}

sub fetch_input {
  my ($self) = @_;
  my $file = $self->param('file');
  die "No file parameter '$file' given" unless defined $file;
  die "No file at '$file' exists" unless -f $file;
  my $filename = basename($self->param('file'));
  
  #Filenames can look like:
  # Drosophila_melanogaster.BDGP5.70.dna.toplevel.fa.gz
  # Drosophila_melanogaster.BDGP5.70.dna_rm.toplevel.fa.gz
  # Drosophila_melanogaster.BDGP5.70.dna_sm.toplevel.fa.gz
  # Drosophila_melanogaster.BDGP5.70.cdna.all.fa.gz
  # Drosophila_melanogaster.BDGP5.70.cdna.abinitio.fa.gz
  # Drosophila_melanogaster.BDGP5.70.ncrna.fa.gz
  # Drosophila_melanogaster.BDGP5.70.pep.all.fa.gz
  # Drosophila_melanogaster.BDGP5.70.pep.abinitio.fa.gz
  
  # Because . can appear in assembly names the regex is quite difficult
  # and it's easier to split on . and then pop & shift our way through it
  my ($species, $assembly, $release, $type, $sub_type);
  $filename =~ s/\.fa\.gz$//;
  my @split_name = split(/\./, $filename);
  $species = shift (@split_name);
  $sub_type = pop(@split_name);
  $type = pop(@split_name);
  $release = pop(@split_name);
  $assembly = join(q{.}, @split_name);
  
  my $molecule = ( $type =~ /na/ ) ? 'dna' : 'pep'; # if it has an na in there then it's DNA
  my $blast_type = ($type =~ /dna/ && $type ne 'cdna' ) ? 'genomic' : 'genes'; # if it was DNA then it's genomic
  
  $self->param('species', lc($species));
  $self->param('molecule', $molecule);
  $self->param('type', $blast_type);
  $self->param('release', $release);
  
  return $self->SUPER::fetch_input();
}

1;
