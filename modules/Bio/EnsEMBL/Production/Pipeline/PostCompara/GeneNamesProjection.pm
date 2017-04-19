=pod 

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneNamesProjection

=cut

=head1 DESCRIPTION

 Pipeline to project gene display_xref 
 from one species to another by using the homologies derived 
 from the Compara ProteinTree pipeline. 

 Normally this is used to project from a well annotated species to one which is not.

=head1 AUTHOR 

ckong

=cut
package Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneNamesProjection;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Production::Pipeline::PostCompara::Base');

sub run {
    my ($self) = @_;

    my $to_species 	 = $self->param_required('species');
    my $from_species     = $self->param_required('source');
    my $compara          = $self->param_required('compara');
    my $release          = $self->param_required('release');
    my $method_link_type = $self->param_required('method_link_type');
    my $output_dir             = $self->param_required('output_dir');

    print "Processing names projection from $from_species to $to_species\n";

    # Creating adaptors
    my $from_ga   = Bio::EnsEMBL::Registry->get_adaptor($from_species, 'core', 'Gene');
    my $to_ga     = Bio::EnsEMBL::Registry->get_adaptor($to_species  , 'core', 'Gene');
    my $to_ta     = Bio::EnsEMBL::Registry->get_adaptor($to_species  , 'core', 'Transcript');
    my $to_dbea   = Bio::EnsEMBL::Registry->get_adaptor($to_species  , 'core', 'DBEntry');
    die("Problem getting DBadaptor(s) - check database connection details\n") if (!$from_ga || !$to_ga || !$to_ta || !$to_dbea);

   my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet'); 
   my $ha    = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'Homology'); 
   my $gdba  = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", 'GenomeDB'); 
   die "Can't connect to Compara database specified by $compara - check command-line and registry file settings" if (!$mlssa || !$ha ||!$gdba);
    # Write projection info metadata
    $self->check_directory($output_dir);
    my $log_file  = $output_dir."/".$from_species."-".$to_species."_GeneNamesProjection_logs.txt";
    open my $log,">","$log_file" or die $!;
    print $log "\n\tProjection log :\n";
    print $log "\t\tsoftware release :$release\n";
    print $log "\t\tfrom :".$from_ga->dbc()->dbname()." to :".$to_ga->dbc()->dbname()."\n";

    # Build Compara GenomeDB objects
    my $from_GenomeDB = $gdba->fetch_by_registry_name($from_species);
    my $to_GenomeDB   = $gdba->fetch_by_registry_name($to_species);
    print $from_GenomeDB->dbID()."\n";
    print $to_GenomeDB->dbID()."\n";
    my $mlss          = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$from_GenomeDB, $to_GenomeDB]);
    if(!defined $mlss) {
      print "No $method_link_type found between $from_species and $to_species";
      return;
    }

    my $mlss_id       = $mlss->dbID();
    # build hash of external db name -> ensembl object type mappings
    my $db_to_type = build_db_to_type($to_ga);
    my $source_db_to_type = build_db_to_type($from_ga);

    # Get homologies from compara - comes back as a hash of arrays
    print $log "\n\tRetrieving homologies of method link type $method_link_type for mlss_id $mlss_id \n";
    my $homologies    = $self->fetch_homologies($ha, $mlss, $from_species, $log, $gdba, $self->param('homology_types_allowed'), $self->param('is_tree_compliant'), $self->param('percent_id_filter'), $self->param('percent_cov_filter'));

    print $log "\n\tProjecting Gene Names & descriptions from $from_species to $to_species\n\n";

    my $total_genes   = scalar(keys %$homologies);

    while (my ($from_stable_id, $to_genes) = each %{$homologies}) {
       my $from_gene  = $from_ga->fetch_by_stable_id($from_stable_id);
       next if (!$from_gene);
       my $gene_nbr=1;
       foreach my $to_stable_id (@{$to_genes}) {
            my $to_gene  = $to_ga->fetch_by_stable_id($to_stable_id);
            next if (!$to_gene);
            if (defined $self->param('project_xrefs') and $self->param('project_xrefs')==1)
            {
              $self->project_xrefs_genenames($to_dbea, $from_gene, $to_gene, $log, scalar(@{$to_genes}), $source_db_to_type);
              
            }
            $self->project_display_xrefs_genenames($to_ga, $to_ta, $to_dbea, $from_gene, $to_gene, $log, scalar(@{$to_genes}),  $db_to_type);
       }
        $gene_nbr++;
    }
    close($log);

    #Disconnecting from the registry
    $from_ga->dbc->disconnect_if_idle();
    $to_ga->dbc->disconnect_if_idle();
    $mlssa->dbc->disconnect_if_idle();
return;
}

sub write_output {
    my ($self) = @_;

}

######################
## internal methods
######################
sub project_display_xrefs_genenames {
    my ($self, $to_geneAdaptor, $to_transcriptAdaptor, $to_dbea, $from_gene, $to_gene, $log, $total_gene_number, $db_to_type)  = @_;

    my $flag_store_proj  = $self->param_required('flag_store_projections');
    my $from_species     = $self->param_required('source');
    my $to_species       = $self->param_required('species');
    my $geneName_source  = $self->param_required('geneName_source');
    my $compara          = $self->param_required('compara');

    # Decide if a gene name should be overwritten
    # Criteria: overwrite if:
    #    - no existing display_xref
    # or
    #    - existing display_xref is RefSeq_*_predicted
    #      AND from_gene is from "best" source external db,
    #      e.g. HGNC in homo_sapiens, MGI in mus_musculus

    if(defined $from_gene->display_xref() && check_overwrite_display_xref($from_gene, $to_gene, $from_species, $to_species)) {
       my $from_gene_dbname     = $from_gene->display_xref->dbname();
       my $from_gene_display_id = $from_gene->display_xref->display_id();         

       return if ($from_gene->status eq 'KNOWN_BY_PROJECTION');

       # Skip clone names if projecting all sources
       return if (lc($from_gene_dbname) =~ /clone/);

       # Get all DBEntries for 'source gene' base on the dbname of display_xref  
       foreach my $dbEntry (@{$from_gene->get_all_DBEntries($from_gene_dbname)}) { 

          if($dbEntry->display_id=~/$from_gene_display_id/  && $flag_store_proj==1 && grep (/$from_gene_dbname/, @$geneName_source)){

             print $log "\t\tProject display xref from:".$from_gene->stable_id()."\t";
             print $log "to:".$to_gene->stable_id()."\t";
             print $log "GeneName:".$from_gene_display_id."\t";
             print $log "DB:".$from_gene_dbname."\n";

             # Modify the dbEntry to indicate it's not from this species - set info_type & info_text
             my $info_txt = "from $from_species gene " . $from_gene->stable_id();

             # modify the display_id to have "(1 of many)" if this is a one-to-many ortholog
             my $tuple_txt = "";
             if ($total_gene_number > 1) {
               $tuple_txt = " (1 of many)";
               my $existing = $dbEntry->display_id();
               $existing =~ s/ \(1 of many\)//;
               $dbEntry->display_id($existing . $tuple_txt);
               $info_txt .= $tuple_txt;
             }
             # For the Ensembl species, logic for Gene and Transcript
             if ($compara eq "Multi"){
               $self->project_display_xrefs_ensembl($to_dbea, $to_gene, $dbEntry, $db_to_type, $info_txt, $to_geneAdaptor, $to_transcriptAdaptor);
             }
            # For EG species
            else {
              $self->project_display_xrefs_ensembl_genomes($dbEntry, $from_gene, $to_dbea, $to_gene, $to_geneAdaptor, $from_species);
            }
         }
      }
   }
}

# Project all the xrefs from a species to another and store them as type PROJECTION
sub project_xrefs_genenames {
    my ($self, $to_dbea, $from_gene, $to_gene, $log, $total_gene_number, $source_db_to_type)  = @_;

    my $flag_store_proj  = $self->param_required('flag_store_projections');
    my $from_species     = $self->param_required('source');
    my $white_list  = $self->param('white_list');

    foreach my $dbEntry (@{$from_gene->get_all_DBLinks()}) {
      my @to_transcripts = @{$to_gene->get_all_Transcripts};
      my $to_transcript = $to_transcripts[0];

      my $dbname = $dbEntry->dbname();
      my $type = $source_db_to_type->{$dbname};

      # Skip xref if it's not in the white list. Only project xrefs from the white list.
      next if (!grep (/$dbname/, @$white_list));

      if ($flag_store_proj==1){
        
        print $log "\t\tProject xref from:".$from_gene->stable_id()."\t";
        print $log "to:".$to_gene->stable_id()."\t";
        print $log "Xref:".$dbEntry->display_id()."\t";
        print $log "DB:".$dbname."\n";

        # Modify the dbEntry to indicate it's not from this species - set info_type & info_text
        my $info_txt = "from $from_species gene " . $from_gene->stable_id();

        # modify the display_id to have "(1 of many)" if this is a one-to-many ortholog
        my $tuple_txt = "";
        if ($total_gene_number > 1) {
          $tuple_txt = " (1 of many)";
          my $existing = $dbEntry->display_id();
          $existing =~ s/ \(1 of many\)//;
          $dbEntry->display_id($existing . $tuple_txt);
          $info_txt .= $tuple_txt;
        }

        $dbEntry->info_type("PROJECTION");
        $dbEntry->info_text($info_txt);

        if ($type eq "Gene") {
          $to_gene->add_DBEntry($dbEntry);
          $to_dbea->store($dbEntry, $to_gene->dbID(), 'Gene', 1);
        }
        elsif ($type eq "Transcript") {
          $to_transcript->add_DBEntry($dbEntry);
          $to_dbea->store($dbEntry, $to_transcript->dbID(), 'Transcript', 1);
        }
        elsif ($type eq "Translation") {
          my $to_translation = $to_transcript->translation();
          return if (!$to_translation);
          $to_translation->add_DBEntry($dbEntry);
          $to_dbea->store($dbEntry, $to_translation->dbID(), 'Translation',1);
        }
      }
    }
}
# ----------------------------------------------------------------------

# Decide if a gene name should be overwritten
# Criteria: overwrite if:
#    - no existing display_xref
# or
#    - existing display_xref is RefSeq_*_predicted
#      AND from_gene is from "best" source external db,
#      e.g. HGNC in homo_sapiens, MGI in mus_musculus

sub check_overwrite_display_xref {
  #To means target & from means the projection source e.g. to == sus_scrofa & from  == homo_sapiens
  my ($from_gene, $to_gene, $from_species, $to_species) = @_;
  
  my $from_dbname= $from_gene->display_xref->dbname();
  my $to_dbname = $to_gene->display_xref->dbname() if ($to_gene->display_xref());
  $to_dbname ||= q{}; #can be empty; this stops warning messages

  #Exit early if we had an external name & the species was not danio_rerio, sus_scrofa or mouse
  return 1 if (!$to_gene->external_name() && $to_species ne "danio_rerio" && $to_species ne 'sus_scrofa' && $to_species ne 'mus_musculus');

  #Exit early if it was a RefSeq predicted name & source was a vetted good symbol
  if ($to_dbname eq "RefSeq_mRNA_predicted" || $to_dbname eq "RefSeq_ncRNA_predicted" || $to_dbname eq "RefSeq_peptide_predicted") {
    if (  ($from_species eq "homo_sapiens" && $from_dbname =~ /HGNC/) ||
          ($from_species eq "mus_musculus" && $from_dbname =~ /MGI/) ||
          ($from_species eq "danio_rerio" && $from_dbname =~ /ZFIN_ID/)) {
      if ($to_species eq "danio_rerio" and is_in_blacklist($from_gene->display_xref)){
        return 0;
      }
      return 1;
    }
  }
  #Zebrafish specific logic; do not re-write!
  elsif ($to_species eq "danio_rerio"){

    my $to_dbEntry = $to_gene->display_xref();
    my $from_dbEntry = $from_gene->display_xref();
    my $to_seq_region_name = $to_gene->seq_region_name();

    return 1 if ($to_dbname eq "Clone_based_ensembl_gene" or $to_dbname eq "Clone_based_vega_gene");

    my $name = $from_gene->display_xref->display_id;
    $name =~ /(\w+)/; # remove (x of y) in name.
    $name = $1;

     if ( $name =~ /C(\w+)orf(\w+)/){
         my $new_name = "C".$to_seq_region_name."H".$1."orf".$2;
        $from_gene->display_xref->display_id($new_name);
        return 1;
    }

    if (!defined ($to_dbEntry) || (($to_dbEntry->display_id =~ /:/) and $to_dbname eq "ZFIN_ID") ){
      if (is_in_blacklist($from_dbEntry)){
              return 0;
      }
      else{
              return 1;
      }
    }
  }
  #Pig specific logic; 
  # Replace any UP & Entrez names
  # Look for Vega/Ensembl specific clone names (CU9???.1)
  elsif($to_species eq 'sus_scrofa') {
    my %clone_overwrites  = map { $_ => 1 } qw/Clone_based_vega_gene Clone_based_ensembl_gene/;
    return 1 if $clone_overwrites{$to_dbname};
    my $to_dbEntry = $to_gene->display_xref();
    if (!defined $to_dbEntry) {
      return 1;
    }
    my $name = $to_dbEntry->display_id;
    #Want to over-write clone ids like CU914217.1, CT914217.1, FP565183.2
    #Bad prefixes are: AP, BX, CR, CT, CU, FP, FQ
    if($name =~ /^(?: C[RTU] | AP | BX | F[PQ])\d+\.\d+$/xms) {
      return 1;
    }
    if($name =~ /^AEMK/) {
      return 1;
    }
    #Get rid of names like DUROC-C7H6orf31 and CXorf36
    if($name =~ /orf/) {
      return 1;
    }
  }
  elsif ($to_species eq 'mus_musculus' || $to_species eq 'rattus_norvegicus') {
    my %clone_overwrites  = map { $_ => 1 } qw/Clone_based_vega_gene Clone_based_ensembl_gene/;
    return 1 if $clone_overwrites{$to_dbname};
    my $to_dbEntry = $to_gene->display_xref();
    if (!defined $to_dbEntry) {
      return 1;
    }
  }
  return 0;

}

# create a hash of external_db_name -> ensembl_object_type
# used to assign projected xrefs to the "correct" type

sub build_db_to_type {

  my ($to_ga) = @_;

  my $db_to_type;

  my $sth = $to_ga->dbc()->prepare("SELECT DISTINCT e.db_name, ox.ensembl_object_type FROM external_db e, xref x, object_xref ox WHERE x.xref_id=ox.xref_id AND e.external_db_id=x.external_db_id");
  $sth->execute();
  my ($db_name, $type);
  $sth->bind_columns(\$db_name, \$type);
  while($sth->fetch()){
    $db_to_type->{$db_name} = $type;
  }
  $sth->finish;

  return $db_to_type;

}

sub overwrite_transcript_display_xrefs {
  my ($to_gene, $ref_dbEntry, $info_txt) = @_;
  my $transcripts = $to_gene->get_all_Transcripts();
  my @havana = grep { 
    $_->analysis->logic_name eq 'ensembl_havana_transcript' ||
    $_->analysis->logic_name eq 'proj_ensembl_havana_transcript' ||
    $_->analysis->logic_name eq 'havana' ||
    $_->analysis->logic_name eq 'proj_havana' ||
    $_->analysis->logic_name eq 'havana_ig_gene' ||
    $_->analysis->logic_name eq 'proj_havana_ig_gene'
  } @{$transcripts};
  my @ensembl = grep { 
    $_->analysis->logic_name eq 'ensembl' ||
    $_->analysis->logic_name eq 'proj_ensembl' ||
    $_->analysis->logic_name eq 'ensembl_projection' ||
    $_->analysis->logic_name eq 'ensembl_ig_gene'
  } @{$transcripts};
  _process_transcripts($ref_dbEntry, $info_txt, 1, \@havana);
  _process_transcripts($ref_dbEntry, $info_txt, 201, \@ensembl);
  return;
}

# Loop through the transcripts, set the expected SYMBOL-001 for havana & SYMBOL-201 for the rest
# Attach the DBEntry and leave until later which will store the entry on the transcript
sub _process_transcripts {
  my ($ref_dbEntry, $info_txt, $offset, $transcripts) = @_;
  my $from_dbname = $ref_dbEntry->dbname();
  my $base_name  = $ref_dbEntry->display_id();
  foreach my $t (@{$transcripts}) {
    my $name = sprintf('%s-%03d', $base_name, $offset);
    my $dbname = "${from_dbname}_trans_name";
    my $xref = Bio::EnsEMBL::DBEntry->new(
      -PRIMARY_ID => $name, -DISPLAY_ID => $name, -DBNAME => $dbname,
      -INFO_TYPE => 'PROJECTION', -INFO_TEXT => $info_txt,
      -DESCRIPTION => $ref_dbEntry->description(),
    );
    $t->display_xref($xref);
    $offset++;
  }
  return;
}

sub is_in_blacklist{
    #catches clones and analyses when projecting display xrefs.
    my ($dbentry) = shift;

    if (($dbentry->display_id =~ /KIAA/) || ( $dbentry->display_id =~ /LOC/)){
       return 1; # return yes that have found gene names that match the regular expression
    }
    elsif ($dbentry->display_id =~ /\-/){
       return 1;
    }
    elsif ($dbentry->display_id =~ /\D{2}\d{6}\.\d+/){
       #print "black listed item found ".$dbentry->display_id."\n";
        return 1;
    }
    else{
        return 0;
    }
    
}

###Ensembl species
# Add the xref to the "to" gene, or transcript or translation depending on what the
# other xrefs from this dbname as assigned to (see build_db_to_type)
# Note that if type is not found, it means that we're dealing with a db that has no
# xrefs in the target database, e.g. MarkerSymbol in mus_musculus -> rattus_norvegicus
# In this case just assign to genes

sub project_display_xrefs_ensembl{
  my ($self, $to_dbea, $to_gene, $dbEntry, $db_to_type, $info_txt, $to_geneAdaptor, $to_transcriptAdaptor )  = @_;
  # Adding projection source information
  $dbEntry->info_type("PROJECTION");
  $dbEntry->info_text($info_txt);

  my @to_transcripts = @{$to_gene->get_all_Transcripts};
  my $to_transcript = $to_transcripts[0];

  # Force loading of external synonyms for the xref
  $dbEntry->get_all_synonyms();

  my $dbname = $dbEntry->dbname();

  my $type = $db_to_type->{$dbname};

  if ($type eq "Gene" || $dbname eq 'HGNC' || !$type) {
    $to_gene->add_DBEntry($dbEntry);
    $to_dbea->store($dbEntry, $to_gene->dbID(), 'Gene', 1);
  }
  elsif ($type eq "Transcript" || $dbname eq 'HGNC_trans_name') {
    $to_transcript->add_DBEntry($dbEntry);
    $to_dbea->store($dbEntry, $to_transcript->dbID(), 'Transcript', 1);
  }
  elsif ($type eq "Translation") {
    my $to_translation = $to_transcript->translation();
    return if (!$to_translation);
    $to_translation->add_DBEntry($dbEntry);
    $to_dbea->store($dbEntry, $to_translation->dbID(), 'Translation',1);
  }
  else {
    warn("Can't deal with xrefs assigned to $type (dbname=" . $dbEntry->dbname . ")\n");
    return;
  }

  # Set gene status to "KNOWN_BY_PROJECTION" and update display_xref
  $to_gene->status("KNOWN_BY_PROJECTION");
  $to_gene->display_xref($dbEntry);
  # Set SYMBOL-001 for havana & SYMBOL-201 for the rest
  overwrite_transcript_display_xrefs($to_gene, $dbEntry, $info_txt);
  # update the gene so that the display_xref_id is set and the
  $to_geneAdaptor->update($to_gene);
  foreach my $transcript (@to_transcripts) {
    # Set the status of the gene's transcripts to "KNOWN_BY_PROJECTION"
    $transcript->status("KNOWN_BY_PROJECTION");
    #Now assign names to the transcripts;
    my $display = $transcript->display_xref();
    if ($display){
      $transcript->add_DBEntry($display);
      $to_dbea->store($display, $transcript->dbID(), 'Transcript', 1);
    }
    # Set the status & display xref if applicable for the gene's transcripts
    $to_transcriptAdaptor->update($transcript);
  }
}

sub project_display_xrefs_ensembl_genomes{
  my ($self, $dbEntry, $from_gene, $to_dbea, $to_gene, $to_geneAdaptor, $from_species) = @_;
  $dbEntry->info_type("PROJECTION");
  $dbEntry->info_text("projected from $from_species,".$from_gene->stable_id());

  $to_dbea->store($dbEntry,$to_gene->dbID(), 'Gene', 1);
  $to_gene->display_xref($dbEntry);
  $to_geneAdaptor->update($to_gene);
}

1
