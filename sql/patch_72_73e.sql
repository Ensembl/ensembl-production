ALTER TABLE biotype MODIFY COLUMN db_type set('cdna', 'core', 'coreexpressionatlas','coreexpressionest', 'coreexpressiongnf', 'funcgen',
                                              'otherfeatures', 'rnaseq', 'variation', 'vega', 'presite', 'sangerverga') NOT NULL DEFAULT 'core';
ALTER TABLE meta_key MODIFY COLUMN db_type SET('cdna','core','funcgen','otherfeatures','rnaseq','variation','vega','presite','sangervega') NOT NULL DEFAULT 'core' ;


-- Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'path', 'patch_72_73e.sql|new db_types');
