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


ckong

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOProjection;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use LWP;
use JSON;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');
use Bio::EnsEMBL::Utils::Exception qw(throw);
use File::Path qw(make_path);
use File::Spec::Functions qw(catdir);

sub param_defaults {
    return {
          
	   };
}

my (%projections_by_evidence_type, %projections_stats);

sub fetch_input {
    my ($self) = @_;

    my $flag_go_check     = $self->param_required('flag_go_check');
    my $flag_store_proj   = $self->param_required('flag_store_projections');
    my $flag_full_stats   = $self->param_required('flag_full_stats');
    my $to_species      = $self->param_required('species');
    my $from_species    = $self->param_required('source');
    my $compara         = $self->param_required('compara');
    my $release         = $self->param_required('release');
    my $outfile         = $self->param_required('output_dir');
    my $output_dir      = $self->param_required('output_dir');
    my $method_link_type       = $self->param_required('method_link_type');
    my $homology_types_allowed = $self->param_required('homology_types_allowed');
    my $percent_id_filter      = $self->param_required('percent_id_filter');
    my $ensemblObj_type        = $self->param_required('ensemblObj_type');
    my $ensemblObj_type_target = $self->param_required('ensemblObj_type_target');
    my $evidence_codes         = $self->param_required('evidence_codes');
    my $goa_webservice         = $self->param_required('goa_webservice');
    my $goa_params             = $self->param_required('goa_params');
    my $taxon_params           = $self->param_required('taxon_params');
    my $is_tree_compliant     = $self->param_required('is_tree_compliant');

    $self->param('flag_go_check', $flag_go_check);
    $self->param('flag_store_proj', $flag_store_proj);
    $self->param('flag_full_stats', $flag_full_stats);
    $self->param('to_species', $to_species);
    $self->param('from_species', $from_species);
    $self->param('compara', $compara);
    $self->param('release', $release);
    $self->param('outfile', $outfile);
    $self->param('output_dir', $output_dir);
    $self->param('method_link_type', $method_link_type);
    $self->param('homology_types_allowed', $homology_types_allowed);
    $self->param('percent_id_filter', $percent_id_filter);
    $self->param('ensemblObj_type', $ensemblObj_type);
    $self->param('ensemblObj_type_target', $ensemblObj_type_target);
    $self->param('evidence_codes', $evidence_codes);
    $self->param('goa_webservice', $goa_webservice);
    $self->param('goa_params', $goa_params);
    $self->param('taxon_params', $taxon_params);
    $self->param('is_tree_compliant', $is_tree_compliant);

    make_path($outfile);

    my $log_file  = $outfile."/".$from_species."-".$to_species."_GOTermsProjection_logs.txt";
    open my $log,">","$log_file" or die $!;

    $self->param('log', $log);

return;
}

sub run {
    my ($self) = @_;

    # Connection to Oracle DB for taxon constraint if available. If Oracle is not available use webservice.
    my $dsn_goapro = 'DBI:Oracle:host=ora-vm-026.ebi.ac.uk;sid=goapro;port=1531';
    my $user       = 'goselect';
    my $pass       = 'selectgo';
    my $hDb;
    my $sql;
    eval{
      $hDb        = DBI->connect($dsn_goapro, $user, $pass, {PrintError => 1, RaiseError => 1});
      $sql        = "select go.goa_validation.taxon_check_term_taxon(?,?) from dual";
    }
    or do{
      print "Cannot connect to server ".DBI->errstr." pipeline will use taxon webservice";
    };
    # Creating adaptors
    my $to_species   = $self->param('to_species');
    my $from_species = $self->param('from_species');

    my $from_ga    = Bio::EnsEMBL::Registry->get_adaptor($from_species, 'core', 'Gene');
    my $to_ga      = Bio::EnsEMBL::Registry->get_adaptor($to_species, 'core', 'Gene');
    my $to_ta      = Bio::EnsEMBL::Registry->get_adaptor($to_species, 'core', 'Transcript');
    my $to_dbea    = Bio::EnsEMBL::Registry->get_adaptor($to_species, 'core', 'DBEntry');

    die("Problem getting DBadaptor(s) - check database connection details\n") if (!$from_ga || !$to_ga || !$to_ta || !$to_dbea);
    
    # Interrogate GOA web service for forbidden GO terms for the given species.
    # This requires both a lookup, and then finding all child-terms on the forbidden list.
    # The forbidden_terms list is used in unwanted_go_term();
    my %forbidden_terms  = get_GOA_forbidden_terms($to_species, $self->param('goa_webservice'), $self->param('goa_params'));
    my $forbidden_terms  = \%forbidden_terms;
    $self->param('forbidden_terms', $forbidden_terms);

    # Get Compara adaptors - use the one specified on the command line
    my $compara = $self->param('compara');
    my $to_latin_species;
    my $meta_container;
    my ($to_taxon_id);
    if ($compara ne "Multi"){
       # Getting ancestry taxon_ids only for Ensembl Genomes species
       $to_latin_species = ucfirst(Bio::EnsEMBL::Registry->get_alias($to_species));
       $meta_container   = Bio::EnsEMBL::Registry->get_adaptor($to_latin_species,'core','MetaContainer');
       ($to_taxon_id)    = @{ $meta_container->list_value_by_key('species.taxonomy_id')};
    }
=pod
    Bio::EnsEMBL::Registry->load_registry_from_db(
            -host       => 'mysql-eg-mirror.ebi.ac.uk',
            -port       => 4157,
            -user       => 'ensrw',
            -pass       => 'writ3r',
            -db_version => '80',
   );
=cut

    my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet');
    my $ha    = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'Homology');
    my $gdba  = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", "GenomeDB");
    die "Can't connect to Compara database specified by $compara - check command-line and registry file settings" if (!$mlssa || !$ha ||!$gdba);
    my $constrained_terms;
    if (!defined($hDb) and !defined($sql)){
      # If Pipeline couldn't use the Oracle database, use Constrained terms via the GOA webservice
      my %constrained_terms = get_taxon_forbidden_terms($to_species, $gdba, $self->param('goa_webservice'), $self->param('taxon_params'));
      $constrained_terms  = \%constrained_terms;
      $self->param('constrained_terms', $constrained_terms);
    }
    # Write projection info metadata
    my $log = $self->param('log');
    print $log "\n\tProjection log :\n";
    print $log "\t\tsoftware release:".$self->param('release')."\n";
    print $log "\t\tfrom :".$from_ga->dbc()->dbname()." to :".$to_ga->dbc()->dbname()."\n";


    # build Compara GenomeDB objects
    my $method_link_type = $self->param('method_link_type');
    my $from_GenomeDB    = $gdba->fetch_by_registry_name($from_species);
    my $to_GenomeDB      = $gdba->fetch_by_registry_name($to_species);
    my $mlss             = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$from_GenomeDB, $to_GenomeDB]);

    throw "Failed to fetch mlss for ml, $method_link_type, for pair of species, $from_species, $to_species\n" if(!defined $mlss);
    my $mlss_id       = $mlss->dbID();
    
    # get homologies from compara - comes back as a hash of arrays
    print $log "\n\tRetrieving homologies of method link type $method_link_type for mlss_id $mlss_id \n";
    my $homologies    = $self->fetch_homologies($ha, $mlss, $from_species, $log, $gdba, $self->param('homology_types_allowed'), $self->param('is_tree_compliant'), $self->param('percent_id_filter'), '1');
   
    print $log "\n\tProjecting GO Terms from $from_species to $to_species\n";
    print $log "\t\t$to_species, before projection, "; 
    print $log "\n\tProjecting GO Terms from $from_species to $to_species\n";
    print $log "\t\t$to_species, before projection, ";
    $self->print_GOstats($to_ga, $log);
    
    my $i             = 0;
    my $total_genes   = scalar(keys %$homologies);

    foreach my $from_stable_id (keys %$homologies) {
       my $from_gene  = $from_ga->fetch_by_stable_id($from_stable_id);
       next if (!$from_gene);
       my @to_genes   = @{$homologies->{$from_stable_id}};
       my $i          = 1;
    
       foreach my $to_stable_id (@to_genes) {
         my $to_gene  = $to_ga->fetch_by_stable_id($to_stable_id);
         next if (!$to_gene);
         $self->project_go_terms($from_species, $compara, $to_ga, $to_dbea, $from_gene, $to_gene, $self->param('ensemblObj_type'), $self->param('ensemblObj_type_target'), $self->param('evidence_codes'), $log, $hDb, $sql, $to_taxon_id, $constrained_terms);
         $i++;
       }
    }
    print $log "\n\t\t$to_species, after projection, ";
    $self->print_GOstats($to_ga, $log);
    print_full_stats($log, $self->param('evidence_codes')) if ($self->param('flag_full_stats')==1);
    print $log "\n";
    print $log Dumper %projections_stats;
 
    close($log);

    #Disconnecting from the registry
    $from_ga->dbc->disconnect_if_idle();
    $to_ga->dbc->disconnect_if_idle();
    $to_ta->dbc->disconnect_if_idle();
    $to_dbea->dbc->disconnect_if_idle();
    $mlssa->dbc->disconnect_if_idle();
    $ha->dbc->disconnect_if_idle();
    $gdba->dbc->disconnect_if_idle(); 
return;
}

sub write_output {
    my ($self) = @_;
}

######################
## internal methods
######################
sub get_GOA_forbidden_terms {
    my ($species, $goa_webservice, $goa_params) = @_; #= shift;

    my %terms;
    # Translate species name to taxonID
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
   $meta_container->dbc->disconnect_if_idle();  
return %terms;
}

sub get_taxon_forbidden_terms {
    my ($species, $gdba,$goa_webservice, $taxon_params) = @_;

    # Translate species into taxonID
    my $meta_container = Bio::EnsEMBL::Registry->get_adaptor($species,'core','MetaContainer');
    my $species_name = $meta_container->single_value_by_key('species.production_name');

    # hit the web service with a request, build up a hash of all forbidden terms for this species
    my $user_agent = LWP::UserAgent->new();
    $user_agent->env_proxy;
    my $response;
    $response = $user_agent->get($goa_webservice.$taxon_params);
    # Retry until web service comes back?
    my $retries = 0;
    while (! $response->is_success ) {
        if ($retries > 5) {
            throw( "Failed to contact GOA webservice 6 times in a row. Dying ungracefully.");
        }

        warning( "Failed to contact GOA webservice, retrying on ".$goa_webservice.$taxon_params.
            "\n LWP error was: ".$response->code
        );
        $retries++;
        $response = $user_agent->get($goa_webservice.$taxon_params);
        sleep(10);
    }

    my $constraint = from_json($response->content);
    my @constraint_pairs = @{ $constraint->{'constraints'} };

    my %blacklisted_terms;
    my @blacklisted_go;

    foreach my $taxon_constraint (@constraint_pairs) {
      my %constraint_elements = %{$taxon_constraint};
      # %constraint_elements is ("ruleId" : "GOTAX:0000134","constraint" : "only_in_taxon","taxa" : ["33090"],"goId" : "GO:0009541")

      my $constraint = $constraint_elements{'constraint'};
      my @taxa = @{$constraint_elements{'taxa'}};
      my @affected_species;
      foreach my $taxon (@taxa) {
        push @affected_species, @{$gdba->fetch_all_by_ancestral_taxon_id($taxon)};
      }
      my $found_species = 0;
      my $is_blacklisted = 0;
      foreach my $affected_species (@affected_species) {
        if ($affected_species->name() eq $species_name) {
          $found_species = 1;
          last;
        }
      }
      if ($constraint eq 'only_in_taxon') {
      # If GO term only in taxon, blacklist if species is not in taxon
        if (!$found_species) {
          $is_blacklisted = 1;
        }
      } elsif ($constraint eq 'never_in_taxon') {
      # If GO term never in taxon, blacklist if species in taxon
        if ($found_species) {
          $is_blacklisted = 1;
        }
      } else {
# Currently, GO constraints match only_in_taxon or never_in_taxon
      # We want to be warned if a new constraint type appears
        throw("unexpected $constraint, please update projection code");
      }

      if ($is_blacklisted) {
        push @blacklisted_go, $constraint_elements{'goId'};
      }
    }

    %blacklisted_terms = get_ontology_terms(@blacklisted_go);
return %blacklisted_terms;
}


sub get_ontology_terms {
    my @starter_terms    = @_;

=pod
    Bio::EnsEMBL::Registry->load_registry_from_db(
            -host       => 'mysql-eg-mirror.ebi.ac.uk',
            -port       => 4157,
            -user       => 'ensrw',
            -pass       => 'writ3r',
            -db_version => '80',
   );
=cut

    my %terms;
    my $ontology_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi','Ontology','OntologyTerm');
    die "Can't get OntologyTerm Adaptor - check that database exist in the server specified" if (!$ontology_adaptor);
 
    foreach my $text_term (@starter_terms) {
        $terms{$text_term} = 1;
       	my $ont_term     = $ontology_adaptor->fetch_by_accession($text_term);
        next if (!$ont_term);
        my $term_list    = $ontology_adaptor->fetch_all_by_ancestor_term($ont_term);
       	foreach my $term (@{$term_list}) {
		$terms{$term->accession} = 1;
       	}
    }
 
return %terms;
}

sub print_full_stats {
    my ($log, $evidence_codes) = @_;
    my $total;

    print $log "\n\n\tProjections stats by evidence code:\n";

    foreach my $et (sort keys %projections_by_evidence_type) {
      next if (!grep(/$et/, @$evidence_codes));

      if ($et) {
        print $log "\t\t" .$et. "\t" . $projections_by_evidence_type{$et} . "\n";
        $total += $projections_by_evidence_type{$et};
      }
    }
    print $log "\t\tTotal:\t$total\n";

return 0;
}

# Functions called within project_go_terms {
#   + get_canonical_translation {
#   + unwanted_go_term {
#   + go_xref_exists {
sub project_go_terms {
    my ($self, $from_species, $compara, $to_ga, $to_dbea, $from_gene, $to_gene, $ensemblObj_type, $ensemblObj_type_target, $evidence_codes, $log, $hDb, $sql, $to_taxon_id, $constrained_terms) = @_;

    # GO xrefs are linked to translations, not genes
    # Project GO terms between the translations of the canonical transcripts of each gene
    my ($from_translation,$to_translation);    

    if($ensemblObj_type=~/Translation/ && $ensemblObj_type_target=~/Translation/){
       $from_translation   = get_canonical_translation($from_gene);
       $to_translation     = get_canonical_translation($to_gene);
    }
    elsif($ensemblObj_type=~/Transcript/ && $ensemblObj_type_target=~/Transcript/){ 
       # $ensemblObj_type=~/Transcript/ in the case of ncRNA
       $from_translation   = $from_gene->canonical_transcript();
       $to_translation     = $to_gene->canonical_transcript();
    }
    elsif($ensemblObj_type=~/Transcript/ && $ensemblObj_type_target=~/Translation/){ 
       $from_translation   = $from_gene->canonical_transcript();
       $to_translation     = get_canonical_translation($to_gene); 
    }

    return if (!$from_translation || !$to_translation);

    my $from_latin_species = ucfirst(Bio::EnsEMBL::Registry->get_alias($from_species));
    my $to_go_xrefs        = $to_translation->get_all_DBEntries("GO") if $self->param('flag_go_check') ==1;
   
    DBENTRY: foreach my $dbEntry (@{$from_translation->get_all_DBEntries("GO")}) { 
      
      $projections_stats{'total'}++;
     
      # Check dbEntry dbname
      next if (!$dbEntry || $dbEntry->dbname() ne "GO" || ref($dbEntry) ne "Bio::EnsEMBL::OntologyXref");

      # Keep the whole dbEntry if at least one of the evidence codes matches the whitelist
      # Check if dbEntry evidence codes isn't in the whitelist 
      my $match_et = 0;
      foreach my $et (@{$dbEntry->get_all_linkage_types}){
        $projections_stats{'missing_ec'}++ if(!grep(/$et/,@$evidence_codes));
        if (grep(/$et/, @$evidence_codes)) {
          $match_et = 1;
          last;
        }
      }
      next DBENTRY if !$match_et;
      # Check GO term against GOA blacklist
      next DBENTRY if (unwanted_go_term($to_translation->stable_id,$dbEntry->primary_id, $self->param('forbidden_terms')));
      # Check GO term against taxon constraints
      my $go_term    = $dbEntry->primary_id;
      # Use Oracle database or Webservice
      if (defined($constrained_terms)){
        next DBENTRY if ($$constrained_terms{$dbEntry->primary_id});
      }
      elsif (defined($sql) and defined($hDb) and defined($to_taxon_id)){
        my $hStmt = $hDb->prepare("$sql") or die "Couldn't prepare statement: " . $hDb->errstr;
        $hStmt->execute($go_term,$to_taxon_id);
        while (my($result) = $hStmt->fetchrow_array()) {
          $projections_stats{'taxon_constraint'}++ if($result !~/OK/);
          next DBENTRY if($result !~/OK/);
        }
       }

      # Check GO term isn't already projected
      next if ($self->param('flag_go_check') ==1 && go_xref_exists($dbEntry, $to_go_xrefs));

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
      # This code is not working for the e! databases 
      if ($compara ne "Multi"){
        my $source_dbEntry = Bio::EnsEMBL::DBEntry->
          new( -primary_id   => $from_translation->stable_id,
                # NB: dbname (external_db) should already exists!
                # Note, $compara is 'division' on the command line.
               -dbname       => 'Ensembl_'.ucfirst($compara),
               -display_id   => $from_translation->stable_id,
          );
      $dbEntry->add_linkage_type("IEA", $source_dbEntry);
      # These fields are actually 'bugs' in the current XRef schema,
      # so we leave them 'NULL' here...
      $dbEntry->info_type("PROJECTION");
      $dbEntry->info_text('');
      my $analysis = Bio::EnsEMBL::Analysis->
          new( -logic_name      => 'go_projection',
               -db              => $dbEntry->dbname,
               -db_version      => '',
               -program         => 'GOProjection.pm',
               -description     => 'The Gene Ontology XRef projection pipeline',
               -display_label   => 'GO projected xrefs',
          );
      $dbEntry->analysis($analysis);
      }
      # For e! databases 
      else{
      $dbEntry->add_linkage_type("IEA");
      my $txt = "from $from_latin_species translation " . $from_translation->stable_id();
      $dbEntry->info_type("PROJECTION");
      $dbEntry->info_text($txt);
      }

      $projections_stats{'to_be_proj'}++;

      delete $dbEntry->{associated_xref} if(defined $dbEntry->{associated_xref});
      $to_translation->add_DBEntry($dbEntry);
      $to_dbea->store($dbEntry, $to_translation->dbID(), $ensemblObj_type_target, 1) if ($self->param('flag_store_proj')==1);
      
      print $log "\t\t Project GO term:".$dbEntry->display_id()."\t";
      print $log "from:".$from_translation->stable_id()."\t";
      print $log "to:".$to_translation->stable_id()."\n";
    }

return 0;
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
  my ($stable_id, $go_term, $forbidden_terms)= @_;

#  if (exists ($forbidden_terms{$stable_id}) ) {
#      if (exists ( $forbidden_terms{$stable_id}->{$go_term} )) {
  if (exists ($$forbidden_terms{$stable_id}) ) {
     if (exists ( $$forbidden_terms{$stable_id}->{$go_term} )) {
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


1;
