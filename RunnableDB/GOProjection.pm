=pod 

=head1 NAME

Bio::EnsEMBL::Pipeline::ProjectGOTerms::RunnableDB::GOProjection

=cut

=head1 DESCRIPTION

 Re-implementation of the code currently held in Ensembl's core API checkout 
 (misc-scripts/xref_projection/project_display_xrefs.pl) which can project 
 'GO' DBEntries from one species to another by using the homologies projected 
 from the Compara ProteinTree pipeline. 

 Normally this is used to project GO terms from a well annotated species to one which is not.

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOProjection;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use LWP;
use JSON;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
          
	   };
}

my ($flag_go_check, $flag_store_projections, $flag_full_stats, $flag_delete_go_terms, $flag_backup);
my ($to_species, $from_species);
my ($mlssa, $ha, $ma, $gdba);
my ($compara, $release, $ensemblObj_type, $goa_webservice, $goa_params);
my ($method_link_type, $homology_types_allowed, $evidence_codes, $percent_id_filter);
my ($log_file, $output_dir, $data);
my (%forbidden_terms, %projections_by_evidence_type, %projections_stats);

sub fetch_input {
    my ($self) = @_;

    $flag_go_check          = $self->param('flag_go_check');
    $flag_store_projections = $self->param('flag_store_projections');
    $flag_full_stats        = $self->param('flag_full_stats');
    $flag_delete_go_terms   = $self->param('flag_delete_go_terms');
    $flag_backup            = $self->param('flag_backup');

    $to_species             = $self->param('to_species');
    $from_species           = $self->param('from_species');
    $compara                = $self->param('division');
    $release                = $self->param('release');
    $ensemblObj_type        = $self->param('ensemblObj_type');

    $goa_webservice         = $self->param('goa_webservice');
    $goa_params             = $self->param('goa_params');
    $method_link_type       = $self->param('method_link_type');
    $homology_types_allowed = $self->param('homology_types_allowed ');
    $evidence_codes         = $self->param('evidence_codes');
    $percent_id_filter      = $self->param('percent_id_filter');
    $log_file               = $self->param('output_dir');
    $output_dir             = $self->param('output_dir');
 
    $self->throw('to_species, from_species, division, release, goa_webservice, goa_params, method_link_type, homology_types_allowed, evidence_codes, log_file are obligatory parameters') unless (defined $to_species && defined $from_species && defined $release && defined $goa_webservice && defined $goa_params && defined $compara && defined $method_link_type && defined $homology_types_allowed && defined $evidence_codes && defined $log_file);

return;
}

sub run {
    my ($self) = @_;

    Bio::EnsEMBL::Registry->set_disconnect_when_inactive();
    Bio::EnsEMBL::Registry->disconnect_all();

    # Connection to Oracle DB for taxon constraint 
    my $dsn_goapro = 'DBI:Oracle:host=ora-vm-026.ebi.ac.uk;sid=goapro;port=1531';
    my $user       = 'goselect';
    my $pass       = 'selectgo';
    my $hDb        = DBI->connect($dsn_goapro, $user, $pass, {PrintError => 1, RaiseError => 1}) or die "Cannot connect to server: " . DBI->errstr;
    my $sql        = "select go.goa_validation.taxon_check_term_taxon(?,?) from dual";
 
    my $from_ga    = Bio::EnsEMBL::Registry->get_adaptor($from_species, 'core', 'Gene');
    my $to_ga      = Bio::EnsEMBL::Registry->get_adaptor($to_species, 'core', 'Gene');
    my $to_ta      = Bio::EnsEMBL::Registry->get_adaptor($to_species, 'core', 'Transcript');
    my $to_dbea    = Bio::EnsEMBL::Registry->get_adaptor($to_species, 'core', 'DBEntry');
    die("Problem getting DBadaptor(s) - check database connection details\n") if (!$from_ga || !$to_ga || !$to_ta || !$to_dbea);
    
    # Interrogate GOA web service for forbidden GO terms for the given species.
    # This requires both a lookup, and then finding all child-terms on the forbidden list.
    # The forbidden_terms list is used in unwanted_go_term();
    %forbidden_terms  = get_GOA_forbidden_terms($to_species);

    # Getting ancestry taxon_ids
    my $to_latin_species = ucfirst(Bio::EnsEMBL::Registry->get_alias($to_species));
    my $meta_container   = Bio::EnsEMBL::Registry->get_adaptor($to_latin_species,'core','MetaContainer');
    my ($to_taxon_id)    = @{ $meta_container->list_value_by_key('species.taxonomy_id')};

    # Get Compara adaptors - use the one specified on the command line
    if ($compara) {
       $mlssa = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet');
       $ha    = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'Homology');
       $ma    = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'Member');
       $gdba  = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", "GenomeDB");
       die "Can't connect to Compara database specified by $compara - check command-line and registry file settings" if (!$mlssa || !$ha || !$ma ||!$gdba);
    }

    $self->check_directory($log_file);
    $log_file  = $log_file."/".$from_species."-".$to_species."_GOTermsProjection_logs.txt";
    open $data,">","$log_file" or die $!;

    # Write projection info metadata
    print $data "\n\tProjection log :\n";
    print $data "\t\trelease             :$release\n";
    print $data "\t\tfrom_db             :".$from_ga->dbc()->dbname()."\n";
    print $data "\t\tfrom_species_common :$from_species\n";
    print $data "\t\tto_db               :".$to_ga->dbc()->dbname()."\n";
    print $data "\t\tto_species_common   :$to_species\n";

    backup($to_ga,$to_species)if($flag_backup==1);
    delete_go_terms($to_ga)   if($flag_delete_go_terms==1);
    
    # build Compara GenomeDB objects
    my $from_GenomeDB = $gdba->fetch_by_registry_name($from_species);
    my $to_GenomeDB   = $gdba->fetch_by_registry_name($to_species);
    my $mlss          = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$from_GenomeDB, $to_GenomeDB]);
    my $mlss_id       = $mlss->dbID();
    
    # get homologies from compara - comes back as a hash of arrays
    print $data "\n\tRetrieving homologies of method link type $method_link_type for mlss_id $mlss_id \n";
    my $homologies    = fetch_homologies($ha, $mlss, $from_species);
    print $data "\n\tProjecting GO Terms from $from_species to $to_species\n";
    print $data "\t\t$to_species, before projection, ";
    print_stats($to_ga);
    
    my $i             = 0;
    my $total_genes   = scalar(keys %$homologies);
    my $last_pc       = -1;

    foreach my $from_stable_id (keys %$homologies) {
       $i++;
       my $from_gene  = $from_ga->fetch_by_stable_id($from_stable_id);
       next if (!$from_gene);
       my @to_genes   = @{$homologies->{$from_stable_id}};
       my $i          = 1;
    
       foreach my $to_stable_id (@to_genes) {
         my $to_gene  = $to_ga->fetch_by_stable_id($to_stable_id);
         next if (!$to_gene);
         project_go_terms($to_ga, $to_dbea, $ma, $from_gene, $to_gene,$to_taxon_id,$ensemblObj_type,$hDb,$sql);
         $i++;
       }
    }
    print $data "\n\t\t$to_species, after projection, ";
    print_stats($to_ga);
    print_full_stats() if ($flag_full_stats==1);
    print $data "\n";
    print $data Dumper %projections_stats;
    close($data);
    $self->dataflow_output_id( { 'to_species' => $to_species }, 1 );

return;
}

sub write_output {
    my ($self) = @_;

    Bio::EnsEMBL::Registry->set_disconnect_when_inactive();
    Bio::EnsEMBL::Registry->disconnect_all();

}

######################
## internal methods
######################
sub check_directory {
    my ($self,$dir) = @_;

    unless (-e $dir) {
        print STDERR "$dir doesn't exists. I will try to create it\n" if ($self->debug());
        print STDERR "mkdir $dir (0755)\n" if ($self->debug());
        die "Impossible create directory $dir\n" unless (mkdir $dir, 0755 );
    }

return;
}

sub get_GOA_forbidden_terms {
    my $species = shift;

    my %terms;
    # Translate species into taxonID
    my $meta_container = Bio::EnsEMBL::Registry->get_adaptor($species,'core','MetaContainer');
    my ($taxon_id)     = @{ $meta_container->list_value_by_key('species.taxonomy_id')};

    # hit the web service with a request, build up a hash of all forbidden terms for this species
    my $user_agent     = LWP::UserAgent->new();
    $user_agent->env_proxy;
    my $response;
    $response          = $user_agent->get($goa_webservice.$goa_params.$taxon_id);
    my $retries        = 0;

    while (! $response->is_success ) {
       if ($retries > 5) {
           throw( "Failed to contact GOA webservice 6 times in a row. Dying ungracefully.");
       }
       warning( "Failed to contact GOA webservice, retrying on ".$goa_webservice.$goa_params.$taxon_id.
           "\n LWP error was: ".$response->code);
       $retries++;
       $response       = $user_agent->get($goa_webservice.$goa_params.$taxon_id);
       sleep(10);
    }

    my $blacklist           = from_json($response->content);
    my @blacklist_pairs     = @{ $blacklist->{'blacklist'} };
    my $translation_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,'core','translation');

    foreach my $go_t (@blacklist_pairs) {
       # look up protein accession in xrefs to get real EnsEMBL associations
       my %bad_thing        = %{$go_t};
       # %bad_thing is (proteinAc => AAAA, goId => GO:111111)
       my %many_bad_things  = get_ontology_terms($bad_thing{'goId'});        
       # %many_bad_things consists of ('GO:32141' => 1)
       my @translations     = @{ $translation_adaptor->fetch_all_by_external_name($bad_thing{'proteinAc'}) };
       
       foreach my $translation ( @translations) {
           if (exists($terms{$translation->stable_id})) {
                @many_bad_things{keys %{$terms{$translation->stable_id}} } = values %{$terms{$translation->stable_id}}; # merge existing hash with new one
           }
           $terms{$translation->stable_id} = \%many_bad_things;
       }
       # and return the list
   }
return %terms;
}

sub get_ontology_terms {
    my @starter_terms    = @_;

    my %terms;
    my $ontology_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi','Ontology','OntologyTerm');
    die "Can't get OntologyTerm Adaptor - check that database exist in the server specified" if (!$ontology_adaptor);
 
    foreach my $text_term (@starter_terms) {
       	my $ont_term     = $ontology_adaptor->fetch_by_accession($text_term);
       	my $term_list    = $ontology_adaptor->fetch_all_by_ancestor_term($ont_term);

       	foreach my $term (@{$term_list}) {
		$terms{$term->accession} = 1;
       	}
    }
 
return %terms;
}

sub backup {
    my ($to_ga, $to_species) = @_;

    my $dbc          = $to_ga->dbc();
    my $host         = $dbc->host();
    my $port         = $dbc->port();
    my $user         = $dbc->username();
    my $pass         = $dbc->password();
    my $dbname       = $dbc->dbname();
    my $mysql_binary = 'mysql';
    my @tables       = qw/gene transcript xref object_xref external_synonym/;

    foreach my $table (@tables) {
      unless (system("$mysql_binary -h$host -P$port -u$user -p$pass -N -e 'select * from $table' $dbname | gzip -c -6 > $output_dir/$dbname.$table.backup.gz") == 0) {
        print STDERR "Can't dump the original $table table from $dbname for backup\n";
        exit 1;
     } else {
        print "Original $table table backed up in $dbname.$table.backup\n";
     }
   }
}

sub delete_go_terms {
    my ($to_ga) = @_;

    print STDERR "Deleting projected GO terms\n";

    my $sth = $to_ga->dbc()->prepare("DELETE x, ox, gx FROM xref x, external_db e, object_xref ox, ontology_xref gx WHERE x.xref_id=ox.xref_id AND x.external_db_id=e.external_db_id AND ox.object_xref_id=gx.object_xref_id AND e.db_name='GO' AND x.info_type='PROJECTION'");
    $sth->execute();
    # note don't need to delete synonyms as GO terms don't have any
    # Also no effect on descriptions or status
}

# Fetch the homologies from the Compara database. Returns a hash of arrays:
# Key = "from" stable ID, value = array of "to" stable IDs
sub fetch_homologies {
    my ($ha, $mlss, $from_species) = @_;

    print $data "\t\tFetching Compara homologies...";
    my $from_species_alias = $gdba->fetch_by_registry_name($from_species)->name();
    my %homology_cache;
    my $count              = 0;
    my $homologies         = $ha->fetch_all_by_MethodLinkSpeciesSet($mlss);

    foreach my $homology (@{$homologies}) {
       next if (!homology_type_allowed($homology->description));
       my $members = $homology->get_all_GeneMembers();
       my @to_stable_ids;my $from_stable_id;
       my @perc_id; 

       my $mems = $homology->get_all_Members();
 
       foreach my $mem (@{$mems}){
             push @perc_id,$mem->perc_id();
       }
       next if (grep {$_ < $percent_id_filter} @perc_id) ;
 
       foreach my $member (@{$members}) {
       	 if ($member->genome_db()->name() eq $from_species_alias) {
            $from_stable_id = $member->stable_id();
         }
         else {
            push(@to_stable_ids, $member->stable_id());
         }
       }

       print STDERR "Warning: can't find stable ID corresponding to 'from' species ($from_species_alias)\n" if (!$from_stable_id);
       push @{$homology_cache{$from_stable_id}}, @to_stable_ids;
       $count++;
  }
  print $data "\tFetched " . $count . " homologies\n";

return \%homology_cache;
}

sub homology_type_allowed {
    my $h = shift;

    foreach my $allowed (@$homology_types_allowed) {
      return 1 if ($h eq $allowed);
    }

return undef;
}

sub print_stats {
    my ($to_ga) = @_;

    my $total_genes = count_rows($to_ga, "SELECT COUNT(*) FROM gene g");
    my $count;
    print $data "\tUnique GO terms: total ";
    print $data &count_rows($to_ga, "SELECT COUNT(DISTINCT(x.dbprimary_acc)) FROM xref x, external_db e WHERE e.external_db_id=x.external_db_id AND e.db_name='GO'");
    print $data " projected ";
    print $data &count_rows($to_ga, "SELECT COUNT(DISTINCT(x.dbprimary_acc)) FROM xref x, external_db e WHERE e.external_db_id=x.external_db_id AND e.db_name='GO' AND x.info_type='PROJECTION'");
    print "\n";
}

sub project_go_terms {
    my ($to_ga, $to_dbea, $ma, $from_gene, $to_gene,$to_taxon_id,$ensemblObj_type,$hDb,$sql) = @_;

    # GO xrefs are linked to translations, not genes
    # Project GO terms between the translations of the canonical transcripts of each gene
    my ($from_translation,$to_translation);    

    if($ensemblObj_type=~/Translation/){ 
       $from_translation   = get_canonical_translation($from_gene);
       $to_translation     = get_canonical_translation($to_gene);
    }    
    else{ # $ensemblObj_type=~/Transcript/ in the case of ncRNA
       $from_translation   = $from_gene->canonical_transcript();
       $to_translation     = $to_gene->canonical_transcript();
    }
    return if (!$from_translation || !$to_translation);

    my $from_latin_species = ucfirst(Bio::EnsEMBL::Registry->get_alias($from_species));
    my $to_go_xrefs        = $to_translation->get_all_DBEntries("GO");
   
    DBENTRY: foreach my $dbEntry (@{$from_translation->get_all_DBEntries("GO")}) { 
      $projections_stats{'total'}++;
      next if (!$dbEntry || $dbEntry->dbname() ne "GO" || ref($dbEntry) ne "Bio::EnsEMBL::OntologyXref");
      # Skip the whole dbEntry if one or more if its evidence codes isn't in the whitelist 
      foreach my $et (@{$dbEntry->get_all_linkage_types}){
        $projections_stats{'missing_ec'}++ if(!grep(/$et/,@$evidence_codes));
        next DBENTRY if (!grep(/$et/, @$evidence_codes));
      }
      # Check GO term against GOA blacklist
      next DBENTRY if (unwanted_go_term($to_translation->stable_id,$dbEntry->primary_id));

      # Check GO term against taxon constraints
      my $go_term    = $dbEntry->primary_id;   
      my $hStmt      = $hDb->prepare("$sql") or die "Couldn't prepare statement: " . $hDb->errstr;
      $hStmt->execute($go_term,$to_taxon_id);

      while (my($result) = $hStmt->fetchrow_array()) {
         $projections_stats{'taxon_constraint'}++ if($result !~/OK/);
         next DBENTRY if($result !~/OK/);
      }

      # check that each from GO term isn't already projected
      next if ($flag_go_check ==1 && go_xref_exists($dbEntry, $to_go_xrefs));
      # Force loading of external synonyms for the xref
      $dbEntry->get_all_synonyms();
      # record statistics by evidence type
      foreach my $et (@{$dbEntry->get_all_linkage_types}){
         $projections_by_evidence_type{$et}++;
      }
      # Change linkage_type for projection to IEA (in the absence of a specific one for projections)
      $dbEntry->flush_linkage_types();

      # First we create a new dbEntry to represent the source dbEntry
      # in the target database (to use as the 'source' of the
      # entry). This is actually the transcript ID we project from,
      # i.e. an Arabidopsis thaliana transcript.
      my $source_dbEntry = Bio::EnsEMBL::DBEntry->
          new( -primary_id         => $from_translation->stable_id,
                # NB: dbname (external_db) should already exists!
                # Note, $compara is 'division' on the command line.
               -dbname             => 'Ensembl '. ucfirst( $compara ),
               -display_id         => $from_translation->stable_id,
          );

      $dbEntry->add_linkage_type("IEA", $source_dbEntry);

      # These fields are actually 'bugs' in the current XRef schema,
      # so we leave them 'NULL' here...
      $dbEntry->info_type("NONE");
      $dbEntry->info_text('');

      my $analysis = Bio::EnsEMBL::Analysis->
          new( -logic_name      => 'go_projection',
               -db              => $dbEntry->dbname,
               -db_version      => '',
               -program         => 'SpeciesProjection.pm',
               -description     => 'The XRef projection pipeline re-implemented by CK based on work by Andy and tweaked by Dan',
               -display_label   => 'Projected XRef',
          );

      $dbEntry->analysis($analysis);
      $to_translation->add_DBEntry($dbEntry);

      $projections_stats{'to_be_proj'}++;
      print "PROJECTION " .$from_gene->stable_id() . " " . $from_translation->stable_id() . " " .  $dbEntry->display_id() . " --> " . $to_gene->stable_id() . " " . $to_translation->stable_id() . "\n";

#      $to_dbea->store($dbEntry, $to_translation->dbID(), $ensemblObj_type, 1) if ($flag_store_projections==1);
    }
}

sub count_rows {
    my ($adaptor, $sql) = @_;

    my $sth = $adaptor->dbc->prepare($sql);
    $sth->execute();

return ($sth->fetchrow_array())[0];
}

# Get the translation associated with the gene's canonical transcript
sub get_canonical_translation {
    my $gene = shift;
    my $canonical_transcript = $gene->canonical_transcript();

    if (!$canonical_transcript) {
       warn("Can't get canonical transcript for " . $gene->stable_id() . ", skipping this homology");
    return undef;
    }

return $canonical_transcript->translation();;
}

# Perform a hash lookup in %forbidden_terms, defined higher up ()
sub unwanted_go_term {
  my ($stable_id,$go_term)= @_;
 
  if (exists ($forbidden_terms{$stable_id}) ) {
     if (exists ( $forbidden_terms{$stable_id}->{$go_term} )) {
       $projections_stats{'forbidden'}++;
       return 1;
     }
  }
return 0;
}

sub go_xref_exists {
    my ($dbEntry, $to_go_xrefs) = @_;

    foreach my $xref (@{$to_go_xrefs}) {
       next if (ref($dbEntry) ne "Bio::EnsEMBL::OntologyXref" || ref($xref) ne "Bio::EnsEMBL::OntologyXref");

       if ($xref->dbname() eq $dbEntry->dbname() &&
	  $xref->primary_id() eq $dbEntry->primary_id() &&
	  join("", @{$xref->get_all_linkage_types()}) eq join("", @{$dbEntry->get_all_linkage_types()})) {
	  $projections_stats{'exist'}++;
      return 1;
      }

      # if a GO term with the same accession, but IEA evidence code, exists, also don't project, as this
      # will lead to duplicates when the projected term has its evidence code changed to IEA after projection
      if ($xref->primary_id() eq $dbEntry->primary_id()) {
         foreach my $evidence_code (@{$xref->get_all_linkage_types()}) {
           $projections_stats{'exist'}++;
	 return 1 if ($evidence_code eq "IEA");
         }
      }
   }

return 0;
}

sub print_full_stats {
 
    print $data "\n\n\tProjections stats by evidence code:\n";
    my $total;

    foreach my $et (sort keys %projections_by_evidence_type) {
      next if (!grep(/$et/, @$evidence_codes));
	
      if ($et) {
	print $data "\t\t" .$et. "\t" . $projections_by_evidence_type{$et} . "\n";
	$total += $projections_by_evidence_type{$et};
      }
    }
    print $data "\t\tTotal:\t$total\n";


}

1;
