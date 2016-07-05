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

-- Patching in support for numerous different names for trinomials

-- Supporting aliases
CREATE TABLE species_alias (
  species_alias_id  INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
  species_id        INTEGER UNSIGNED NOT NULL,
  alias             varchar(255) NOT NULL,
  is_current        BOOLEAN NOT NULL DEFAULT true,
  created_by    INTEGER,
  created_at    DATETIME,
  modified_by   INTEGER,
  modified_at   DATETIME,
  PRIMARY KEY (species_alias_id),
  UNIQUE INDEX (alias, is_current),
  INDEX sa_speciesid_idx (species_id)
);


-- Supporting production name
ALTER TABLE species
ADD COLUMN production_name VARCHAR(255) NOT NULL
AFTER web_name;

-- Supporting scientific name
ALTER TABLE species
ADD COLUMN scientific_name VARCHAR(255) NOT NULL
AFTER web_name;

-- Supporting URL name
ALTER TABLE species
ADD COLUMN url_name VARCHAR(255) NOT NULL
AFTER production_name;

-- Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_66_67b.sql|Patching in support for numerous different names for trinomials');
