========================================================================
 ENSEMBL RAPID RELEASE FTP SITE
========================================================================

The structure of the FTP directory is show below.
<species> is the scientific name of a species.
<assembly> is the assembly accession, e.g. GCA_001458135.1.
<geneset> is the date that the geneset was loaded by Ensembl.
Square brackets indicate directories or files that are not available
for all species.

species
  |-- <species>
      |-- <assembly>
          |-- geneset
              |-- <geneset>
                  |-- README
                  |-- <species>-<assembly>-<geneset>-cdna.fa.gz
                  |-- <species>-<assembly>-<geneset>-cds.fa.gz
                  |-- <species>-<assembly>-<geneset>-genes.embl.gz
                  |-- <species>-<assembly>-<geneset>-genes.gtf.gz
                  |-- <species>-<assembly>-<geneset>-genes.gff3.gz
                  |-- <species>-<assembly>-<geneset>-pep.fa.gz
                  |-- <species>-<assembly>-<geneset>-xref.tsv.gz
          |-- genome
              |-- README
              |-- [assembly_mapping]
                  |-- *.chain.gz
              |-- [<species>-<assembly>-chromosomes.tsv.gz]
              |-- <species>-<assembly>-hardmasked.fa.gz
              |-- <species>-<assembly>-softmasked.fa.gz
              |-- <species>-<assembly>-unmasked.fa.gz
          |-- [rnaseq]
              |-- README
              |-- *.bam
              |-- *.bam.bai
              |-- *.bam.bw


========================================================================
 geneset | <geneset> | <species>-<assembly>-<geneset>-cdna.fa.gz
 geneset | <geneset> | <species>-<assembly>-<geneset>-cds.fa.gz
 geneset | <geneset> | <species>-<assembly>-<geneset>-pep.fa.gz
========================================================================
Gene sequences in FASTA format. The 'cdna' file contains
transcript sequences for all types of gene (including, for example,
pseudogenes and RNA genes). The 'cds' file contains the DNA sequences
of the coding regions of protein-coding genes. The 'pep' file contains
the amino acid sequences of protein-coding genes.

The headers in the 'cdna' FASTA files have the format:
><transcript_stable_id> <seq_type> <assembly_name>:<seq_name>:<start>:<end>:<strand> gene:<gene_stable_id> gene_biotype:<gene_biotype> transcript_biotype:<transcript_biotype> [gene_symbol:<gene_symbol>] [description:<description>]

Example 'cdna' header:
>ENSZVIT00000000002.1 cdna UG_Zviv_1:LG1:3600:22235:-1 gene:ENSZVIG00000000002.1 gene_biotype:protein_coding transcript_biotype:protein_coding

The headers in the 'cds' FASTA files have the format:
><transcript_stable_id> <seq_type> <assembly_name>:<seq_name>:<coding_start>:<coding_end>:<strand> gene:<gene_stable_id> gene_biotype:<gene_biotype> transcript_biotype:<transcript_biotype> [gene_symbol:<gene_symbol>] [description:<description>]

Example 'cds' header:
>ENSZVIT00000000002.1 cds UG_Zviv_1:LG1:5289:19862:-1 gene:ENSZVIG00000000002.1 gene_biotype:protein_coding transcript_biotype:protein_coding

The headers in the 'pep' FASTA files have the format:
><protein_stable_id> <seq_type> <assembly_name>:<seq_name>:<coding_start>:<coding_end>:<strand> gene:<gene_stable_id> transcript:<transcript_stable_id> gene_biotype:<gene_biotype> transcript_biotype:<transcript_biotype> [gene_symbol:<gene_symbol>] [description:<description>]

Example 'pep' header:
>ENSZVIP00000000002.1 pep UG_Zviv_1:LG1:5289:19862:-1 gene:ENSZVIG00000000002.1 transcript:ENSZVIT00000000002.1 gene_biotype:protein_coding transcript_biotype:protein_coding

Stable IDs for genes, transcripts, and proteins include a version
suffix. Gene symbols and descriptions are not available for all genes.


========================================================================
 geneset | <geneset> | <species>-<assembly>-<geneset>-genes.embl.gz
========================================================================
Gene annotation in EMBL format, including cross-references to external
sources such as GO, RefSeq, and UniProt.

The file contains an entry for each of the genome sequences:
 * ID: Standard EMBL-format header, including sequence name and length
 * AC: Sequence identifier in the format:
       <seq_type>:<assembly>:<seq_name>:<start>:<end>:<strand>
 * SV: The sequence name and assembly version
 * OS: Scientific name of species, followed by the common name in
       parentheses, if available
 * OC: Scientific classification of species
 * CC: Comments

Genes, transcripts, translations and exons are provided in the feature
table of each entry. Stable IDs for the features include a version
suffix. Cross-references are 'db_xref' properties of 'CDS' features.

Feature table:
 * Genes are 'gene' features
    * 'gene' property: gene stable ID
 * Protein-coding transcripts are 'mRNA' features
    * 'gene' property: gene stable ID
    * 'standard_name' property: transcript stable ID
 * Pseudogenes and non-coding RNA transcripts are 'misc_RNA' features
    * 'gene' property: gene stable ID
    * 'note' property: biotype, e.g "pseudogene", "lncRNA"
    * 'standard_name' property: transcript stable ID
 * Proteins are 'CDS' features
    * 'gene' property: gene stable ID
    * 'protein_id' property: protein stable ID
    * 'translation' property: amino acid sequence
 * Exons are 'exon' entries.


========================================================================
 geneset | <geneset> | <species>-<assembly>-<geneset>-genes.gff3.gz  
========================================================================
Gene annotation in GFF3 format. (Specification: https://github.com/The-Sequence-Ontology/Specifications/blob/master/gff3.md)

GFF3 files are validated using GenomeTools (http://genometools.org).

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


========================================================================
 geneset | <geneset> | <species>-<assembly>-<geneset>-genes.gtf.gz  
========================================================================
Gene annotation in GTF format. (Specification: https://mblab.wustl.edu/GTF22.html)

Trans-spliced genes cannot be represented in GTF, so are not included;
they are available in the GFF3 files.

Attributes for feature types:
(square brackets indicate data which is not available for all features)
 * gene:
    * gene_id: Ensembl gene stable ID
    * gene_version: Ensembl gene version
    * [gene_name]: Gene name
    * gene_biotype: Ensembl gene biotype, e.g. "protein_coding", "pseudogene"
    * gene_source: Annotation source
 * transcript:
    * All of the above 'gene_*' attributes
    * transcript_id: Ensembl transcript stable ID
    * transcript_version: Ensembl transcript version
    * [transcript_name]: Transcript name
    * transcript_biotype: Ensembl transcript biotype, e.g. "protein_coding", "pseudogene"
    * transcript_source: Annotation source
 * exon
    * All of the above 'gene_*' and 'transcript_*' attributes
    * exon_id: Ensembl exon stable ID
    * exon_version: Ensembl exon version
    * exon_number: aka 'rank', shows the 5'->3' ordering of exons
 * CDS
    * All of the above 'gene_*', 'transcript_*', and 'exon_*' attributes
    * protein_id: Ensembl protein stable ID
    * protein_version: Ensembl protein version
 * stop_codon
    * All of the above 'gene_*' and 'transcript_*' attributes
    * exon_number: aka 'rank', shows the 5'->3' ordering of exons
 * [five_prime_utr]
    * All of the above 'gene_*' and 'transcript_*' attributes
 * [three_prime_utr]
    * All of the above 'gene_*' and 'transcript_*' attributes
 * [Selenocysteine]:
    * All of the above 'gene_*' and 'transcript_*' attributes


========================================================================
 geneset | <geneset> | <species>-<assembly>-<geneset>-xref.tsv.gz 
========================================================================
A tab-delimited file of cross-references from Ensembl gene, transcript,
and protein stable IDs to external sources, such as GO, RefSeq, and
UniProt. The file has the following columns:
 * gene_stable_id: Ensembl gene stable ID
 * transcript_stable_id: Ensembl transcript stable ID
 * protein_stable_id: Ensembl protein stable ID
 * xref_id: External identifier
 * xref_label: External name
 * description: Cross-reference description
 * db_name: External data source
 * info_type: The means of cross-reference assignment, examples are:
    * DIRECT: an assertion by the external source of a link to an
      Ensembl object
    * DEPENDENT: a transitive link, via another cross-reference
    * CHECKSUM: an exact sequence match
    * SEQUENCE_MATCH: an alignment based sequence match (not
      necessarily exact)
 * dependent_sources: For transitively-derived cross-references, the
   external data source and identifier used as intermediary
 * source_identity: For alignment-derived cross-references, the
   percentage of the Ensembl sequence that matches the external sequence
 * xref_identity: For alignment-derived cross-references, the
   percentage of the external sequence that matches the Ensembl sequence
 * linkage_type: for GO terms, the method of inference, e.g. IEA


========================================================================
 genome | [assembly_mapping] | *.chain.gz
========================================================================
Chain files for mapping between asemblies. (Specification: https://genome.ucsc.edu/goldenPath/help/chain.html)
Such files can be used to project annotation between assemblies, using,
for example, CrossMap (https://crossmap.readthedocs.io/en/latest/)


========================================================================
 genome | [<species>-<assembly>-chromosomes.tsv.gz]
========================================================================
A tab-delimited file with chromosome names and lengths. This file is
absent if the assembly does not have chromosomes.


========================================================================
 genome | <species>-<assembly>-unmasked.fa.gz
 genome | <species>-<assembly>-softmasked.fa.gz
 genome | <species>-<assembly>-hardmasked.fa.gz
========================================================================
Genomic DNA in FASTA format. The 'unmasked' file has no repeat masking,
the 'softmasked' file uses lower case letters for repeat regions, and
the 'hardmasked' file has Ns for repeat regions. Repeat features are
annotated with dust, TRF, and RepeatMasker, the latter using a
combination of RepBase and taxonomically-relevant repeat libraries.

The headers in the FASTA files have the format:
><seq_name> <masking>:<seq_type> <assembly_name>:<seq_name>:<start>:<end>:<strand>

Example 'softmasked' header:
>LG1 softmasked:chromosome UG_Zviv_1:LG1:1:131769443:1

The <seq_type> will be 'chromosome' for chromosomal regions, and will
be 'primary_assembly' for non-chromosomal regions.


========================================================================
 [rnaseq] | *.bam
 [rnaseq] | *.bam.bai
 [rnaseq] | *.bam.bw
========================================================================
BAM and bigWig files of RNA-seq data aligned against a genome. A README
file in the [rnaseq] directory contains details of the samples used in
the alignments. This directory is absent if there are no RNA-seq
alignments.

