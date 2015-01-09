-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

# Table structure for projection info database

CREATE TABLE projections (

  db_release					INT NOT null,
  timestamp					DATETIME,
  from_db					VARCHAR(255),
  from_species_latin				VARCHAR(255),
  from_species_common				VARCHAR(255),
  to_db					        VARCHAR(255),
  to_species_latin				VARCHAR(255),
  to_species_common				VARCHAR(255)
  
);
