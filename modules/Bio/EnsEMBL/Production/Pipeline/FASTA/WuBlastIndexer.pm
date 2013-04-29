=pod

=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

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
