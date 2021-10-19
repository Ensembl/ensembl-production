-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2021] EMBL-European Bioinformatics Institute
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

# patch_96_97_f.sql
#
# Title: Reset and clean meta keys table
#
# Description:
#   Removed old obsolete data from metakey, reordering
# Patch identifier
-- Allow compara as a db_type option.
ALTER TABLE meta_key CHANGE db_type db_type
  SET('cdna','compara','core','funcgen','otherfeatures','rnaseq','variation','vega','presite','sangervega');


-- It's easiest to start with a clean slate, then work through one db_type at a time.
UPDATE meta_key SET is_current = 0;


-- A few meta_keys are essential everywhere...
INSERT INTO meta_key (name, is_optional, is_current, db_type) VALUES
  ('patch', 0, 1, 'cdna,compara,core,funcgen,otherfeatures,rnaseq,variation'),
  ('schema_type', 0, 1, 'cdna,compara,core,funcgen,otherfeatures,rnaseq,variation'),
  ('schema_version', 0, 1, 'cdna,compara,core,funcgen,otherfeatures,rnaseq,variation'),
  ('species.production_name', 0, 1, 'cdna,core,funcgen,otherfeatures,rnaseq,variation');


-- Mandatory keys for core are optional for core-like, except for 'assembly.*' and 'species.*' ones.
INSERT INTO meta_key (name, is_optional, is_current, db_type) VALUES
  ('assembly.default', 0, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('assembly.name', 0, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('genebuild.method', 0, 1, 'core'),
  ('genebuild.start_date', 0, 1, 'core'),
  ('provider.name', 0, 1, 'core'),
  ('provider.url', 0, 1, 'core'),
  ('sample.gene_param', 0, 1, 'core'),
  ('sample.gene_text', 0, 1, 'core'),
  ('sample.location_param', 0, 1, 'core'),
  ('sample.location_text', 0, 1, 'core'),
  ('sample.search_text', 0, 1, 'core'),
  ('sample.transcript_param', 0, 1, 'core'),
  ('sample.transcript_text', 0, 1, 'core'),
  ('species.classification', 0, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.display_name', 0, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.division', 0, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.scientific_name', 0, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.taxonomy_id', 0, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.url', 0, 1, 'core,cdna,otherfeatures,rnaseq');

INSERT INTO meta_key (name, is_optional, is_current, db_type) VALUES
  ('genebuild.method', 1, 1, 'cdna,otherfeatures,rnaseq'),
  ('genebuild.start_date', 1, 1, 'cdna,otherfeatures,rnaseq'),
  ('provider.name', 1, 1, 'cdna,otherfeatures,rnaseq'),
  ('provider.url', 1, 1, 'cdna,otherfeatures,rnaseq'),
  ('sample.gene_param', 1, 1, 'cdna,otherfeatures,rnaseq'),
  ('sample.gene_text', 1, 1, 'cdna,otherfeatures,rnaseq'),
  ('sample.location_param', 1, 1, 'cdna,otherfeatures,rnaseq'),
  ('sample.location_text', 1, 1, 'cdna,otherfeatures,rnaseq'),
  ('sample.search_text', 1, 1, 'cdna,otherfeatures,rnaseq'),
  ('sample.transcript_param', 1, 1, 'cdna,otherfeatures,rnaseq'),
  ('sample.transcript_text', 1, 1, 'cdna,otherfeatures,rnaseq');


-- Optional keys for core are also optional for core-like
INSERT INTO meta_key (name, is_optional, is_current, db_type) VALUES
  ('assembly.accession', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('assembly.coverage_depth', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('assembly.date', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('assembly.description', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('assembly.long_name', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('assembly.mapping', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('assembly.master_accession', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('assembly.ucsc_alias', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('assembly.version', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('assembly.web_accession_source', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('assembly.web_accession_type', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('dna_align_featurebuild.level', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('exonbuild.level', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('gencode.version', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('genebuild.hash', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('genebuild.havana_datafreeze_date', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('genebuild.id', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('genebuild.initial_release_date', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('genebuild.last_geneset_update', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('genebuild.level', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('genebuild.projection_source_db', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('genebuild.version', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('liftover.mapping', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('lrg', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('ploidy', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('prediction_exonbuild.level', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('prediction_transcriptbuild.level', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('protein_align_featurebuild.level', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('repeat.analysis', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('repeat_featurebuild.level', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('sample.structural_param', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('sample.structural_text', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('sample.variation_param', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('sample.variation_text', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('sample.vep_ensembl', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('sample.vep_hgvs', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('sample.vep_id', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('sample.vep_pileup', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('sample.vep_vcf', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('schema.copy_src', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('schema.load_complete', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('schema.load_started', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('simple_featurebuild.level', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.alias', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.biomart_dataset', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.bioproject_id', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.common_name', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.db_name', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.nematode_clade', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.serotype', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.species_name', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.species_taxonomy_id', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.stable_id_prefix', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.strain', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.strain_collection', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.substrain', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.vectorbase_name', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.wikipedia_name', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.wikipedia_url', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('species.wormbase_name', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('transcriptbuild.level', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('uniprot_proteome.id', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('uniprot_proteome.status', 1, 1, 'core,cdna,otherfeatures,rnaseq'),
  ('xref.timestamp', 1, 1, 'core,cdna,otherfeatures,rnaseq');


-- Optional keys for otherfeatures
INSERT INTO meta_key (name, is_optional, is_current, db_type) VALUES
  ('genebuild.last_otherfeatures_update', 1, 1, 'otherfeatures');


-- No optional keys for funcgen


-- Optional keys for variation
INSERT INTO meta_key (name, is_optional, is_current, db_type) VALUES
  ('ancestral_allele_source', 1, 1, 'variation'),
  ('ancestral_allele_update', 1, 1, 'variation'),
  ('cadd_version', 1, 1, 'variation'),
  ('ClinGen_Allele_Registry_CAR_version', 1, 1, 'variation'),
  ('ClinGen_Allele_Registry_source', 1, 1, 'variation'),
  ('ClinGen_Allele_Registry_update', 1, 1, 'variation'),
  ('dbnsfp_version', 1, 1, 'variation'),
  ('EPMC citation_update', 1, 1, 'variation'),
  ('EquivalentAlleles_run_date', 1, 1, 'variation'),
  ('HGVS_version', 1, 1, 'variation'),
  ('individual.displayable_strain', 1, 1, 'variation'),
  ('pairwise_ld.default_population', 1, 1, 'variation'),
  ('ploidy', 1, 1, 'variation'),
  ('polyphen_version', 1, 1, 'variation'),
  ('sample.default_strain', 1, 1, 'variation'),
  ('sample.reference_strain', 1, 1, 'variation'),
  ('sift_protein_db_version', 1, 1, 'variation'),
  ('sift_version', 1, 1, 'variation'),
  ('TranscriptEffect_run_date', 1, 1, 'variation'),
  ('UCSC citation_update', 1, 1, 'variation'),
  ('USCS citation_update', 1, 1, 'variation'),
  ('VariationClass_run_date', 1, 1, 'variation'),
  ('web_config', 1, 1, 'variation');

INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_96_97_f.sql|update_meta_keys');

