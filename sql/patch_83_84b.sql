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

# patch_83_84b.sql
#
# Title: Add division related tables
#
# Description: Add division and division_species tables

CREATE TABLE division (
  division_id INT(10) unsigned NOT NULL AUTO_INCREMENT,
  name VARCHAR(32) NOT NULL,
  shortname VARCHAR(4) NOT NULL,
  PRIMARY KEY (division_id),
  UNIQUE KEY name_idx (name),
  UNIQUE KEY shortname_idx (shortname)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE division_species (
  division_id INT(10) DEFAULT NULL,
  species_id INT(10) DEFAULT NULL,
  UNIQUE KEY division_species_idx (division_id,species_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE division_db (
  division_id INT(10) DEFAULT NULL,
  db_name VARCHAR(64) NOT NULL,
  db_type ENUM('COMPARA','GENE_MART','SEQ_MART','SNP_MART','FEATURES_MART','ONTOLOGY_MART','ONTOLOGY','TAXONOMY','ANCESTRAL','WEBSITE','INFO') NOT NULL,
  is_current TINYINT(1) NOT NULL DEFAULT '1',
  update_type ENUM('NEW_GENOME','NEW_ASSEMBLY','NEW_GENEBUILD','PATCHED','OTHER') DEFAULT 'PATCHED',
  release_status ENUM('NOT_READY','COMPARA_READY','WEB_READY') DEFAULT 'NOT_READY',
  UNIQUE KEY division_db_idx (division_id,db_name,is_current)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_83_84b.sql|division_tables');
