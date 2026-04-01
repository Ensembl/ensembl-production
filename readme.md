# README

This directory contains changelog files for partial data releases on Ensembl Beta.

## CHANGELOG

Documents new genomes or annotations that become available as part of a partial data release on Ensembl Beta .
Allow users to track which species, assemblies, and annotations were updated.

Each entry in this directory corresponds to a partial release and records the following changes :

- New genome added to Ensembl Beta
- New annotation for an existing genome
- Updated dataset for an existing genome or annotation

## File contents and columns

Changelog files are in CSV format and include the following columns for each updated or newly available dataset :

- scientific_name: Latin name for the species or strain (e.g. "Homo sapiens") 
- common_name: Common name (e.g. "human") 
- assembly_name: Assembly label used by Ensembl (e.g. "GRCh38") .
- assembly_accession: Accession number from the INSDC Genome Assembly Database, which is used as an authoritative source of assemblies (e.g. "GCA_000001405.28") 
- Annotation_provider: Resource that supplied the genome annotation (e.g. “Ensembl, NCBI, or a community provider”) 
- Dataset updated: Binary indicators for updated geneset, variation and regulation data

## NOTES

- Use these changelog files to identify exactly which species and assemblies have been updated in a given partial Ensembl Beta release.

