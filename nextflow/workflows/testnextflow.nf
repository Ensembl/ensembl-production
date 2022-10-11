// Declare syntax version
nextflow.enable.dsl=2
// Script parameters
params.query = "/some/data/sample.fa"
params.db = "/some/path/pdb"

process blastSearch {
  input:
    path query
    path db
  output:
    path "top_hits.txt"

    """
    blastp -db $db -query $query -outfmt 6 > blast_result
    cat blast_result | head -n 10 | cut -f 2 > top_hits.txt
    """
}

process extractTopHits {
  input:
    path top_hits

  output:
    path "sequences.txt"

    """
    blastdbcmd -db $db -entry_batch $top_hits > sequences.txt
    """
}

workflow {
   def query_ch = Channel.fromPath(params.query)
   blastSearch(query_ch, params.db) | extractTopHits | view
}
