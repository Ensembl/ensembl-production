alter table analysis_description add column default_displayable BOOLEAN;

-- Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_71_72b.sql|add default_displayable to analysis_description');
