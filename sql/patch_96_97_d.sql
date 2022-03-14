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


# patch_96_97_d.sql
#
# Title: Analysis_description update
#
# Description:
#   Remove species association from analysis_description and minro changes to web_data
ALTER TABLE web_data ADD COLUMN description varchar(255);
DROP VIEW full_analysis_description;
DROP VIEW logic_name_overview;
DROP VIEW unconnected_analyses;
DROP VIEW unused_web_data;
DROP TABLE analysis_web_data;
UPDATE analysis_description set default_displayable=0 where default_displayable is null;
ALTER TABLE analysis_description CHANGE COLUMN default_web_data_id web_data_id INT(1);
ALTER TABLE analysis_description CHANGE COLUMN default_displayable displayable TINYINT(1) NOT NULL;
# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_96_97_d.sql|analysis_description_update');
