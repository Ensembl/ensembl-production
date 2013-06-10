=pod

=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile

=head1 DESCRIPTION

The main workhorse of the GTF dumping pipeline.

Allowed parameters are:

=over 8

=item species - The species to dump

=item base_path - The base of the dumps

=item release - The current release we are emitting

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::GTF::Base);

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file gz_work_with_file/;
use Bio::EnsEMBL::Utils::IO::GTFSerializer;
use File::Path qw/rmtree/;

sub fetch_input {
  my ($self) = @_;
    
  throw "Need a species" unless $self->param('species');
  throw "Need a release" unless $self->param('release');
  throw "Need a base_path" unless $self->param('base_path');

  throw "No gtfToGenePred executable given" 
    unless $self->param('gtf_to_genepred');
  $self->assert_executable($self->param('gtf_to_genepred'));

  throw "No genePredCheck executable given" 
    unless $self->param('gene_pred_check');
  $self->assert_executable($self->param('gene_pred_check'));

  return;
}

sub run {
  my ($self) = @_;
  
  my $root = $self->data_path();
  if(-d $root) {
    $self->info('Directory "%s" already exists; removing', $root);
    rmtree($root);
  }

  my $path = $self->_generate_file_name();
  $self->info("Dumping GTF to %s", $path);
  gz_work_with_file($path, 'w', 
		 sub {
		   my ($fh) = @_;
		   my $gtf_serializer = 
		     Bio::EnsEMBL::Utils::IO::GTFSerializer->new($fh);

		   # filter for 1st portion of human Y
		   foreach my $slice (@{$self->get_Slices('core', 1)}) { 
		     foreach my $gene (@{$slice->get_all_Genes(undef, undef, 1)}) {
		       foreach my $transcript (@{$gene->get_all_Transcripts()}) {
			 $gtf_serializer->print_feature($transcript);
		       }
		     }
		   }
		 });

  $self->info(sprintf "Checking GTF file %s", $path);
  $self->_gene_pred_check($path);
  
  # $self->run_cmd("gzip $path");

  $self->info("Dumping GTF README for %s", $self->param('species'));
  $self->_create_README();  
  
  return;
}

sub _gene_pred_check {
  my ($self, $gtf_file) = @_;
  my $info_out = File::Spec->catfile($self->data_path(), 'info.out');
  my $genepred_out = File::Spec->catfile($self->data_path(), 'info.gp');

  my $cmd = sprintf(q{%s -infoOut=%s -genePredExt %s %s}, 
    $self->param('gtf_to_genepred'), $info_out, $gtf_file, $genepred_out);
  $self->run_cmd($cmd);

  $cmd = sprintf(q{%s %s}, $self->param('gene_pred_check'), $genepred_out);
  my ($rc, $output) = $self->run_cmd($cmd);

  throw sprintf "genePredCheck reports failure for %s GTF dump", $self->param('species')
    unless $output =~ /failed: 0/;

  unlink $info_out;
  unlink $genepred_out;

  return;
}

sub _generate_file_name {
  my ($self) = @_;

  # File name format looks like:
  # <species>.<assembly>.<release>.gtf.gz
  # e.g. Homo_sapiens.GRCh37.71.gtf.gz
  my @name_bits;
  push @name_bits, $self->web_name();
  push @name_bits, $self->assembly();
  push @name_bits, $self->param('release');
  push @name_bits, 'gtf', 'gz';

  my $file_name = join( '.', @name_bits );
  my $path = $self->data_path();

  return File::Spec->catfile($path, $file_name);

}

sub _create_README {
  my ($self) = @_;
  my $species = $self->scientific_name();
  
  my $readme = <<README;
#### README ####

--------
GTF DUMP
--------

This directory includes a summary of the gene annotation information 
and GTF format.

Ensembl provides an automatic gene annotation for $species.
For some species (including human, mouse, zebrafish and pig), the
annotation provided through Ensembl also includes manual annotation
from HAVANA.
These data will be dumped in a number of forms - one of them being 
GTF files. Our annotation is based on alignments of biological 
sequence data (eg. proteins, cDNAs) to the genome assembly. 
The annotation dumped here is transcribed and translated from the 
genome assembly and is not the original input sequence data that 
we used for alignment. Therefore, the sequences provided by Ensembl 
may differ from the original input sequence data where the genome 
assembly is different to the aligned sequence. 

GTF file format dumping provides all the annotated protein coding 
genes in this release genes's set. Considerably more information 
is stored in Ensembl: the GTF file just gives a representation which 
is compatible with existing tools.

--------------------------------
Definition and supported options
--------------------------------

The GFF (General Feature Format) format consists of one line per 
feature, each containing 9 columns of data, plus optional track 
definition lines. The following documentation is based on the 
Version 2 specifications. The GTF (General Transfer Format) is 
identical to GFF version 2.

Fields

Fields must be tab-separated. Also, all but the final field in each 
feature line must contain a value; "empty" columns should be denoted 
with a '.'

    seqname   - name of the chromosome or scaffold; chromosome names 
                can be given with or without the 'chr' prefix (the 
                convention in Ensembl is to omit the 'chr' prefix).
    source    - name of the program that generated this feature, or 
                the data source (database or project name)
    feature   - feature type name, e.g. Gene, Variation, Similarity
    start     - start position of the feature, with sequence numbering 
                starting at 1.
    end       - end position of the feature, with sequence numbering 
                starting at 1.
    score     - a floating point value.
    strand    - defined as + (forward) or - (reverse).
    frame     - one of '0', '1' or '2'. '0' indicates that the first 
                base of the feature is the first base of a codon, '1' 
                that the second base is the first base of a codon, and 
                so on..
    attribute - a semicolon-separated list of tag-value pairs, providing 
                additional information about each feature.

Track lines

Although not part of the formal GFF specification, Ensembl will use 
track lines to further configure sets of features. Track lines should 
be placed at the beginning of the list of features they are to affect.

The track line consists of the word 'track' followed by space-separated 
key=value pairs. Valid parameters used by Ensembl are:

    name        - unique name to identify this track when parsing the 
                  file
    description - Label to be displayed under the track in Region in 
                  Detail
    priority    - integer defining the order in which to display tracks, 
                  if multiple tracks are defined.

--------------
Example output
--------------

MT      Mt_tRNA exon    3230    3304    .       +       .       gene_id "ENSG00000209082"; transcript_id "ENST00000386347"; exon_number "1"; gene_name "MT-TL1"; gene_biotype "Mt_tRNA"; transcript_name "MT-TL1-201"; exon_id "ENSE00002006242";
MT      protein_coding  exon    3307    4262    .       +       .       gene_id "ENSG00000198888"; transcript_id "ENST00000361390"; exon_number "1"; gene_name "MT-ND1"; gene_biotype "protein_coding"; transcript_name "MT-ND1-201"; exon_id "ENSE00001435714";
MT      protein_coding  CDS     3307    4262    .       +       0       gene_id "ENSG00000198888"; transcript_id "ENST00000361390"; exon_number "1"; gene_name "MT-ND1"; gene_biotype "protein_coding"; transcript_name "MT-ND1-201"; protein_id "ENSP00000354687";
MT      protein_coding  start_codon     3307    3309    .       +       0       gene_id "ENSG00000198888"; transcript_id "ENST00000361390"; exon_number "1"; gene_name "MT-ND1"; gene_biotype "protein_coding"; transcript_name "MT-ND1-201";

README
  
  my $path = File::Spec->catfile($self->data_path(), 'README');
  work_with_file($path, 'w', sub {
    my ($fh) = @_;
    print $fh $readme;
    return;
  });
  return;
}

1;

