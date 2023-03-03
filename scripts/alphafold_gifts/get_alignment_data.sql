select al.uniprot_id, al.transcript_id, et.enst_id, ue.uniprot_acc
  from ensembl_gifts.alignment al
  inner join ensembl_gifts.alignment_run alr ON alr.alignment_run_id = al.alignment_run_id
  inner join ensembl_gifts.release_mapping_history rmh ON rmh.release_mapping_history_id = alr.release_mapping_history_id
  inner join ensembl_gifts.ensembl_species_history esh ON esh.ensembl_species_history_id = rmh.ensembl_species_history_id
  inner join ensembl_gifts.ensembl_transcript et ON et.transcript_id = al.transcript_id
  inner join ensembl_gifts.uniprot_entry ue ON ue.uniprot_id = al.uniprot_id
  where score1_type = 'perfect_match'
    and alr.ensembl_release = esh.ensembl_release
    and rmh.ensembl_species_history_id = ?
