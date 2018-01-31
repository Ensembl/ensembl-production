-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2017] EMBL-European Bioinformatics Institute
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

# patch_91_92_x.sql
#
# Title: Update biotype to master_biotype tables.
#
# Description: Rename biotype table to master_biotype and so_term column added.

RENAME TABLE biotype TO master_biotype;

ALTER TABLE master_biotype ADD COLUMN so_acc VARCHAR(64) AFTER biotype_group;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_92_93_b.sql|biotype to master_biotype');
