==============================
ENSEMBL RAPID RELEASE FTP SITE
==============================


The latest data is always available via a directory prefixed "current_".
For example "current_fasta" will always point to the latest data files in FASTA format.

The FTP directory has the following basic structure, although not all information is available for each species.

|-- assembly_chain 	Chain files for mapping between species assemblies
|    |
|    |-- <species>
|
|-- bamcov  BAM and bigWig files derived by aligning RNASeq data to the genome
|    |
|    |-- <species>
|         |
|         |-- genebuild
|
|-- bed  GERP constrained element data in BED format
|    |
|    |-- ensembl_compara
|         |
|         |-- <multiple sequence alignment>
|
|-- blat  2bit DNA files for use with BLAT
|    |
|    |-- dna
|
|-- compara  TreeFam HMM families
|    |
|    |-- conservation_scores  GERP constrained element data in BED format
|    |    |
|    |    |-- <multiple sequence alignment>
|    |
|    |-- species_trees  Newick tree format files that underlie comparative analyses
|
|-- data_files  Alignment data files from a variety of sources
|    |
|    |-- <species>
|         |
|         |-- <assembly>
|              |
|              |-- external_feature_file
|              |
|              |-- funcgen
|              |
|              |-- rnaseq
|
|-- embl  Annotations on genomic DNA in EMBL format
|    |
|    |-- <species>
|
|-- emf  Alignments in EMF format
|    |
|    |-- ensembl_compara
|         |
|         |-- homologies  Gene trees and protein alignments underlying othology and paralogy
|         |
|         |-- multiple_alignments  Whole genome multiple alignments with conservation scores
|              |
|              |-- <multiple sequence alignment>
|   
|-- fasta  Sequences and annotations in FASTA format
|    |
|    |-- ancestral alleles  Predictions of ancestral alleles (coordinates correspond to each extant species)   
|    |
|    |-- <species>
|         |
|         |-- cdna       Transcript sequences (protein-coding and pseudogene)
|	        |-- cds        Coding sequences
|         |-- dna        Genomic DNA
|         |-- dna_index  Genomic DNA, compressed using bgzip, with an HTSLib index
|         |-- ncrna      Transcript sequences (non-coding RNA)
|         |-- pep        Translation (peptide) sequences
|
|-- genbank  Annotations on genomic DNA in GenBank format
|    |
|    |-- <species>
|
|-- gff3  Gene annotation in GFF3 format
|    |
|    |-- <species>
|
|-- gtf  Gene annotation in GTF format
|    |
|    |-- <species>
|
|-- json  Genome and annotation data in JSON format
|    |
|    |-- <species>
|
|-- maf  Alignment dumps in MAF format
|    |
|    |-- ensembl-compara
|         |
|         |-- multiple_alignments  EPO and Pecan alignments
|         |    |
|         |    |-- <multiple sequence alignment>
|         |
|         |-- pairwise_alignments  LastZ pairwise alignments
|              |
|              |-- <pairwise alignment>
|
|-- mysql  MySQL database per-table text files
|    |
|    |-- <core database>  General genome and annotation information
|    |
|    |-- <cdna database>  cDNA to genome alignments
|    |
|    |-- <otherfeatures database>  Supplementary annotation information
|    |
|    |-- <rnaseq database>  RNASeq alignments and gene models
|    |
|    |-- <funcgen database>  Probe-mapping and regulatory data
|    |
|    |-- <variation database>  Variation data
|    |
|    |-- ensembl_accounts  Schema-only copy of the database used to manage Ensembl user accounts
|    |
|    |-- ensembl_ancestral_<release>  Predictions of ancestral alleles
|    |
|    |-- ensembl_archive_<release>  Data on historical Ensembl releases
|    |
|    |-- ensembl_compara_<release>  Comparative genomics: Homology, protein families, whole genome alignments, synteny
|    |
|    |-- ensembl_metadata_<release>  Genome and assembly data
|    |
|    |-- ensembl_ontology_<release>  Ontologies used in Ensembl
|    |
|    |-- ensembl_production_<release>  Controlled vocabularies for Ensembl databases
|    |
|    |-- ensembl_stable_ids_<release>  Stable ID lookups, used in search
|    |
|    |-- ensembl_website_<release>  Information used to build Ensembl websites
|    |
|    |-- ensembl_mart_<release>  BioMart database for genes
|    |
|    |-- genomic_features_mart_<release>  BioMart database for genomic annotations
|    |
|    |-- ontology_mart_<release>  BioMart database for ontologies
|    |
|    |-- regulation_mart_<release>  BioMart database for regulatory data
|    |
|    |-- sequence_mart_<release>  BioMart database for DNA and amino acid sequences
|    |
|    |-- snp_mart_<release>  BioMart database for variation data (including structural variation)
|
|-- ncbi_blast
|    |
|    |-- genes
|    |
|    |-- genomic
|
|-- new_genomes.txt  Summary of new genome assemblies in this release
|
|-- regulation  Files relating to the Ensembl Regulatory build (human and mouse only)
|    |
|    |-- <species>
|
|-- removed_genomes.txt  Summary of removed genome assemblies in this release
|
|-- renamed_genomes.txt  Summary of renamed genome assemblies in this release
|
|-- species_EnsemblVertebrates.txt  Summary of all genome assemblies in this release
|
|-- species_metadata_EnsemblVertebrates.json  Summary of removed genome assemblies in this release
|
|-- species_metadata_EnsemblVertebrates.xml  Summary of removed genome assemblies in this release
|
|-- summary.txt  Genome assembly counts for this release
|
|-- tsv  Cross references from Ensembl genes, transcripts and translations to ENA, RefSeq, and UniProt
|    |
|    |-- <species>
|
|-- uniprot_report_EnsemblVertebrates.txt  Summary of UniProt coverage for all genome assemblies
|
|-- updated_annotations.txt  Summary of existing genome assemblies which have new gene annotations in this release
|
|-- updated_assemblies.txt  Summary of existing genomes which have new assemblies in this release
|
|-- variation  Variation data and VEP cache files
|    |
|    |-- gvf  Variations in GVF format
|    |    |
|    |    |-- <species>
|    |
|    |-- indexed_vep_cache  Cache files for use with VEP, compressed using bgzip
|    |
|    |-- vcf  Variations in VCF format
|    |    |
|    |    |-- <species>
|    |
|    |-- vep  Cache files for use with VEP, compressed using gzip
|
|-- virtual machine  Ensembl virtual machine
|
|-- xml  Gene tree and orthology files in PhyloXML and OrthoXML formats
     |
     |-- ensembl-compara
          |
          |-- homologies  Gene trees and protein alignments underlying othology and paralogy

#######################
Fasta DNA dumps
#######################

-----------
FILE NAMES
------------
The files are consistently named following this pattern:
   <species>.<assembly>.<sequence type>.<id type>.<id>.fa.gz

<species>:   The systematic name of the species.
<assembly>:  The assembly build name.
<sequence type>:
 * 'dna' - unmasked genomic DNA sequences.
  * 'dna_rm' - masked genomic DNA.  Interspersed repeats and low
     complexity regions are detected with the RepeatMasker tool and masked
     by replacing repeats with 'N's.
  * 'dna_sm' - soft-masked genomic DNA. All repeats and low complexity regions
    have been replaced with lowercased versions of their nucleic base
<id type> One of the following:
  * 'chromosome'     - The top-level coordinate system in most species in Ensembl
  * 'nonchromosomal' - Contains DNA that has not been assigned a chromosome
  * 'seqlevel'       - This is usually sequence scaffolds, chunks or clones.
     -- 'scaffold'   - Larger sequence contigs from the assembly of shorter
        sequencing reads (often from whole genome shotgun, WGS) which could
        not yet be assembled into chromosomes. Often more genome sequencing
        is needed to narrow gaps and establish a tiling path.
     -- 'chunk' -  While contig sequences can be assembled into large entities,
        they sometimes have to be artificially broken down into smaller entities
        called 'chunks'. This is due to limitations in the annotation
        pipeline and the finite record size imposed by MySQL which stores the
        sequence and annotation information.
     -- 'clone' - In general this is the smallest sequence entity.  It is often
        identical to the sequence of one BAC clone, or sequence region
        of one BAC clone which forms the tiling path.
<id>:     The actual sequence identifier. Depending on the <id type> the <id>
          could represent the name of a chromosome, a scaffold, a contig, a clone ..
          Field is empty for seqlevel files
fa: All files in these directories represent FASTA database files
gz: All files are compacted with GNU Zip for storage efficiency.


EXAMPLES
   The genomic sequence of human chromosome 1:
     Homo_sapiens.GRCh37.dna.chromosome.1.fa.gz

   The masked version of the genome sequence on human chromosome 1
   (contains '_rm' or '_sm' in the name):
     Homo_sapiens.GRCh37.dna_rm.chromosome.1.fa.gz
     Homo_sapiens.GRCh37.dna_sm.chromosome.1.fa.gz

   Non-chromosomal assembly sequences:
   e.g. mitochondrial genome, sequence contigs not yet mapped on chromosomes
     Homo_sapiens.GRCh37.dna.nonchromosomal.fa.gz
     Homo_sapiens.GRCh37.dna_rm.nonchromosomal.fa.gz
     Homo_sapiens.GRCh37.dna_sm.nonchromosomal.fa.gz

---------
TOPLEVEL
---------
These files contains all sequence regions flagged as toplevel in an Ensembl
schema. This includes chromsomes, regions not assembled into chromosomes and
N padded haplotype/patch regions.

EXAMPLES

  Toplevel sequences unmasked:
    Homo_sapiens.GRCh37.dna.toplevel.fa.gz
  
  Toplevel soft/hard masked sequences:
    Homo_sapiens.GRCh37.dna_sm.toplevel.fa.gz
    Homo_sapiens.GRCh37.dna_rm.toplevel.fa.gz

-----------------
PRIMARY ASSEMBLY
-----------------
Primary assembly contains all toplevel sequence regions excluding haplotypes
and patches. This file is best used for performing sequence similarity searches
where patch and haplotype sequences would confuse analysis. If the primary
assembly file is not present, that indicates that there are no haplotype/patch
regions, and the 'toplevel' file is equivalent.

EXAMPLES

  Primary assembly sequences unmasked:
    Homo_sapiens.GRCh37.dna.primary_assembly.fa.gz
  
  Primary assembly soft/hard masked sequences:
    Homo_sapiens.GRCh37.dna_sm.primary_assembly.fa.gz
    Homo_sapiens.GRCh37.dna_rm.primary_assembly.fa.gz

--------------
SPECIAL CASES
--------------
Some chromosomes have alternate haplotypes which are presented in files with 
the haplotype sequence only:
   Homo_sapiens.GRCh37.dna_rm.chromosome.HSCHR6_MHC_QBL.fa.gz
   Homo_sapiens.GRCh37.dna_rm.chromosome.HSCHR17_1.fa.gz

All alternative assembly and patch regions have their sequence padded 
with N's to ensure alignment programs can report the correct index
regions

e.g. A patch region with a start position of 1,000,001 will have 1e6 N's added
its start so an alignment program will report coordinates with respect to the
whole chromosome.

Human has sequenced Y chromosomes and the pseudoautosomal region (PAR)
on the Y is annotated.  By definition the PAR region is identical on the 
X and Y chromosome.  The Y chromosome file contains the Y chromsome 
minus these repeated PAR regions i.e. the unique portion of Y.

####################
Fasta Peptide dumps
####################
These files hold the protein translations of Ensembl genes.

-----------
FILE NAMES
------------
The files are consistently named following this pattern:
   <species>.<assembly>.<sequence type>.<status>.fa.gz

<species>:       The systematic name of the species.
<assembly>:      The assembly build name.
<sequence type>: pep for peptide sequences
<status>
  * 'pep.all' - all translations resulting from Ensembl genes.
  * 'pep.abinitio' translations resulting from 'ab initio' gene
     prediction algorithms such as SNAP and GENSCAN. In general, all
     'ab initio' predictions are based solely on the genomic sequence and
     not any other experimental evidence. Therefore, not all GENSCAN
     or SNAP predictions represent biologically real proteins.
fa : All files in these directories represent FASTA database files
gz : All files are compacted with GNU Zip for storage efficiency.

EXAMPLES (Note: Not all species have 'pep.abinitio' data)
 for Human:
    Homo_sapiens.NCBI36.pep.all.fa.gz
      contains all annotated peptides
    Homo_sapiens.NCBI36.pep.abinitio.fa.gz
      contains all abinitio predicted peptide

-------------------------------
FASTA Sequence Header Lines
------------------------------
The FASTA sequence header lines are designed to be consistent across
all types of Ensembl FASTA sequences.

Stable IDs for genes, transcripts, and translations are suffixed with
a version if they have been generated by Ensembl (this is typical for
vertebrate species, but not for non-vertebrates).
All ab initio data is unversioned.

General format:

>TRANSLATION_ID SEQTYPE LOCATION GENE_ID TRANSCRIPT_ID GENE_BIOTYPE TRANSCRIPT_BIOTYPE

Example of Ensembl Peptide header:

>ENSP00000328693.1 pep chromosome:NCBI35:1:904515:910768:1 gene:ENSG00000158815.1 transcript:ENST00000328693.1 gene_biotype:protein_coding transcript_biotype:protein_coding
 ^                 ^   ^                                   ^                      ^                            ^                           ^
 TRANSLATION_ID    |   LOCATION                            GENE_ID                TRANSCRIPT_ID                GENE_BIOTYPE                TRANSCRIPT_BIOTYPE
                SEQTYPE

##################
Fasta cDNA dumps
#################

These files hold the cDNA sequences corresponding to Ensembl genes,
excluding ncRNA genes, which are in a separate 'ncrna' Fasta file.
cDNA consists of transcript sequences for actual and possible
genes, including pseudogenes, NMD and the like. See the file names 
explanation below for different subsets of both known and predicted 
transcripts.

------------
FILE NAMES
------------
The files are consistently named following this pattern:
<species>.<assembly>.<sequence type>.<status>.fa.gz

<species>: The systematic name of the species.
<assembly>: The assembly build name.
<sequence type>: cdna for cDNA sequences
<status>
  * 'cdna.all' - all transcripts of Ensembl genes, excluding ncRNA.
  * 'cdna.abinitio' - transcripts resulting from 'ab initio' gene prediction
     algorithms such as SNAP and GENSCAN. In general all 'ab initio'
     predictions are solely based on the genomic sequence and do not
     use other experimental evidence. Therefore, not all GENSCAN or SNAP
     cDNA predictions represent biologically real cDNAs.
     Consequently, these predictions should be used with care.

EXAMPLES  (Note: Not all species have 'cdna.abinitio' data)
  for Human:
    Homo_sapiens.NCBI36.cdna.all.fa.gz
      cDNA sequences for all transcripts
    Homo_sapiens.NCBI36.cdna.abinitio.fa.gz
      cDNA sequences for 'ab initio' prediction transcripts.

------------------------------
FASTA Sequence Header Lines
------------------------------
The FASTA sequence header lines are designed to be consistent across
all types of Ensembl FASTA sequences.

Stable IDs for genes and transcripts are suffixed with
a version if they have been generated by Ensembl (this is typical for
vertebrate species, but not for non-vertebrates).
All ab initio data is unversioned.

General format:

>TRANSCRIPT_ID SEQTYPE LOCATION GENE_ID GENE_BIOTYPE TRANSCRIPT_BIOTYPE

Example of an Ensembl cDNA header:

>ENST00000289823.1 cdna chromosome:NCBI35:8:21922367:21927699:1 gene:ENSG00000158815.1 gene_biotype:protein_coding transcript_biotype:protein_coding
 ^                 ^    ^                                       ^                      ^                           ^
 TRANSCRIPT_ID     |    LOCATION                                GENE_ID                GENE_BIOTYPE                TRANSCRIPT_BIOTYPE
                SEQTYPE

##################
Fasta cds dumps
#################

These files hold the coding sequences corresponding to Ensembl genes.
CDS does not contain UTR or intronic sequence.

------------
FILE NAMES
------------
The files are consistently named following this pattern:
<species>.<assembly>.<sequence type>.<status>.fa.gz

<species>: The systematic name of the species.
<assembly>: The assembly build name.
<sequence type>: cds for CDS sequences
<status>
  * 'cds.all' - all transcript coding sequences resulting from Ensembl genes.

EXAMPLES
  for Human:
    Homo_sapiens.NCBI37.cds.all.fa.gz
      cds sequences for all protein-coding transcripts

-------------------------------
FASTA Sequence Header Lines
------------------------------
The FASTA sequence header lines are designed to be consistent across
all types of Ensembl FASTA sequences.

Stable IDs for genes and transcripts are suffixed with
a version if they have been generated by Ensembl (this is typical for
vertebrate species, but not for non-vertebrates).
All ab initio data is unversioned.

General format:

>TRANSCRIPT_ID SEQTYPE LOCATION GENE_ID GENE_BIOTYPE TRANSCRIPT_BIOTYPE

Example of an Ensembl CDS header:

>ENST00000525148.1 cds chromosome:GRCh37:11:66188562:66193526:1 gene:ENSG00000174576.1 gene_biotype:protein_coding transcript_biotype:nonsense_mediated_decay
 ^                 ^   ^                                        ^                      ^                           ^
 TRANSCRIPT_ID     |   LOCATION                                 GENE_ID                GENE_BIOTYPE                TRANSCRIPT_BIOTYPE
                SEQTYPE

-----------------------
$format FLATFILE DUMPS
-----------------------
This directory contains $species $format flatfile dumps. To ease
downloading of the files, the $format format entries are bundled 
into groups of chromosomes and non-chromosomal regions.  
All files are then compacted with gzip.

$format flat files include gene annotation and cross-references
to other data sources such as UniProt and GO.

The main body of the entry gives the same information as is in the main 
$format flat file entry.

    * ID - the $format id
    * AC - the EMBL/GenBank/DDBJ accession number (only the primary 
           accession number used)
    * SV - The accession.version pair which gives the exact reference to 
           a particular sequence
    * CC - comment lines to help you interpret the entry 

Genes, transcripts, translations and exons are dumped into the
feature table of the Ensembl entry. Stable IDs for these features
are suffixed with a version if they have been generated by Ensembl
(this is typical for vertebrate species, but not for non-vertebrates).

    * Genes are 'gene' entries, with the gene stable ID as the 'gene'
      property

    * Transcripts are 'mRNA' entries, with the gene stable ID as the
      'gene' property, and the transcript stable ID as the
      'standard_name' property.

    * Translations are 'CDS' entries, with the gene stable ID as the
      'gene' property, the translation stable ID as the 'protein_id'
      property, and the amino acid sequences as the 'translation'
      property.

    * Exons are 'exon' entries.

-----------------------
GFF FLATFILE DUMPS
-----------------------
This directory contains GFF flatfile dumps. All files are compressed
using GNU Zip.

Ensembl provides an automatic gene annotation for $species.
For some species ( human, mouse, zebrafish, pig and rat), the
annotation provided through Ensembl also includes manual annotation
from HAVANA.
In the case of human and mouse, the GTF files found here are equivalent
to the GENCODE gene set.

GFF3 flat file format dumping provides all the sequence features known by
Ensembl, including protein coding genes, ncRNA, repeat features etc.
Annotation is based on alignments of biological evidence (eg. proteins,
cDNAs, RNA-seq) to a genome assembly. Annotation is based on alignments of
biological evidence (eg. proteins, cDNAs, RNA-seq) to a genome assembly.
The annotation dumped here is transcribed and translated from the
genome assembly and is not the original input sequence data that
we used for alignment. Therefore, the sequences provided by Ensembl
may differ from the original input sequence data where the genome
assembly is different to the aligned sequence.
Considerably more information is stored in Ensembl: the flat file 
just gives a representation which is compatible with existing tools.

We are considering other information that should be made dumpable. In 
general we would prefer people to use database access over flat file 
access if you want to do something serious with the data. 

Note the following features of the GFF3 format provided on this site:
1) types are described using SO terms that are as specific as possible.
e.g. protein_coding_gene is used where a gene is known to be protein coding
2) Phase is currently set to 0 - the phase used by the Ensembl system
is stored as an attribute
3) Some validators may warn about duplicated identifiers for CDS features. 
This is to allow split features to be grouped.

We are actively working to improve our GFF3 so some of these issues may
be addressed in future releases of Ensembl.

Additionally, we provide a GFF3 file containing the predicted gene set
as generated by Genscan and other abinitio prediction tools.
This file is identified by the abinitio extension.

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

--------------------------------
Definition and supported options
--------------------------------

GFF3 files are nine-column, tab-delimited, plain text files. Literal use of tab,
newline, carriage return, the percent (%) sign, and control characters must be
encoded using RFC 3986 Percent-Encoding; no other characters may be encoded.
Backslash and other ad-hoc escaping conventions that have been added to the GFF
format are not allowed. The file contents may include any character in the set
supported by the operating environment, although for portability with other
systems, use of Latin-1 or Unicode are recommended.

Fields

Fields are tab-separated. Also, all but the final field in each feature line
must contain a valu; "empty" columns are denoted with a '.'

   seqid     - The ID of the landmark used to establish the coordinate system for the current
               feature. IDs may contain any characters, but must escape any characters not in
               the set [a-zA-Z0-9.:^*$@!+_?-|]. In particular, IDs may not contain unescaped
               whitespace and must not begin with an unescaped ">".
   source    - The source is a free text qualifier intended to describe the algorithm or
               operating procedure that generated this feature. Typically this is the name of a
               piece of software, such as "Genescan" or a database name, such as "Genbank." In
               effect, the source is used to extend the feature ontology by adding a qualifier
               to the type creating a new composite type that is a subclass of the type in the
               type column.
   type      - The type of the feature (previously called the "method"). This is constrained to
               be either: (a)a term from the "lite" version of the Sequence Ontology - SOFA, a
               term from the full Sequence Ontology - it must be an is_a child of
               sequence_feature (SO:0000110) or (c) a SOFA or SO accession number. The latter
               alternative is distinguished using the syntax SO:000000.
   start     - start position of the feature in positive 1-based integer coordinates
               always less than or equal to end
   end       - end position of the feature in positive 1-based integer coordinates
   score     - The score of the feature, a floating point number. As in earlier versions of the
               format, the semantics of the score are ill-defined. It is strongly recommended
               that E-values be used for sequence similarity features, and that P-values be
               used for ab initio gene prediction features.
   strand    - The strand of the feature. + for positive strand (relative to the landmark), -
               for minus strand, and . for features that are not stranded. In addition, ? can
               be used for features whose strandedness is relevant, but unknown.
   phase     - For features of type "CDS", the phase indicates where the feature begins with
               reference to the reading frame. The phase is one of the integers 0, 1, or 2,
               indicating the number of bases that should be removed from the beginning of this
               feature to reach the first base of the next codon. In other words, a phase of
               "0" indicates that the next codon begins at the first base of the region
               described by the current line, a phase of "1" indicates that the next codon
               begins at the second base of this region, and a phase of "2" indicates that the
               codon begins at the third base of this region. This is NOT to be confused with
               the frame, which is simply start modulo 3.
   attribute - A list of feature attributes in the format tag=value. Multiple tag=value pairs
               are separated by semicolons. URL escaping rules are used for tags or values
               containing the following characters: ",=;". Spaces are allowed in this field,
               but tabs must be replaced with the %09 URL escape. Attribute values do not need
               to be and should not be quoted. The quotes should be included as part of the
               value by parsers and not stripped.


Attributes

The following attributes are available. All attributes are semi-colon separated
pairs of keys and values.

- ID:     ID of the feature. IDs for each feature must be unique within the
          scope of the GFF file. In the case of discontinuous features (i.e. a single
          feature that exists over multiple genomic locations) the same ID may appear on
          multiple lines. All lines that share an ID collectively represent a single
          feature.
- Name:   Display name for the feature. This is the name to be displayed to the user.
- Alias:  A secondary name for the feature
- Parent: Indicates the parent of the feature. A parent ID can be used to group exons into
          transcripts, transcripts into genes, and so forth
- Dbxref: A database cross reference
- Ontology_term: A cross reference to an ontology term
- Is_circular:   A flag to indicate whether a feature is circular

Pragmas/Metadata

GFF3 files can contain meta-data. In the case of experimental meta-data these are
noted by a #!. Those which are stable are noted by a ##. Meta data is a single key,
a space and then the value. Current meta data keys are:

* genome-build -  Build identifier of the assembly e.g. GRCh37.p11
* genome-version - Version of this assembly e.g. GRCh37
* genome-date - The date of the release of this assembly e.g. 2009-02
* genome-build-accession - The accession and source of this accession e.g. NCBI:GCA_000001405.14
* genebuild-last-updated - The date of the last genebuild update e.g. 2013-09

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

--------
GTF DUMP
--------

This directory includes a summary of the gene annotation information 
and GTF format.

Ensembl provides an automatic gene annotation for $species.
For some species ( human, mouse, zebrafish, pig and rat), the
annotation provided through Ensembl also includes manual annotation
from HAVANA.
In the case of human and mouse, the GTF files found here are equivalent
to the GENCODE gene set.

GTF provides access to all annotated transcripts which make
up an Ensembl gene set. Annotation is based on alignments of
biological evidence (eg. proteins, cDNAs, RNA-seq) to a genome assembly.
The annotation dumped here is transcribed and translated from the 
genome assembly and is not the original input sequence data that 
we used for alignment. Therefore, the sequences provided by Ensembl 
may differ from the original input sequence data where the genome 
assembly is different to the aligned sequence. 

Additionally, we provide a GTF file containing the predicted gene set
as generated by Genscan and other abinitio prediction tools.
This file is identified by the abinitio extension.


-----------
FILE NAMES
------------
The files are consistently named following this pattern:
   <species>.<assembly>.<version>.gtf.gz

<species>:       The systematic name of the species.
<assembly>:      The assembly build name.
<version>:       The version of Ensembl from which the data was exported.
gtf : All files in these directories are in GTF format
gz : All files are compacted with GNU Zip for storage efficiency.

e.g.
Homo_sapiens.GRCh38.81.gtf.gz

For the predicted gene set, an additional abinitio flag is added to the name file.
<species>.<assembly>.<version>.abinitio.gtf.gz

e.g.
Homo_sapiens.GRCh38.81.abinitio.gtf.gz

--------------------------------
Definition and supported options
--------------------------------

The GTF (General Transfer Format) is an extension of GFF version 2 
and used to represent transcription models. GFF (General Feature Format) 
consists of one line per feature, each containing 9 columns of data. 

Fields

Fields are tab-separated. Also, all but the final field in each 
feature line must contain a value; "empty" columns are denoted 
with a '.'

    seqname   - name of the chromosome or scaffold; chromosome names 
                without a 'chr' 
    source    - name of the program that generated this feature, or 
                the data source (database or project name)
    feature   - feature type name. Current allowed features are
                {gene, transcript, exon, CDS, Selenocysteine, start_codon,
                stop_codon and UTR}
    start     - start position of the feature, with sequence numbering 
                starting at 1.
    end       - end position of the feature, with sequence numbering 
                starting at 1.
    score     - a floating point value indiciating the score of a feature
    strand    - defined as + (forward) or - (reverse).
    frame     - one of '0', '1' or '2'. Frame indicates the number of base pairs
                before you encounter a full codon. '0' indicates the feature 
                begins with a whole codon. '1' indicates there is an extra
                base (the 3rd base of the prior codon) at the start of this feature.
                '2' indicates there are two extra bases (2nd and 3rd base of the 
                prior exon) before the first codon. All values are given with
                relation to the 5' end.
    attribute - a semicolon-separated list of tag-value pairs (separated by a space), 
                providing additional information about each feature. A key can be
                repeated multiple times.

Attributes

The following attributes are available. All attributes are semi-colon
separated pairs of keys and values.

- gene_id: The stable identifier for the gene
- gene_version: The stable identifier version for the gene
- gene_name: The official symbol of this gene
- gene_source: The annotation source for this gene
- gene_biotype: The biotype of this gene
- transcript_id: The stable identifier for this transcript
- transcript_version: The stable identifier version for this transcript
- transcript_name: The symbold for this transcript derived from the gene name
- transcript_source: The annotation source for this transcript
- transcript_biotype: The biotype for this transcript
- exon_id: The stable identifier for this exon
- exon_version: The stable identifier version for this exon
- exon_number: Position of this exon in the transcript
- ccds_id: CCDS identifier linked to this transcript
- protein_id: Stable identifier for this transcript's protein
- protein_version: Stable identifier version for this transcript's protein
- tag: A collection of additional key value tags
- transcript_support_level: Ranking to assess how well a transcript is supported (from 1 to 5)

Tags

Tags are additional flags used to indicate attibutes of the transcript.

- CCDS: Flags this transcript as one linked to a CCDS record
- seleno: Flags this transcript has a Selenocysteine edit. Look for the Selenocysteine
feature for the position of this on the genome
- cds_end_NF: the coding region end could not be confirmed
- cds_start_NF: the coding region start could not be confirmed
- mRNA_end_NF: the mRNA end could not be confirmed
- mRNA_start_NF: the mRNA start could not be confirmed.
- basic: the transcript is part of the gencode basic geneset

Comments

Lines may be commented out by the addition of a single # character at the start. These
lines should be ignored by your parser.

Pragmas/Metadata

GTF files can contain meta-data. In the case of experimental meta-data these are 
noted by a #!. Those which are stable are noted by a ##. Meta data is a single key,
a space and then the value. Current meta data keys are:

* genome-build -  Build identifier of the assembly e.g. GRCh37.p11
* genome-version - Version of this assembly e.g. GRCh37
* genome-date - The date of this assembly's release e.g. 2009-02
* genome-build-accession - The accession and source of this accession e.g. NCBI:GCA_000001405.14
* genebuild-last-updated - The date of the last genebuild update e.g. 2013-09

------------------
Example GTF output
------------------

#!genome-build GRCh38
11      ensembl_havana  gene    5422111 5423206 .       +       .       gene_id "ENSG00000167360"; gene_version "4"; gene_name "OR51Q1"; gene_source "ensembl_havana"; gene_biotype "protein_coding";
11      ensembl_havana  transcript      5422111 5423206 .       +       .       gene_id "ENSG00000167360"; gene_version "4"; transcript_id "ENST00000300778"; transcript_version "4"; gene_name "OR51Q1"; gene_source "ensembl_havana"; gene_biotype "protein_coding"; transcript_name "OR51Q1-001"; transcript_source "ensembl_havana"; transcript_biotype "protein_coding"; tag "CCDS"; ccds_id "CCDS31381";
11      ensembl_havana  exon    5422111 5423206 .       +       .       gene_id "ENSG00000167360"; gene_version "4"; transcript_id "ENST00000300778"; transcript_version "4"; exon_number "1"; gene_name "OR51Q1"; gene_source "ensembl_havana"; gene_biotype "protein_coding"; transcript_name "OR51Q1-001"; transcript_source "ensembl_havana"; transcript_biotype "protein_coding"; tag "CCDS"; ccds_id "CCDS31381"; exon_id "ENSE00001276439"; exon_version "4";
11      ensembl_havana  CDS     5422201 5423151 .       +       0       gene_id "ENSG00000167360"; gene_version "4"; transcript_id "ENST00000300778"; transcript_version "4"; exon_number "1"; gene_name "OR51Q1"; gene_source "ensembl_havana"; gene_biotype "protein_coding"; transcript_name "OR51Q1-001"; transcript_source "ensembl_havana"; transcript_biotype "protein_coding"; tag "CCDS"; ccds_id "CCDS31381"; protein_id "ENSP00000300778"; protein_version "4";
11      ensembl_havana  start_codon     5422201 5422203 .       +       0       gene_id "ENSG00000167360"; gene_version "4"; transcript_id "ENST00000300778"; transcript_version "4"; exon_number "1"; gene_name "OR51Q1"; gene_source "ensembl_havana"; gene_biotype "protein_coding"; transcript_name "OR51Q1-001"; transcript_source "ensembl_havana"; transcript_biotype "protein_coding"; tag "CCDS"; ccds_id "CCDS31381";
11      ensembl_havana  stop_codon      5423152 5423154 .       +       0       gene_id "ENSG00000167360"; gene_version "4"; transcript_id "ENST00000300778"; transcript_version "4"; exon_number "1"; gene_name "OR51Q1"; gene_source "ensembl_havana"; gene_biotype "protein_coding"; transcript_name "OR51Q1-001"; transcript_source "ensembl_havana"; transcript_biotype "protein_coding"; tag "CCDS"; ccds_id "CCDS31381";
11      ensembl_havana  UTR     5422111 5422200 .       +       .       gene_id "ENSG00000167360"; gene_version "4"; transcript_id "ENST00000300778"; transcript_version "4"; gene_name "OR51Q1"; gene_source "ensembl_havana"; gene_biotype "protein_coding"; transcript_name "OR51Q1-001"; transcript_source "ensembl_havana"; transcript_biotype "protein_coding"; tag "CCDS"; ccds_id "CCDS31381";
11      ensembl_havana  UTR     5423155 5423206 .       +       .       gene_id "ENSG00000167360"; gene_version "4"; transcript_id "ENST00000300778"; transcript_version "4"; gene_name "OR51Q1"; gene_source "ensembl_havana"; gene_biotype "protein_coding"; transcript_name "OR51Q1-001"; transcript_source "ensembl_havana"; transcript_biotype "protein_coding"; tag "CCDS"; ccds_id "CCDS31381";


