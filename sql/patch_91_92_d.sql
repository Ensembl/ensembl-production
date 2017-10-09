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

# patch_91_92_d.sql
#
# Title: Analysis_description update
#
# Description:
#   Remove species association from analysis_description and rework how web_data is stored
ALTER TABLE web_data ADD COLUMN description varchar(255);
CREATE TABLE web_data_element (
  web_data_id               INTEGER UNSIGNED NOT NULL,
  data_key                  VARCHAR(32) NOT NULL,
  data_value               TEXT,

  -- Columns for the web interface:
  created_by    INTEGER,
  created_at    DATETIME,
  modified_by   INTEGER,
  modified_at   DATETIME,

  PRIMARY KEY (web_data_id)   
);

INSERT INTO web_data_element(web_data_id,data_key,data_value) (SELECT web_data_id,"hash",data FROM web_data);
DROP VIEW full_analysis_description;
DROP VIEW logic_name_overview;
DROP VIEW unconnected_analyses;
DROP TABLE analysis_web_data;
ALTER TABLE web_data DROP COLUMN data;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_91_92_d.sql|analysis_description_update');
