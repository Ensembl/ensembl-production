-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

-- Table schema for the production database

-- The 'meta' table.
CREATE TABLE IF NOT EXISTS meta (

  meta_id                     INT NOT NULL AUTO_INCREMENT,
  species_id                  INT UNSIGNED DEFAULT 1,
  meta_key                    VARCHAR(40) NOT NULL,
  meta_value                  TEXT NOT NULL,

  PRIMARY   KEY (meta_id),
  UNIQUE    KEY species_key_value_idx (species_id, meta_key, meta_value(255)),
            KEY species_value_idx (species_id, meta_value(255))

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

# Add schema type and schema version to the meta table
INSERT INTO meta (species_id, meta_key, meta_value) VALUES
  (NULL, 'schema_type', 'production'),
  (NULL, 'schema_version', 99);

# Patches included in this schema file
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_98_99_a.sql|schema version');

-- The 'master_biotype' table.
-- Contains all the valid biotypes used for genes and transcripts.
CREATE TABLE master_biotype (
  biotype_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name            VARCHAR(64) NOT NULL,
  is_current      TINYINT NOT NULL DEFAULT '1',
  is_dumped       TINYINT NOT NULL DEFAULT '1',
  object_type     ENUM('gene', 'transcript') NOT NULL DEFAULT 'gene',
  db_type         SET('cdna', 'core', 'coreexpressionatlas',
                      'coreexpressionest', 'coreexpressiongnf', 'funcgen',
                      'otherfeatures', 'rnaseq', 'variation', 'vega',
                      'presite', 'sangervega') NOT NULL DEFAULT 'core',
  attrib_type_id  INT(11) DEFAULT NULL,
  description     TEXT,
  biotype_group   ENUM('coding','pseudogene','snoncoding','lnoncoding','mnoncoding','LRG','undefined','no_group') DEFAULT NULL,
  so_acc          VARCHAR(64),
  so_term         VARCHAR(1023),

  -- Columns for the web interface:
  created_by      INT,
  created_at      DATETIME,
  modified_by     INT,
  modified_at     DATETIME,

  PRIMARY KEY (biotype_id),
  UNIQUE KEY name_type_idx (name, object_type)
);

-- The 'meta_key' table.
-- Contains the meta keys that may or must be available in the 'meta'
-- table in the Core databases.
CREATE TABLE meta_key (
  meta_key_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name              VARCHAR(64) NOT NULL,
  is_optional       TINYINT NOT NULL DEFAULT '0',
  is_current        TINYINT NOT NULL DEFAULT '1',
  db_type           SET('cdna', 'compara', 'core', 'funcgen', 'otherfeatures',
                        'rnaseq', 'variation', 'vega') NOT NULL DEFAULT 'core',
  description       TEXT,
  -- Columns for the web interface:
  created_by    INT,
  created_at    DATETIME,
  modified_by   INT,
  modified_at   DATETIME,
  is_multi_value tinyint(1) NOT NULL DEFAULT '0',

  PRIMARY KEY (meta_key_id),
  UNIQUE KEY name_type_idx (name, db_type)
);

-- The 'analysis_description' table.
-- Contains the analysis logic name along with the data that should
-- be available in the 'analysis_description' table, except for the
-- 'web_data' and 'displayable' columns.
CREATE TABLE analysis_description (
  analysis_description_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  logic_name                VARCHAR(128) NOT NULL,
  description               TEXT,
  display_label             VARCHAR(256) NOT NULL,
  db_version                TINYINT(1) NOT NULL DEFAULT '1',
  is_current                TINYINT NOT NULL DEFAULT '1',
  web_data_id       INT(1)  DEFAULT NULL,
  displayable       TINYINT(1) NOT NULL,

  -- Columns for the web interface:
  created_by    INT,
  created_at    DATETIME,
  modified_by   INT,
  modified_at   DATETIME,

  PRIMARY KEY (analysis_description_id),
  UNIQUE KEY logic_name_idx (logic_name)
);


-- The 'web_data' table.
-- Contains the unique web_data.
CREATE TABLE web_data (
  web_data_id               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  data                      TEXT,

  -- Columns for internal documentation
  comment TEXT,

  -- Columns for the web interface:
  created_by    INT,
  created_at    DATETIME,
  modified_by   INT,
  modified_at   DATETIME,
  description varchar(255) DEFAULT NULL,

  PRIMARY KEY (web_data_id)
);

-- The 'master_attrib_type' table.
-- Lists the existing attrib_types
CREATE TABLE master_attrib_type (
  attrib_type_id            SMALLINT(5) unsigned NOT NULL AUTO_INCREMENT,
  code                      VARCHAR(20) NOT NULL DEFAULT '',
  name                      VARCHAR(255) NOT NULL DEFAULT '',
  description               TEXT,
  is_current                TINYINT(1) NOT NULL DEFAULT '1',

  -- Columns for the web interface:
  created_by    INT,
  created_at    DATETIME,
  modified_by   INT,
  modified_at   DATETIME,

  PRIMARY KEY (attrib_type_id),
  UNIQUE KEY code_idx (code)
);

-- The 'master_attrib' table.
-- Lists the existing variation attrib data
CREATE TABLE master_attrib (
  attrib_id           INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  attrib_type_id      SMALLINT(5) UNSIGNED NOT NULL DEFAULT 0,
  value               TEXT NOT NULL,
  is_current          TINYINT(1) NOT NULL DEFAULT '1',

  -- Columns for the web interface:
  created_by    INT,
  created_at    DATETIME,
  modified_by   INT,
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
  created_by    INT,
  created_at    DATETIME,
  modified_by   INT,
  modified_at   DATETIME,

  UNIQUE KEY set_idx (attrib_set_id, attrib_id),
  KEY attrib_idx (attrib_id)
);

-- The 'master_external_db' table.
-- Lists the existing external_dbs
CREATE TABLE master_external_db (
  external_db_id            INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  db_name                   VARCHAR(100) NOT NULL,
  db_release                VARCHAR(255) DEFAULT NULL,
  status                    ENUM('KNOWNXREF','KNOWN','XREF','PRED','ORTH','PSEUDO') NOT NULL,
  priority                  INT(11) NOT NULL,
  db_display_name           VARCHAR(255) NOT NULL,
  type                      ENUM('ARRAY','ALT_TRANS','ALT_GENE','MISC','LIT','PRIMARY_DB_SYNONYM','ENSEMBL') DEFAULT NULL,
  secondary_db_name         VARCHAR(255) DEFAULT NULL,
  secondary_db_table        VARCHAR(255) DEFAULT NULL,
  description               TEXT,
  is_current                TINYINT(1) NOT NULL DEFAULT '1',

  -- Columns for the web interface:
  created_by    INT,
  created_at    DATETIME,
  modified_by   INT,
  modified_at   DATETIME,

  PRIMARY KEY (external_db_id),
  UNIQUE KEY db_name_idx (db_name,db_release,is_current)
);

-- The 'master_misc_set' table
-- Lists the existing misc_sets
CREATE TABLE master_misc_set (
  misc_set_id               SMALLINT(5) UNSIGNED NOT NULL AUTO_INCREMENT,
  code                      VARCHAR(25) NOT NULL DEFAULT '',
  name                      VARCHAR(255) NOT NULL DEFAULT '',
  description               TEXT NOT NULL,
  max_length                INT(10) UNSIGNED NOT NULL,
  is_current                TINYINT(1) NOT NULL DEFAULT '1',

  -- Columns for the web interface:
  created_by    INT,
  created_at    DATETIME,
  modified_by   INT,
  modified_at   DATETIME,

  PRIMARY KEY (misc_set_id),
  UNIQUE KEY code_idx (code)
);


-- The 'master_unmapped_reason' table
-- Lists the existing unmapped_reasons
CREATE TABLE master_unmapped_reason (
  unmapped_reason_id        INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  summary_description       VARCHAR(255) DEFAULT NULL,
  full_description          VARCHAR(255) DEFAULT NULL,
  is_current                TINYINT(1) NOT NULL DEFAULT '1',

  -- Columns for the web interface:
  created_by    INT,
  created_at    DATETIME,
  modified_by   INT,
  modified_at   DATETIME,

  PRIMARY KEY (unmapped_reason_id)
);

-- VIEWS

-- Views for the master tables.  These views are simply selecting the
-- entries from the corresponding master table that have is_current
-- set to true.

CREATE DEFINER = CURRENT_USER SQL SECURITY INVOKER VIEW attrib_type AS
SELECT
  attrib_type_id AS attrib_type_id,
  code AS code,
  name AS name,
  description AS description
FROM    master_attrib_type
WHERE   is_current = true
ORDER BY attrib_type_id;

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

CREATE DEFINER = CURRENT_USER SQL SECURITY INVOKER VIEW biotype AS
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

CREATE DEFINER = CURRENT_USER SQL SECURITY INVOKER VIEW external_db AS
SELECT
  external_db_id AS external_db_id,
  db_name AS db_name,
  db_release AS db_release,
  status AS status,
  priority AS priority,
  db_display_name AS db_display_name,
  type AS type,
  secondary_db_name AS secondary_db_name,
  secondary_db_table AS secondary_db_table,
  description AS description
FROM    master_external_db
WHERE   is_current = true
ORDER BY external_db_id;

CREATE DEFINER = CURRENT_USER SQL SECURITY INVOKER VIEW misc_set AS
SELECT
  misc_set_id AS misc_set_id,
  code AS code,
  name AS name,
  description AS description,
  max_length AS max_length
FROM    master_misc_set
WHERE   is_current = true
ORDER BY misc_set_id;

CREATE DEFINER = CURRENT_USER SQL SECURITY INVOKER VIEW unmapped_reason AS
SELECT
  unmapped_reason_id AS unmapped_reason_id,
  summary_description AS summary_description,
  full_description AS full_description
FROM    master_unmapped_reason
WHERE   is_current = true
ORDER BY unmapped_reason_id;
