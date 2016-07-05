-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016] EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
-- http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

# patch_79_80b.sql
#
# Title: Add variation attrib tables.
#
# Description:
# Add variation 'attrib' and 'attrib_set' tables.

-- The 'master_attrib' table.
-- Lists the existing variation attrib data
CREATE TABLE master_attrib (
  attrib_id           INT(11) UNSIGNED NOT NULL DEFAULT 0,
  attrib_type_id      SMALLINT(5) UNSIGNED NOT NULL DEFAULT 0,
  value               TEXT NOT NULL,
  is_current          TINYINT(1) NOT NULL DEFAULT '1',

  -- Columns for the web interface:
  created_by    INTEGER,
  created_at    DATETIME,
  modified_by   INTEGER,
  modified_at   DATETIME,

  PRIMARY KEY (attrib_id),
  UNIQUE KEY type_val_idx (attrib_type_id, value(80))
);

-- The 'master_attrib_set' table.
-- Lists the existing variation attrib_set data
CREATE TABLE master_attrib_set (
  attrib_set_id       INT(11) UNSIGNED NOT NULL DEFAULT 0,
  attrib_id           INT(11) UNSIGNED NOT NULL DEFAULT 0,
  is_current          TINYINT(1) NOT NULL DEFAULT '1',

  -- Columns for the web interface:
  created_by    INTEGER,
  created_at    DATETIME,
  modified_by   INTEGER,
  modified_at   DATETIME,

  UNIQUE KEY set_idx (attrib_set_id, attrib_id),
  KEY attrib_idx (attrib_id)
);

CREATE DEFINER = CURRENT_USER SQL SECURITY INVOKER VIEW attrib AS
SELECT
  attrib_id AS attrib_id,
  attrib_type_id AS attrib_type_id,
  value AS value
FROM    master_attrib
WHERE   is_current = true
ORDER BY attrib_id;

CREATE DEFINER = CURRENT_USER SQL SECURITY INVOKER VIEW attrib_set AS
SELECT
  attrib_set_id AS attrib_set_id,
  attrib_id AS attrib_id
FROM    master_attrib_set
WHERE   is_current = true
ORDER BY attrib_set_id,attrib_id;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
VALUES (NULL, 'patch', 'patch_79_80b.sql|add_variation_attrib_tables');
