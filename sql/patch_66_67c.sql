-- Patching in support for comments on web data

ALTER TABLE web_data
ADD COLUMN comment TEXT 
AFTER data;

-- Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_66_67c.sql|Patching in support for comments on web data');