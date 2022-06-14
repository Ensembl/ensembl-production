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

package Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile;

use strict;
use warnings;
no  warnings 'redefine';
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO::GFFSerializer;
use Bio::EnsEMBL::Utils::IO qw/work_with_file gz_work_with_file/;
use File::Path qw/rmtree/;
use File::Spec::Functions qw/catdir/;
use Bio::EnsEMBL::Transcript;

my $add_xrefs = 0;

sub fetch_input {
  my ($self) = @_;
  my $base_path     = $self->param('base_path');
  my $out_file_stem = $self->param('out_file_stem');
  my $species       = $self->param('species');
  my $release       = $self->param('release');
  $add_xrefs        = $self->param('xrefs');

  throw "Need a species" unless $species;
  throw "Need a release" unless $release;
  throw "Need a base_path" unless $base_path;

  my ($out_file, $abinitio_out_file);
  if (defined $out_file_stem) {
    $out_file = catdir($base_path, "$species.$out_file_stem");
    $abinitio_out_file = catdir($base_path, "$species.$out_file_stem.abinitio") if $self->param('abinitio');
  } else {
    $out_file = $self->_generate_file_name();
    $abinitio_out_file = $self->_generate_abinitio_file_name() if $self->param('abinitio');
  }

  $self->param('out_file', $out_file);
  $self->param('abinitio_out_file', $abinitio_out_file);

  return;
}

sub run {
  my ($self) = @_;
  my $species          = $self->param_required('species');
  my $db_type          = $self->param_required('db_type');
  my $out_file         = $self->param_required('out_file');
  my $feature_types    = $self->param('feature_type');
  my $per_chromosome   = $self->param_required('per_chromosome');
  my $abinitio_out_file = $self->param('abinitio_out_file');
  
  my $reg = 'Bio::EnsEMBL::Registry';

  my $slices = $self->get_Slices($self->param('db_type'), 1);

  my %adaptors;
  foreach my $feature_type (@$feature_types) {
    $adaptors{$feature_type} = $reg->get_adaptor($species, $db_type, $feature_type);
    if ($feature_type eq 'Transcript') {
      $adaptors{'Exon'} = $reg->get_adaptor($species, $db_type, 'Exon');
    }
  }
  $adaptors{'PredictionTranscript'} = $reg->get_adaptor($species, $db_type, 'PredictionTranscript');

  my $out_files;

  my $chr_out_file = $out_file;
  $chr_out_file =~ s/\.gff3/\.chr\.gff3/;
  my $alt_out_file = $out_file;
  $alt_out_file =~ s/\.gff3/\.chr_patch_hapl_scaff\.gff3/;
  my $tmp_out_file = $out_file . "_tmp";
  my $tmp_alt_out_file = $alt_out_file . "_tmp";

  my (@chroms, @scaff, @alt);
  my $chromosome_name = $self->get_chromosome_name();

  foreach my $slice (@$slices) {
    if ($slice->is_reference) {
      if ($slice->is_chromosome) {
        if ($per_chromosome) {
          my $slice_name = $chromosome_name . "." . $slice->seq_region_name;
          my $chr_file = $out_file;
          $chr_file =~ s/\.gff3/\.$slice_name\.gff3/;
          if ($self->param('gene')) {
            $self->print_to_file([$slice], $chr_file, $feature_types, \%adaptors, 1);
            push @$out_files, $chr_file;
          }
        }
        push @chroms, $slice;
      }
      else {
        push @scaff, $slice;
      }
    } else {
      push @alt, $slice;
    }
  }

  my $unzipped_out_file;
  if (scalar(@chroms) > 0 && scalar(@$slices) > scalar(@chroms) && $self->param('gene')) {
    $self->print_to_file(\@chroms, $chr_out_file, $feature_types, \%adaptors, 1);
    $self->print_to_file(\@scaff, $tmp_out_file, $feature_types, \%adaptors);
    system("cat $chr_out_file $tmp_out_file > $out_file");
    # To avoid multistream issues, we need to unzip then rezip the output file
    $unzipped_out_file = $out_file;
    $unzipped_out_file =~ s/\.gz$//;
    system("gunzip $out_file");
    system("gzip -n $unzipped_out_file");
    system("rm $tmp_out_file");
    push @$out_files, $chr_out_file;
    push @$out_files, $out_file;
  } elsif (scalar(@chroms) > 0 && $self->param('gene')) {
    # If species has only chromosomes, dump only one file
    $self->print_to_file(\@chroms, $out_file, $feature_types, \%adaptors, 1);
    push @$out_files, $out_file;
  } elsif ($self->param('gene')) {
    # If species has only scaffolds, dump only one file
    $self->print_to_file(\@scaff, $out_file, $feature_types, \%adaptors, 1);
    push @$out_files, $out_file;
  }
  if (scalar(@alt) > 0 && $self->param('gene')) {
    $self->print_to_file(\@alt, $tmp_alt_out_file, $feature_types, \%adaptors);
    system("cat $out_file $tmp_alt_out_file > $alt_out_file");
    # To avoid multistream issues, we need to unzip then rezip the output file
    $unzipped_out_file = $alt_out_file;
    $unzipped_out_file =~ s/\.gz$//;
    system("gunzip $alt_out_file");
    system("gzip -n $unzipped_out_file");
    system("rm $tmp_alt_out_file");
    push @$out_files, $alt_out_file;
  }

  if ($self->param('abinitio')) {
    $self->print_to_file($slices, $abinitio_out_file, ['PredictionTranscript'], \%adaptors, 1);
    push @$out_files, $abinitio_out_file;
  }

  $self->param('out_files', $out_files);

  $self->info("Dumping GFF3 README for %s", $self->param('species'));
  $self->_create_README();
  $self->core_dbc()->disconnect_if_idle() if defined $self->core_dbc;
  $self->hive_dbc()->disconnect_if_idle() if defined $self->hive_dbc;
}

sub print_to_file {
  my ($self, $slices, $file, $feature_types, $adaptors, $include_header) = @_;

  my $dba = $self->core_dba;
  my $include_scaffold = $self->param_required('include_scaffold');
  my $logic_names = $self->param_required('logic_name');

  my $reg = 'Bio::EnsEMBL::Registry';

  my $mc = $dba->get_MetaContainer();
  my $providers = $mc->list_value_by_key('provider.name') || '';
  my $provider = join(" and ", @$providers);

  gz_work_with_file($file, 'w', sub {
    my ($fh) = @_;

    my $serializer = Bio::EnsEMBL::Utils::IO::GFFSerializer->new($fh);

    $serializer->print_main_header(undef, $dba) if $include_header;

    foreach my $slice(@$slices) {
      if ($include_scaffold) {
        $slice->source($provider) if $provider;
        $serializer->print_feature($slice);
      }
      foreach my $feature_type (@$feature_types) {
        my $features = $self->fetch_features($feature_type, $adaptors->{$feature_type}, $logic_names, $slice);
        $serializer->print_feature_list($features);
      }
    }
  });
}

sub fetch_features {
  my ($self, $feature_type, $adaptor, $logic_names, $slice) = @_;
  
  my @features;
  if (scalar(@$logic_names) == 0) {
    @features = @{$adaptor->fetch_all_by_Slice($slice)};
  } else {
    foreach my $logic_name (@$logic_names) {
      my $features;
      if ($feature_type eq 'Transcript') {
        $features = $adaptor->fetch_all_by_Slice($slice, 0, $logic_name);
      } else {
        $features = $adaptor->fetch_all_by_Slice($slice, $logic_name);
      }
      push @features, @$features;
    }
  }
  $adaptor->clear_cache();
  if ($feature_type eq 'Transcript') {
    my $exon_features = $self->exon_features(\@features);
    push @features, @$exon_features;
  }

  if ($feature_type eq 'PredictionTranscript') {
    my $prediction_exons = $self->prediction_exons(\@features);
    push @features, @$prediction_exons;
  }
      
  return \@features;
}

sub prediction_exons {
  my ($self, $transcripts) = @_;

  my @prediction_exons;
  foreach my $transcript(@$transcripts) {
    push @prediction_exons, @{ $transcript->get_all_Exons() };
  }
  return \@prediction_exons;
}

sub exon_features {
  my ($self, $transcripts) = @_;
  
  my @cds_features;
  my @exon_features;
  my @utr_features;
  
  foreach my $transcript (@$transcripts) {
    push @cds_features, @{ $transcript->get_all_CDS(); };
    push @exon_features, @{ $transcript->get_all_ExonTranscripts() };
    push @utr_features, @{ $transcript->get_all_five_prime_UTRs()};
    push @utr_features, @{ $transcript->get_all_three_prime_UTRs()};
  }
  
  return [@exon_features, @cds_features, @utr_features];
}

sub Bio::EnsEMBL::Transcript::summary_as_hash {
  my $self = shift;
  my %summary;

  my $parent_gene = $self->get_Gene();
  my $id = $self->display_id;

  $summary{'seq_region_name'}          = $self->seq_region_name;
  $summary{'source'}                   = $self->source;
  $summary{'start'}                    = $self->seq_region_start;
  $summary{'end'}                      = $self->seq_region_end;
  $summary{'strand'}                   = $self->strand;
  $summary{'id'}                       = $id;
  $summary{'Parent'}                   = $parent_gene->stable_id;
  $summary{'biotype'}                  = $self->biotype;
  $summary{'version'}                  = $self->version;
  $summary{'Name'}                     = $self->external_name;
  my $havana_transcript = $self->havana_transcript();
  $summary{'havana_transcript'}        = $havana_transcript->display_id() if $havana_transcript;
  $summary{'havana_version'}           = $havana_transcript->version() if $havana_transcript;
  $summary{'ccdsid'}                   = $self->ccds->display_id if $self->ccds;
  $summary{'transcript_id'}            = $id;
  $summary{'transcript_support_level'} = $self->tsl if $self->tsl;

  my @tags;
  push(@tags, 'basic') if $self->gencode_basic();
  push(@tags, 'Ensembl_canonical') if $self->is_canonical();

  # A transcript can have different types of MANE-related attributes (MANE_Select, MANE_Plus_Clinical)
  # We depend on the Bio::EnsEMBL::MANE object to get the specific type
  my $mane = $self->mane_transcript();
  if ($mane) {
    my $mane_type = $mane->type();
    push(@tags, $mane_type) if ($mane_type);
  }

  $summary{'tag'} = \@tags if @tags;

  # Add xrefs
  if ($add_xrefs) {
    my $xrefs = $self->get_all_xrefs();
    my (@db_xrefs, @go_xrefs);
    foreach my $xref (sort {$a->dbname cmp $b->dbname} @$xrefs) {
      my $dbname = $xref->dbname;
      if ($dbname eq 'GO') {
        push @go_xrefs, "$dbname:".$xref->display_id;
      } else {
        $dbname =~ s/^RefSeq.*/RefSeq/;
        $dbname =~ s/^Uniprot.*/UniProtKB/;
        $dbname =~ s/^protein_id.*/NCBI_GP/;
        push @db_xrefs,"$dbname:".$xref->display_id;
      }
    }
    $summary{'Dbxref'} = \@db_xrefs if scalar(@db_xrefs);
    $summary{'Ontology_term'} = \@go_xrefs if scalar(@go_xrefs);
  }

  return \%summary;
}

sub _generate_file_name {
  my ($self) = @_;

  # File name format looks like:
  # <species>.<assembly>.<release>.gff3.gz
  # e.g. Homo_sapiens.GRCh37.71.gff3.gz
  my @name_bits;
  push @name_bits, $self->web_name();
  push @name_bits, $self->assembly();
  push @name_bits, $self->param('release');
  push @name_bits, 'gff3', 'gz';

  my $file_name = join( '.', @name_bits );
  my $path = $self->create_dir('gff3');

  return File::Spec->catfile($path, $file_name);

}

sub _generate_abinitio_file_name {
  my ($self) = @_;

  # File name format looks like:
  # <species>.<assembly>.<release>.gff3.gz
  # e.g. Homo_sapiens.GRCh38.81.abinitio.gff3.gz
  my @name_bits;
  push @name_bits, $self->web_name();
  push @name_bits, $self->assembly();
  push @name_bits, $self->param('release');
  push @name_bits, 'abinitio', 'gff3', 'gz';

  my $file_name = join( '.', @name_bits );
  my $path = $self->create_dir('gff3');

  return File::Spec->catfile($path, $file_name);

}

sub write_output {
  my ($self) = @_;

  foreach my $out_file (@{$self->param('out_files')}) {
    $self->dataflow_output_id({out_file => $out_file}, 1);
  }
}

sub _create_README {
  my ($self) = @_;
  my $species = $self->scientific_name();

  my $readme = <<README;
#### README ####

-----------------------
GFF FLATFILE DUMPS
-----------------------
Gene annotation is provided in GFF3 format. Detailed specification of
the format is maintained by the Sequence Ontology:
https://github.com/The-Sequence-Ontology/Specifications/blob/master/gff3.md

GFF3 files are validated using GenomeTools: http://genometools.org

For chromosomal assemblies, in addition to a file containing all
genes, there are per-chromosome files. If a predicted geneset is
available (generated by Genscan and other ab initio tools), these
genes are in a separate 'abinitio' file.


The 'type' of gene features is:
 * "gene" for protein-coding genes
 * "ncRNA_gene" for RNA genes
 * "pseudogene" for pseudogenes
The 'type' of transcript features is:
 * "mRNA" for protein-coding transcripts
 * a specific type or RNA transcript such as "snoRNA" or "lnc_RNA"
 * "pseudogenic_transcript" for pseudogenes
All transcripts are linked to "exon" features.
Protein-coding transcripts are linked to "CDS", "five_prime_UTR", and
"three_prime_UTR" features.

Attributes for feature types:
(square brackets indicate data which is not available for all features)
 * region types:
    * ID: Unique identifier, format "<region_type>:<region_name>"
    * [Alias]: A comma-separated list of aliases, usually including the
      INSDC accession
    * [Is_circular]: Flag to indicate circular regions
 * gene types:
    * ID: Unique identifier, format "gene:<gene_stable_id>"
    * biotype: Ensembl biotype, e.g. "protein_coding", "pseudogene"
    * gene_id: Ensembl gene stable ID
    * version: Ensembl gene version
    * [Name]: Gene name
    * [description]: Gene description
 * transcript types:
    * ID: Unique identifier, format "transcript:<transcript_stable_id>"
    * Parent: Gene identifier, format "gene:<gene_stable_id>"
    * biotype: Ensembl biotype, e.g. "protein_coding", "pseudogene"
    * transcript_id: Ensembl transcript stable ID
    * version: Ensembl transcript version
    * [Note]: If the transcript sequence has been edited (i.e. differs
      from the genomic sequence), the edits are described in a note.
 * exon
    * Parent: Transcript identifier, format "transcript:<transcript_stable_id>"
    * exon_id: Ensembl exon stable ID
    * version: Ensembl exon version
    * constitutive: Flag to indicate if exon is present in all
      transcripts
    * rank: Integer that show the 5'->3' ordering of exons
 * CDS
    * ID: Unique identifier, format "CDS:<protein_stable_id>"
    * Parent: Transcript identifier, format "transcript:<transcript_stable_id>"
    * protein_id: Ensembl protein stable ID
    * version: Ensembl protein version

Metadata:
 * genome-build - Build identifier of the assembly e.g. GRCh37.p11
 * genome-version - Version of this assembly e.g. GRCh37
 * genome-date - The date of the release of this assembly e.g. 2009-02
 * genome-build-accession - Genome accession e.g. GCA_000001405.14
 * genebuild-last-updated - Date of the last genebuild update e.g. 2013-09

-----------
FILE NAMES
------------
The files are consistently named following this pattern:
   <species>.<assembly>.<_version>.gff3.gz

<species>:       The systematic name of the species. 
<assembly>:      The assembly build name.
<version>:       The version of Ensembl from which the data was exported.
gff3 : All files in these directories are in GFF3 format
gz : All files are compacted with GNU Zip for storage efficiency.

e.g. 
Homo_sapiens.GRCh38.81.gff3.gz

For the predicted gene set, an additional abinitio flag is added to the name file.
<species>.<assembly>.<version>.abinitio.gff3.gz

e.g.
Homo_sapiens.GRCh38.81.abinitio.gff3.gz

------------------
Example GFF3 output
------------------

##gff-version 3
#!genome-build  Pmarinus_7.0
#!genome-version Pmarinus_7.0
#!genome-date 2011-01
#!genebuild-last-updated 2013-04

GL476399        Pmarinus_7.0    supercontig     1       4695893 .       .       .       ID=supercontig:GL476399;Alias=scaffold_71
GL476399        ensembl gene    2596494 2601138 .       +       .       ID=gene:ENSPMAG00000009070;Name=TRYPA3;biotype=protein_coding;description=Trypsinogen A1%3B Trypsinogen a3%3B Uncharacterized protein  [Source:UniProtKB/TrEMBL%3BAcc:O42608];logic_name=ensembl;version=1
GL476399        ensembl transcript      2596494 2601138 .       +       .       ID=transcript:ENSPMAT00000010026;Name=TRYPA3-201;Parent=gene:ENSPMAG00000009070;biotype=protein_coding;version=1
GL476399        ensembl exon    2596494 2596538 .       +       .       Name=ENSPMAE00000087923;Parent=transcript:ENSPMAT00000010026;constitutive=1;ensembl_end_phase=1;ensembl_phase=-1;rank=1;version=1
GL476399        ensembl exon    2598202 2598361 .       +       .       Name=ENSPMAE00000087929;Parent=transcript:ENSPMAT00000010026;constitutive=1;ensembl_end_phase=2;ensembl_phase=1;rank=2;version=1
GL476399        ensembl exon    2599023 2599282 .       +       .       Name=ENSPMAE00000087937;Parent=transcript:ENSPMAT00000010026;constitutive=1;ensembl_end_phase=1;ensembl_phase=2;rank=3;version=1
GL476399        ensembl exon    2599814 2599947 .       +       .       Name=ENSPMAE00000087952;Parent=transcript:ENSPMAT00000010026;constitutive=1;ensembl_end_phase=0;ensembl_phase=1;rank=4;version=1
GL476399        ensembl exon    2600895 2601138 .       +       .       Name=ENSPMAE00000087966;Parent=transcript:ENSPMAT00000010026;constitutive=1;ensembl_end_phase=-1;ensembl_phase=0;rank=5;version=1
GL476399        ensembl CDS     2596499 2596538 .       +       0       ID=CDS:ENSPMAP00000009982;Parent=transcript:ENSPMAT00000010026
GL476399        ensembl CDS     2598202 2598361 .       +       2       ID=CDS:ENSPMAP00000009982;Parent=transcript:ENSPMAT00000010026
GL476399        ensembl CDS     2599023 2599282 .       +       1       ID=CDS:ENSPMAP00000009982;Parent=transcript:ENSPMAT00000010026
GL476399        ensembl CDS     2599814 2599947 .       +       2       ID=CDS:ENSPMAP00000009982;Parent=transcript:ENSPMAT00000010026
GL476399        ensembl CDS     2600895 2601044 .       +       0       ID=CDS:ENSPMAP00000009982;Parent=transcript:ENSPMAT00000010026
GL476399        ensembl five_prime_UTR  2596494 2596498 .       +       .       Parent=transcript:ENSPMAT00000010026
GL476399        ensembl three_prime_UTR 2601045 2601138 .       +       .       Parent=transcript:ENSPMAT00000010026

README

  if ($species eq 'Homo sapiens') {
    $readme .= "
--------------------------------------
Locus Reference Genomic Sequence (LRG)
--------------------------------------
This is a manually curated project that contains stable and un-versioned reference sequences designed specifically for reporting sequence variants with clinical implications.
The sequences of each locus (also called LRG) are chosen in collaboration with research and diagnostic laboratories, LSDB (locus specific database) curators and mutation consortia with expertise in the region of interest.
LRG website: http://www.lrg-sequence.org
LRG data are freely available in several formats (FASTA, BED, XML, Tabulated) at this address: http://www.lrg-sequence.org/downloads
    ";
  }

  my $path = File::Spec->catfile($self->get_dir('gff3'), 'README');
  work_with_file($path, 'w', sub {
    my ($fh) = @_;
    print $fh $readme;
    return;
  });
  return;
}

1;

