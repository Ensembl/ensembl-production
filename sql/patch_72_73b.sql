alter table species add unique index species_prefix_idx(species_prefix) ;
alter table species add unique index taxon_idx(taxon) ;
alter table species add unique index production_name_idx(production_name) ;
alter table species modify column species_prefix varchar(7) not null ;

-- Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_72_73b.sql|add constraints on species columns');
