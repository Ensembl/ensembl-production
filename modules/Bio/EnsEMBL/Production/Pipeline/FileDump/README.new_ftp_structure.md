================================================================================
Ensembl FTP Site Structure
================================================================================

This document explains how data is organised on the Ensembl FTP site.

--------------------------------------------------------------------------------
OVERVIEW
--------------------------------------------------------------------------------

Data is arranged hierarchically by INSDC (International Nucleotide Sequence
Database Collaboration) assembly accession numbers, which follow this format:

    [Prefix]_[9 digits].[Version]

The prefix indicates the source database:

    GCA    ENA/GenBank
    GCF    RefSeq

Every FTP path typically has five components:

    {accession_path} / {provider} / {annotation_date} / {data_directory} / {files}

This structure applies to both GCA and GCF accessions.

--------------------------------------------------------------------------------
QUICK START
--------------------------------------------------------------------------------

Examples using assembly GCA_000001405.29 (human genome, version 29).

Gene annotations (genebuild date: March 2023):

    GCA/000/001/405/29/ensembl/2023_03/geneset/genes.gff3.gz

Variation data (genebuild date: March 2023, release: 18 October 2023):

    GCA/000/001/405/29/ensembl/2023_03/variation/2023_10_18/variation.vcf.gz

Genome sequence (genebuild date: March 2023):

    GCA/000/001/405/29/ensembl/2023_03/genome/softmasked.fa.bgz


--------------------------------------------------------------------------------
PATH STRUCTURE
--------------------------------------------------------------------------------

1. ACCESSION PATH
-----------------
The accession digits are split into groups of three to keep directory sizes
manageable:

    GCA_000001405.29  ->  GCA/000/001/405/29/

    GCA/
    +-- 000/
        +-- 001/
            +-- 405/
                +-- 29/


2. PROVIDER
-----------
Each assembly directory contains one or more provider subdirectories,
indicating who supplied the annotation:

    ensembl/      Ensembl-provided annotations
    community/    Community-provided annotations

Other provider names may also appear.


3. GENEBUILD DATE
-----------------
Within each provider directory, data is organised by genebuild date in
YYYY_MM format. Multiple dated releases may exist for the same assembly,
reflecting successive annotation updates:

    GCA/000/001/405/29/
    +-- ensembl/
        +-- 2023_04/
        +-- 2024_11/
        +-- 2025_12/


4 & 5. DATA DIRECTORIES AND FILES
----------------------------------
See the files included in the different DATA DIRECTORIES section below.

geneset/
--------
Gene annotation files for a genebuild.

    genes.gff3.gz           Gene annotations in GFF3 format
    genes.gff3.bgz          Bgzip-compressed GFF3 gene annotations
    genes.gff3.bgz.csi      Coordinate-sorted index for GFF3
    genes.gtf.gz            Gene annotations in GTF format
    genes.gtf.bgz           Bgzip-compressed GTF gene annotations
    genes.gtf.bgz.csi       Coordinate-sorted index for GTF
    genes.embl.gz           Gene data in EMBL format
    cdna.fa.bgz             cDNA sequences
    cdna.fa.bgz.fai         FASTA index for cDNA
    cdna.fa.bgz.gzi         Bgzip index for cDNA
    pep.fa.bgz              Protein sequences
    pep.fa.bgz.fai          FASTA index for protein sequences
    pep.fa.bgz.gzi          Bgzip index for protein sequences
    xref.tsv.gz             Cross-reference table mapping gene identifiers
    md5sum.txt              Checksums for file integrity verification

Example:

    GCA/000/001/405/29/ensembl/2023_03/geneset/genes.gff3.gz


genome/
-------
Genome sequence files for a genebuild. Sequences are provided in three
masking forms (see NOTE ON REPEAT MASKING below).

    softmasked.fa.bgz       Genome sequence with repeats in lowercase
    softmasked.fa.bgz.fai   FASTA index for soft-masked genome
    softmasked.fa.bgz.gzi   Bgzip index for soft-masked genome
    hardmasked.fa.bgz       Genome sequence with repeats replaced by N
    hardmasked.fa.bgz.fai   FASTA index for hard-masked genome
    hardmasked.fa.bgz.gzi   Bgzip index for hard-masked genome
    unmasked.fa.bgz         Genome sequence with no repeat masking
    unmasked.fa.bgz.fai     FASTA index for unmasked genome
    unmasked.fa.bgz.gzi     Bgzip index for unmasked genome
    chromosomes.tsv.gz      Chromosome metadata
    md5sum.txt              Checksums for file integrity verification

NOTE ON REPEAT MASKING: Note: hard-masked where repeats are replaced with N, and soft-masked where repeats are lowercased.
 
Example:

    GCA/000/001/405/29/ensembl/2023_03/genome/softmasked.fa.bgz


homology/
---------
Homology data for a genebuild, optionally organised in a YYYY_MM_DD
release subdirectory.

    homology.tsv.gz         Homology data in TSV format
    md5sum.txt              Checksums for file integrity verification

Example:

    GCA/000/001/405/29/ensembl/2023_03/homology/2023_10_18/


variation/
----------
Genetic variation data for a genebuild, optionally organised in a
YYYY_MM_DD release subdirectory.

    variation.vcf.gz        Variant annotations and genotype data in VCF format
    md5sum.txt              Checksums for file integrity verification

Example:

    GCA/000/001/405/29/ensembl/2023_03/variation/2023_10_18/variation.vcf.gz


--------------------------------------------------------------------------------
KEY NOTES
--------------------------------------------------------------------------------

- Assembly paths are derived from the accession prefix, accession digits split into triplets, and version number

- Data is organised by provider and genebuild annotation date below each assembly path

- Genebuild date directories use `YYYY_MM` format

- FASTA files use bgzip compression (.fa.bgz). Companion .fai and .gzi index
  files enable random access without decompressing the whole file.

- Most annotation files are available in multiple formats (GFF3, GTF, EMBL).
  Use whichever your tool requires.

- Variation data is provided in standard VCF format

- Always verify downloaded files using the md5sum.txt provided in each
  directory.

- Provider directories and available data types vary between assemblies.

--------------------------------------------------------------------------------
SUPPORT
--------------------------------------------------------------------------------

For questions about this FTP structure, contact the Ensembl helpdesk: helpdesk@ensembl.org

================================================================================

