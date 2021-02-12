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

# patch_96_97_b.sql
#
# Title: Add so_term column to biotype table
#
# Description:
#   Update master_biotype table and biotype view to include a new so_term column.


-- Add new column so_term
ALTER TABLE master_biotype ADD COLUMN so_term VARCHAR(1023) AFTER so_acc;

-- Populate so_term column
UPDATE master_biotype SET so_term = 'protein_coding_gene' WHERE so_acc = 'SO:0001217';
UPDATE master_biotype SET so_term = 'C_gene_segment' WHERE so_acc = 'SO:0000478';
UPDATE master_biotype SET so_term = 'D_gene_segment' WHERE so_acc = 'SO:0000458';
UPDATE master_biotype SET so_term = 'J_gene_segment' WHERE so_acc = 'SO:0000470';
UPDATE master_biotype SET so_term = 'pseudogene' WHERE so_acc = 'SO:0000336';
UPDATE master_biotype SET so_term = 'pseudogenic_transcript' WHERE so_acc = 'SO:0000516';
UPDATE master_biotype SET so_term = 'V_gene_segment' WHERE so_acc = 'SO:0000466';
UPDATE master_biotype SET so_term = 'gene_segment' WHERE so_acc = 'SO:3000000';
UPDATE master_biotype SET so_term = 'ncRNA_gene' WHERE so_acc = 'SO:0001263';
UPDATE master_biotype SET so_term = 'rRNA' WHERE so_acc = 'SO:0000252';
UPDATE master_biotype SET so_term = 'tRNA' WHERE so_acc = 'SO:0000253';
UPDATE master_biotype SET so_term = 'unconfirmed_transcript' WHERE so_acc = 'SO:0002139';
UPDATE master_biotype SET so_term = 'lnc_RNA' WHERE so_acc = 'SO:0001877';
UPDATE master_biotype SET so_term = 'cDNA' WHERE so_acc = 'SO:0000756';
UPDATE master_biotype SET so_term = 'EST' WHERE so_acc = 'SO:0000345';
UPDATE master_biotype SET so_term = 'miRNA' WHERE so_acc = 'SO:0000276';
UPDATE master_biotype SET so_term = 'ncRNA' WHERE so_acc = 'SO:0000655';
UPDATE master_biotype SET so_term = 'mRNA' WHERE so_acc = 'SO:0000234';
UPDATE master_biotype SET so_term = 'retrotransposed' WHERE so_acc = 'SO:0000569';
UPDATE master_biotype SET so_term = 'snRNA' WHERE so_acc = 'SO:0000274';
UPDATE master_biotype SET so_term = 'snoRNA' WHERE so_acc = 'SO:0000275';
UPDATE master_biotype SET so_term = 'three_prime_overlapping_ncrna' WHERE so_acc = 'SO:0002120';
UPDATE master_biotype SET so_term = 'scRNA' WHERE so_acc = 'SO:0000013';
UPDATE master_biotype SET so_term = 'RNase_MRP_RNA' WHERE so_acc = 'SO:0000385';
UPDATE master_biotype SET so_term = 'RNase_P_RNA' WHERE so_acc = 'SO:0000386';
UPDATE master_biotype SET so_term = 'telomerase_RNA' WHERE so_acc = 'SO:0000390';
UPDATE master_biotype SET so_term = 'pre_miRNA' WHERE so_acc = 'SO:0001244';
UPDATE master_biotype SET so_term = 'tmRNA' WHERE so_acc = 'SO:0000584';
UPDATE master_biotype SET so_term = 'SRP_RNA' WHERE so_acc = 'SO:0000590';
UPDATE master_biotype SET so_term = 'class_I_RNA' WHERE so_acc = 'SO:0000990';
UPDATE master_biotype SET so_term = 'class_II_RNA' WHERE so_acc = 'SO:0000989';
UPDATE master_biotype SET so_term = 'piRNA' WHERE so_acc = 'SO:0001035';
UPDATE master_biotype SET so_term = 'CRISPR' WHERE so_acc = 'SO:0001459';
UPDATE master_biotype SET so_term = 'vaultRNA_primary_transcript' WHERE so_acc = 'SO:0002040';
UPDATE master_biotype SET so_term = 'guide_RNA' WHERE so_acc = 'SO:0000602';
UPDATE master_biotype SET so_term = 'Y_RNA' WHERE so_acc = 'SO:0000405';
UPDATE master_biotype SET so_term = 'transposable_element' WHERE so_acc = 'SO:0000101';
UPDATE master_biotype SET so_term = 'transposable_element_gene' WHERE so_acc = 'SO:0000111';
UPDATE master_biotype SET so_term = 'bidirectional_promoter_lncRNA' WHERE so_acc = 'SO:0002185';

-- update biotype view
ALTER VIEW biotype AS
SELECT
  biotype_id AS biotype_id,
  name AS name,
  object_type AS object_type,
  db_type AS db_type,
  attrib_type_id AS attrib_type_id,
  description AS description,
  biotype_group AS biotype_group,
  so_acc AS so_acc,
  so_term AS so_term
FROM master_biotype
WHERE is_current = true
ORDER BY biotype_id;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_96_97_b.sql|biotype_so_term');
