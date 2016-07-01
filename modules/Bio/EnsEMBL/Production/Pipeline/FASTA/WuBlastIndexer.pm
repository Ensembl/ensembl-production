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

Bio::EnsEMBL::Production::Pipeline::FASTA::WuBlastIndexer

=head1 DESCRIPTION

Creates WUBlast indexes of the given GZipped file. The resulting index
is created under the parameter location I<base_path> in blast and then in a
directory defined by the type of dump. The type of dump also changes the file
name generated. Genomic dumps have their release number replaced with the
last repeat masked date. 

See Bio::EnsEMBL::Production::Pipeline::FASTA::BlastIndexer for the allowed parameters.

=cut

package Bio::EnsEMBL::Production::Pipeline::FASTA::WuBlastIndexer;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::FASTA::BlastIndexer/;

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults()},
    program => 'xdformat',
    blast_dir => 'blast',
  };
}

sub index_file {
  my ($self, $source_file) = @_;
  my $molecule_arg = ($self->param('molecule') eq 'dna') ? '-n' : '-p' ;
  my $silence = ($self->debug()) ? 0 : 1;
  my $target_dir = $self->target_dir();
  my $target_file = $self->target_file($source_file);
  my $db_title = $self->db_title($source_file);
  my $date = $self->db_date();
  
  my $cmd = sprintf(q{cd %s && %s %s -q%d -I -t %s -d %s -o %s %s }, 
    $target_dir, $self->param('program'), $molecule_arg, $silence, $db_title, $date, $target_file, $source_file);
  
  $self->run_cmd($cmd);
  $self->param('index_base', $target_file);
  return;
}

1;
