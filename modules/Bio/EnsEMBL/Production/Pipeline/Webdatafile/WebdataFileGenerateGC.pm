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

 Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFileGenerateGC;

=head1 DESCRIPTION
  Compute GC percentage  step for webdatafile dumps

=cut

package Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFileGenerateGC;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Path::Tiny qw(path);
use Carp qw/croak/;
use JSON qw/decode_json/;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup;
use Capture::Tiny qw/capture/;
use Path::Tiny qw/path tempfile/;

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults},
  };
}


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
  
}


sub generate_gc {

  my ($self, $genome, $chrom_report) = @_;
  my $gc_path = $genome->gc_path(); 
  while(my $report = shift @{$chrom_report}) {
    my $seq_ref = $report->get_seq_ref();
    my $name = $report->name();

    print STDERR "======> Processing ${name} for GC content\n";

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
    print STDERR "GC STDOUT:\n";
    print STDERR "${stdout}\n";
    if($exit != 0) {
      die "Return code was ${exit}. Failed to execute command $cmd: $!";
    }

    print STDERR "======> DONE\n";
  }

}


1;
