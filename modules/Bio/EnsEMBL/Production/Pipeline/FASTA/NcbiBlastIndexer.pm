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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::FASTA::NcbiBlastIndexer

=head1 DESCRIPTION

Creates NCBI Blast indexes of the given GZipped file. The resulting index
is created under the parameter location I<base_path> in ncbi_blast and then in a
directory defined by the type of dump. The type of dump also changes the file
name generated. Genomic dumps have their release number replaced with the
last repeat masked date. 

Allowed parameters are:

=over 8

=item file - The file to index

=item program - The location of the xdformat program

=item molecule - The type of molecule to index. I<dna> and I<pep> are allowed

=item type - Type of index we are creating. I<genomic> and I<genes> are allowed

=item base_path - The base of the dumps

=item release - Required for correct DB naming

=item skip - Skip this iteration of the pipeline

=item index_masked_files - Allows you to index masked files. This is off by default as NCBI Blast can support this but not without further processing

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::FASTA::NcbiBlastIndexer;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::FASTA::BlastIndexer/;
use Cwd;
use Bio::EnsEMBL::Utils::Scalar qw/scope_guard/;
use File::Basename qw/fileparse/;

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults()},
    program => 'makeblastdb',
    blast_dir => 'ncbi_blast',
    index_masked_files => 0,
  };
}

sub index_file {
  my ($self, $source_file) = @_;
  my $molecule_arg = ($self->param('molecule') eq 'dna') ? 'nucl' : 'prot' ;
  my $target_dir = $self->target_dir();
  my $target_file = $self->target_file($source_file);
  my $db_title = $self->db_title($source_file);
  
  # Do a scope guard to bring us back into the right directory & cd into the target
  my $current_dir = getcwd;
  my $guard = scope_guard(sub { chdir($current_dir) } );
  chdir($target_dir) or $self->throw("Cannot change into the target directory $target_dir");

  #Need more localised filenames since we are cd'ing into the directory & avoids later multi-file absolute .nal issues
  my $source_filename = fileparse($source_file);
  my $target_filename = fileparse($target_file);

  my $cmd = sprintf(q{%s -in %s -out %s -dbtype %s -title %s -input_type fasta}, 
    $self->param('program'), $source_filename, $target_filename, $molecule_arg, $db_title);
  $self->run_cmd($cmd);
  $self->param('index_base', $target_file);
  return;
}

1;
