select ensembl_species_history_id, species, assembly_accession as assembly, ensembl_release as release
  from ensembl_gifts.ensembl_species_history
  where ensembl_release = ?
  order by ensembl_species_history_id
