-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

# Versioning db table definitions
#

# Conventions:
#  - use lower case and underscores
#  - internal ids are integers named tablename_id
#  - same name is given in foreign key relations

CREATE TABLE checksum_xref (
  checksum_xref_id  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  source_id         INT UNSIGNED NOT NULL,
  accession         CHAR(14) NOT NULL,
  checksum          CHAR(32) NOT NULL,

  PRIMARY KEY (checksum_xref_id),
  INDEX checksum_idx(checksum(10))
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


CREATE TABLE source (
  source_id                INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  name                     VARCHAR(128),
  active                   BOOLEAN NOT NULL DEFAULT 1,
  parser                   VARCHAR(128),

  PRIMARY KEY (source_id),
  UNIQUE KEY name_idx (name)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

CREATE TABLE version (
  version_id               INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  source_id                INT(10) UNSIGNED,
  revision                 VARCHAR(255),
  count_seen               INT(10) UNSIGNED NOT NULL,
  uri                      VARCHAR(255),
  index_uri                VARCHAR(255),
  clean_uri                VARCHAR(255),
  preparse                 BOOLEAN NOT NULL DEFAULT 0,

  PRIMARY KEY (version_id),
  KEY version_idx (source_id, revision),
  FOREIGN KEY (source_id) REFERENCES source(source_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

