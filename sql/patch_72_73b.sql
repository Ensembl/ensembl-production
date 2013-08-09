ALTER TABLE species ADD UNIQUE INDEX species_prefix_idx(species_prefix) ;
ALTER TABLE species ADD UNIQUE INDEX taxon_idx(taxon) ;
ALTER TABLE species ADD UNIQUE INDEX production_name_idx(production_name) ;
ALTER TABLE species MODIFY COLUMN species_prefix varchar(7) not null ;

-- Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_72_73b.sql|add constraints on species columns');
