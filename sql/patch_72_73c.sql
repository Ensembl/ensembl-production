ALTER TABLE biotype MODIFY COLUMN db_type set('cdna', 'core', 'coreexpressionatlas','coreexpressionest', 'coreexpressiongnf', 'funcgen',
                                              'otherfeatures', 'rnaseq', 'variation', 'vega', 'presite', 'sangerverga') NOT NULL DEFAULT 'core';
ALTER TABLE biotype ADD COLUMN biotype_group ENUM('coding','pseudogene','snoncoding','lnoncoding','undefined') DEFAULT NULL;

-- Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'path', 'patch_72_73c.sql|biotype group in biotype table');
