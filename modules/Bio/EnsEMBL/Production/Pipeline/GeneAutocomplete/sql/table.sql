-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
DROP TABLE IF EXISTS gene_autocomplete;
CREATE TABLE gene_autocomplete (
  species       varchar(255) DEFAULT NULL,
  stable_id     varchar(128) NOT NULL DEFAULT "",
  display_label varchar(128) DEFAULT NULL,
  location      varchar(60)  DEFAULT NULL,
  db            varchar(32)  NOT NULL DEFAULT "core",
  KEY i  (species, display_label),
  KEY i2 (species, stable_id),
  KEY i3 (species, display_label, stable_id)) ENGINE=MyISAM;