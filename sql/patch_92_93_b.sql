-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

# patch_92_93_b.sql
#
# Title: Update table biotype to master_biotype.
#
# Description:
#   Change constraint name_type_idx from (name, object_type, db_type) to (name, object_type)
#   to enforce that (name, object_type) pairs are unique as used by the ORM.
#   Rename biotype table to master_biotype.
#   Add so_acc column to master_biotype and populate it.
#   Create biotype view.

-- Remove existing composite unique key that contains (name, object_type, db_type)
DROP INDEX name_type_idx ON biotype;

-- Prepare table for new composite unique key (name, object_type), remove duplicates
UPDATE biotype SET db_type = 'core,presite,otherfeatures,vega' WHERE biotype_id = 44;
UPDATE biotype SET description = 'From RefSeq import.' WHERE biotype_id = 44;
DELETE FROM biotype WHERE biotype_id = 121;
UPDATE biotype SET db_type = 'core,presite,otherfeatures' WHERE biotype_id = 45;
UPDATE biotype SET description = 'From RefSeq import.' WHERE biotype_id = 45;
DELETE FROM biotype WHERE biotype_id = 122;
DELETE FROM biotype WHERE biotype_id = 159;
UPDATE biotype SET db_type = 'core,presite,otherfeatures' WHERE biotype_id = 87;
DELETE FROM biotype WHERE biotype_id = 161;
UPDATE biotype SET db_type = 'core,presite,otherfeatures' WHERE biotype_id = 88;
UPDATE biotype SET attrib_type_id = 76 WHERE biotype_id = 88;
DELETE FROM biotype WHERE biotype_id = 162;
UPDATE biotype SET db_type = 'core,presite,otherfeatures,vega' WHERE biotype_id = 83;
UPDATE biotype SET description = 'small nucleolar RNA.' WHERE biotype_id = 83;
DELETE FROM biotype WHERE biotype_id = 190;
UPDATE biotype SET db_type = 'core,presite,otherfeatures,vega' WHERE biotype_id = 84;
UPDATE biotype SET description = 'small nucleolar RNA.' WHERE biotype_id = 84;
DELETE FROM biotype WHERE biotype_id = 201;
UPDATE biotype SET db_type = 'core,presite,otherfeatures,vega' WHERE biotype_id = 77;
UPDATE biotype SET description = 'From Havana manual annotation.' WHERE biotype_id = 77;
DELETE FROM biotype WHERE biotype_id = 119;
DELETE FROM biotype WHERE biotype_id = 213;
UPDATE biotype SET db_type = 'core,presite,otherfeatures,vega' WHERE biotype_id = 78;
UPDATE biotype SET description = 'From Havana manual annotation.' WHERE biotype_id = 78;
DELETE FROM biotype WHERE biotype_id = 120;
DELETE FROM biotype WHERE biotype_id = 214;
DELETE FROM biotype WHERE biotype_id = 34;
DELETE FROM biotype WHERE biotype_id = 136;

-- Add new composite key
ALTER TABLE biotype ADD CONSTRAINT name_type_idx UNIQUE KEY (name, object_type);

-- Rename table to master_biotype
RENAME TABLE biotype TO master_biotype;

-- Add new column so_acc
ALTER TABLE master_biotype ADD COLUMN so_acc VARCHAR(64) AFTER biotype_group;

-- Populate so_acc column according to Bio::EnsEMBL::Utils::SequenceOntologyMapper
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='ambiguous_orf' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='ambiguous_orf' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='antisense' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='antisense' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='antisense_RNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='antisense_RNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='antitoxin' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='antitoxin' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='class_II_RNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000989' WHERE name='class_II_RNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='class_I_RNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000990' WHERE name='class_I_RNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='CRISPR' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='disrupted_domain' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='guide_RNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000602' WHERE name='guide_RNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='IG_C_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000478' WHERE name='IG_C_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='IG_C_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='IG_C_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='IG_D_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000458' WHERE name='IG_D_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='IG_D_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='IG_D_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='IG_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:3000000' WHERE name='IG_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='IG_J_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000470' WHERE name='IG_J_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='IG_J_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='IG_J_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='IG_LV_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:3000000' WHERE name='IG_LV_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='IG_M_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:3000000' WHERE name='IG_M_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='IG_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='IG_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='IG_V_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000466' WHERE name='IG_V_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='IG_V_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='IG_V_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='IG_Z_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:3000000' WHERE name='IG_Z_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000655' WHERE name='known_ncRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='lincRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='lincRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='lncRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='macro_lncRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='macro_lncRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='miRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000276' WHERE name='miRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='miRNA_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='miRNA_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='misc_RNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000655' WHERE name='misc_RNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='misc_RNA_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='misc_RNA_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='mRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000234' WHERE name='mRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='Mt_rRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000252' WHERE name='Mt_rRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='Mt_tRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000253' WHERE name='Mt_tRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='Mt_tRNA_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='Mt_tRNA_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='ncbi_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='ncbi_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='ncRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000655' WHERE name='ncRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='ncRNA_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='ncRNA_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000234' WHERE name='nonsense_mediated_decay' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='nontranslating_CDS' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000234' WHERE name='nontranslating_CDS' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='non_coding' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='non_coding' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000234' WHERE name='non_stop_decay' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='piRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001035' WHERE name='piRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='polymorphic' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='polymorphic_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000234' WHERE name='polymorphic_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='pre_miRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001244' WHERE name='pre_miRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='processed_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='processed_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='processed_transcript' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='processed_transcript' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='protein_coding' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000234' WHERE name='protein_coding' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='retained_intron' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='retained_intron' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='ribozyme' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='ribozyme' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='RNase_MRP_RNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000385' WHERE name='RNase_MRP_RNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='RNase_P_RNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000386' WHERE name='RNase_P_RNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='rRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000252' WHERE name='rRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='rRNA_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='rRNA_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='scaRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000013' WHERE name='scaRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='scRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000013' WHERE name='scRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='scRNA_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='scRNA_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='sense_intronic' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='sense_intronic' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='sense_overlapping' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0001877' WHERE name='sense_overlapping' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='snlRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000274' WHERE name='snlRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='snoRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000275' WHERE name='snoRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='snoRNA_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='snoRNA_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='snRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000274' WHERE name='snRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='snRNA_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='snRNA_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='sRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000274' WHERE name='sRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='SRP_RNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000590' WHERE name='SRP_RNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='telomerase_RNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000390' WHERE name='telomerase_RNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='tmRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000584' WHERE name='tmRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='transcribed_processed_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='transcribed_processed_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='transcribed_unitary_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='transcribed_unitary_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='transcribed_unprocessed_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='transcribed_unprocessed_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='translated_processed_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='translated_processed_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='translated_unprocessed_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='translated_unprocessed_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='tRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000253' WHERE name='tRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='tRNA_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='tRNA_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='TR_C_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000478' WHERE name='TR_C_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='TR_D_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000458' WHERE name='TR_D_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='TR_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:3000000' WHERE name='TR_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='TR_J_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000470' WHERE name='TR_J_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='TR_J_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='TR_J_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='TR_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='TR_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001217' WHERE name='TR_V_gene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000466' WHERE name='TR_V_gene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='TR_V_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='TR_V_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='unitary_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='unitary_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0000336' WHERE name='unprocessed_pseudogene' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000516' WHERE name='unprocessed_pseudogene' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='vaultRNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0002040' WHERE name='vaultRNA' AND object_type='transcript';
UPDATE master_biotype SET so_acc='SO:0001263' WHERE name='Y_RNA' AND object_type='gene';
UPDATE master_biotype SET so_acc='SO:0000405' WHERE name='Y_RNA' AND object_type='transcript';

-- Populate so_acc column with new mappings (best judgement used)
UPDATE master_biotype SET so_acc='SO:0000345' WHERE biotype_id=21;
UPDATE master_biotype SET so_acc='SO:0000345' WHERE biotype_id=22;
UPDATE master_biotype SET so_acc='SO:0002139' WHERE biotype_id=28;
UPDATE master_biotype SET so_acc='SO:0000756' WHERE biotype_id=37;
UPDATE master_biotype SET so_acc='SO:0000756' WHERE biotype_id=38;
UPDATE master_biotype SET so_acc='SO:0000569' WHERE biotype_id=73;
UPDATE master_biotype SET so_acc='SO:0000569' WHERE biotype_id=74;
UPDATE master_biotype SET so_acc='SO:0002120' WHERE biotype_id=118;
UPDATE master_biotype SET so_acc='SO:0001459' WHERE biotype_id=197;
UPDATE master_biotype SET so_acc='SO:0000101' WHERE biotype_id=209;
UPDATE master_biotype SET so_acc='SO:0000101' WHERE biotype_id=210;
UPDATE master_biotype SET so_acc='SO:0002185' WHERE biotype_id=212;
UPDATE master_biotype SET so_acc='SO:0001877' WHERE biotype_id=218;

-- biotype table view
CREATE DEFINER = CURRENT_USER SQL SECURITY INVOKER VIEW biotype AS
SELECT
  biotype_id AS biotype_id,
  name AS name,
  object_type AS object_type,
  db_type AS db_type,
  attrib_type_id AS attrib_type_id,
  description AS description,
  biotype_group AS biotype_group,
  so_acc AS so_acc
FROM master_biotype
WHERE is_current = true
ORDER BY biotype_id;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_92_93_b.sql|biotype to master_biotype');
