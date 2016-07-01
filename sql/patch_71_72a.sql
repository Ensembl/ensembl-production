-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016] EMBL-European Bioinformatics Institute
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

-- patch_71_72a.sql
--
-- Title: Create table meta and set schema type/version
--
-- Description:
--   Production does not have meta table, create it and
--   add information so that script schema_patcher.pl would work

CREATE TABLE IF NOT EXISTS meta (

  meta_id                     INT NOT NULL AUTO_INCREMENT,
  species_id                  INT UNSIGNED DEFAULT 1,
  meta_key                    VARCHAR(40) NOT NULL,
  meta_value                  TEXT NOT NULL,

  PRIMARY   KEY (meta_id),
  UNIQUE    KEY species_key_value_idx (species_id, meta_key, meta_value(255)),
            KEY species_value_idx (species_id, meta_value(255))

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'schema_type', 'production');

INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'schema_version', 72);

-- Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_71_72a.sql|meta table, schema type, schema version');
