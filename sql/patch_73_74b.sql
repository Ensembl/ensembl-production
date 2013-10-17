ALTER TABLE master_external_db MODIFY COLUMN db_display_name VARCHAR(255) NOT NULL;

-- Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'path', 'patch_73_74b.sql|db_display_name_not_null');
