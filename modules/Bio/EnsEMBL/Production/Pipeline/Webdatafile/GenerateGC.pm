=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenerateGC;

=head1 DESCRIPTION
  Compute Gene and Transcript  step for webdatafile dumps

=cut

package Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenerateGC;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Path::Tiny qw(path);
use Carp qw/croak/;
use JSON qw/decode_json/;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::IndexWig;
use Capture::Tiny qw/capture/;
use Path::Tiny qw/path tempfile/;


sub run {

  my ($self) = @_;
  my $species = $self->param('species');
  my $current_step = $self->param('current_step') ;
  my $output = $self->param('output_path');
  my $app_path = $self->param('app_path'); 
  my $genome_data = {
    dbname     => $self->param('dbname'),
    gca        => $self->param('gca'),
    genome_id  => $self->param('genome_id'),
    species    => $self->param('species'),
    version    => $self->param('version'),
    type       => $self->param('type'),  
    root_path  => path($self->param('root_path'))
  };
  my $lookup = Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup->new("genome_data" => $genome_data); 
  my $genome = $lookup->get_genome('1');
  my $chrom_report = $genome->get_chrom_report();
  $self->generate_gc($genome, $chrom_report);
  $self->wig_index($genome);
  
}

sub wig_index{

  my ($self, $genome) = @_;
  my $gc_path = $genome->gc_path(); 
  my $chrom_report = $genome->get_chrom_report('sortbyname');
  my @paths;
  my $indexer = Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::IndexWig->new(genome => $genome);
  $self->warning(  "Finding GC wig files for ".$genome->genome_id() );
  while(my $report = shift @{$chrom_report}) {
      my $sub_path = $gc_path->child($genome->to_seq_id($report).".wig.gz");
      next unless $sub_path->exists();
      $self->warning("Indexing wig file ${sub_path} ... ");
      my $bw_path = $indexer->index_gzip_wig($sub_path);
      push(@paths, $bw_path);
      $self->warning("Done");
    }
    my $target_bw = $genome->gc_bw_path();
    $self->warning("Found ".scalar(@paths)." bigwigs. Concat into a single bigwig ${target_bw} ... ");
    $indexer->bigwig_cat(\@paths, $target_bw);
    $self->warning("DONE\n");
 


}
sub generate_gc {

  my ($self, $genome, $chrom_report) = @_;
  my $gc_path = $genome->gc_path(); 
  while(my $report = shift @{$chrom_report}) {
    my $seq_ref = $report->get_seq_ref();
    my $name = $report->name();

    $self->warning( "======> Processing ${name} for GC content\n");

    my $gc_fasta = tempfile('gcwriter_XXXXXXXX');
    my $fh = $gc_fasta->openw();
    print $fh ">${name}\n";
    ${$seq_ref} =~ s/(.{1,60})/$1\n/g;
    print $fh ${$seq_ref};
    print "\n";
    close $fh;

    my $output = $gc_path->child($genome->to_seq_id($report));

    my $cmd = 'GC_analysis.py';
    my @args = (
      '--input_file', $gc_fasta->stringify(),
      '--output_file', $output,
      '--window_size', 5,
      '--shift', 5,
      '--output_format', 'gzip',
    );
   
    my ($stdout, $stderr, $exit) = capture {
      system($cmd, @args);
    };
    $self->warning("GC STDOUT:\n");
    $self->warning("${stdout}\n");
    if($exit != 0) {
      die "Return code was ${exit}. Failed to execute command $cmd: $!";
    }

    $self->warning( "======> DONE\n");
  }

}


1;
