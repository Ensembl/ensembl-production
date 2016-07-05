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

# patch_79_80c.sql
#
# Title: Use auto_increment for the master_attrib table.
#
# Description:
# Use auto_increment for the 'attrib_id' column in the 'master_attrib' table

ALTER TABLE master_attrib CHANGE attrib_id attrib_id INT(11) UNSIGNED NOT NULL AUTO_INCREMENT;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
VALUES (NULL, 'patch', 'patch_79_80c.sql|use_auto_increment_for_the_master_attrib_table');
