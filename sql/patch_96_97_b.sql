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

# patch_91_92_a.sql
#
# Title: Refactor biotype
#
# Description:
#   Change biotype into master_biotype and create a view for biotype
#   This is to support the introduction of biotype as a table in the core schema

RENAME TABLE biotype TO master_biotype;

CREATE DEFINER = CURRENT_USER SQL SECURITY INVOKER VIEW biotype AS
SELECT
  biotype_id,
  name,
  is_dumped,
  object_type,
  attrib_type_id,
  description,
  biotype_group        
FROM    master_biotype
WHERE   is_current = true
ORDER BY biotype_id;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_96_97_b.sql|biotype_rename');
