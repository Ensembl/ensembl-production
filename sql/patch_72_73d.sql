ALTER TABLE changelog ADD COLUMN mitochondrion ENUM('Y', 'N', 'changed') NOT NULL DEFAULT 'N';


-- Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'path', 'patch_72_73d.sql|mitochondrion in changelog');
