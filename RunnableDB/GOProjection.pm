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

=head1 MAINTAINER/AUTHOR

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

sub param_defaults {
    return {
          
	   };
}

my ($flag_go_check, $flag_store_projections, $flag_full_stats, $flag_delete_go_terms);
my ($to_species, $from_species, $compara, $release);
my ($method_link_type, $homology_types_allowed, $percent_id_filter);
my ($log_file, $output_dir, $data);

my ($evidence_codes, $ensemblObj_type, $ensemblObj_type_target,$goa_webservice, $goa_params);
my (%forbidden_terms, %projections_by_evidence_type, %projections_stats);
my ($mlssa, $ha, $ma, $gdba);

sub fetch_input {
    my ($self) = @_;

    $flag_go_check          = $self->param_required('flag_go_check');
    $flag_store_projections = $self->param_required('flag_store_projections');
    $flag_full_stats        = $self->param_required('flag_full_stats');
    $flag_delete_go_terms   = $self->param_required('flag_delete_go_terms');

    $to_species             = $self->param_required('species');
    $from_species           = $self->param_required('from_species');
    $compara                = $self->param_required('compara');
    $release                = $self->param_required('release');

    $method_link_type       = $self->param_required('method_link_type');
    $homology_types_allowed = $self->param_required('homology_types_allowed ');
    $percent_id_filter      = $self->param_required('percent_id_filter');
    $log_file               = $self->param_required('output_dir');
    $output_dir             = $self->param_required('output_dir');

    $ensemblObj_type        = $self->param_required('ensemblObj_type');
    $ensemblObj_type_target = $self->param_required('ensemblObj_type_target');
    $evidence_codes         = $self->param_required('evidence_codes');
    $goa_webservice         = $self->param_required('goa_webservice');
    $goa_params             = $self->param_required('goa_params');

return;
}

sub run {
    my ($self) = @_;

#    Bio::EnsEMBL::Registry->set_disconnect_when_inactive(1);

    # Connection to Oracle DB for taxon constraint 
    my $dsn_goapro = 'DBI:Oracle:host=ora-vm-026.ebi.ac.uk;sid=goapro;port=1531';
    my $user       = 'goselect';
    my $pass       = 'selectgo';
    my $hDb        = DBI->connect($dsn_goapro, $user, $pass, {PrintError => 1, RaiseError => 1}) or die "Cannot connect to server: " . DBI->errstr;
    my $sql        = "select go.goa_validation.taxon_check_term_taxon(?,?) from dual";

    # Creating adaptors
    my $from_ga    = Bio::EnsEMBL::Registry->get_adaptor($from_species, 'core', 'Gene');
    my $to_ga      = Bio::EnsEMBL::Registry->get_adaptor($to_species, 'core', 'Gene');
    my $to_ta      = Bio::EnsEMBL::Registry->get_adaptor($to_species, 'core', 'Transcript');
    my $to_dbea    = Bio::EnsEMBL::Registry->get_adaptor($to_species, 'core', 'DBEntry');

    #$from_ga->dbc->disconnect_when_inactive(1);	
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
    $mlssa = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet');
    $ha    = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'Homology');
    #$ma    = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'SeqMember');
    $gdba  = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", "GenomeDB");
    die "Can't connect to Compara database specified by $compara - check command-line and registry file settings" if (!$mlssa || !$ha ||!$gdba);

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

    $self->delete_go_terms($to_ga) if($flag_delete_go_terms==1);

    # build Compara GenomeDB objects
    my $from_GenomeDB = $gdba->fetch_by_registry_name($from_species);
    my $to_GenomeDB   = $gdba->fetch_by_registry_name($to_species);
    my $mlss          = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$from_GenomeDB, $to_GenomeDB]);
    my $mlss_id       = $mlss->dbID();
    
    # get homologies from compara - comes back as a hash of arrays
    print $data "\n\tRetrieving homologies of method link type $method_link_type for mlss_id $mlss_id \n";
    my $homologies    = $self->fetch_homologies($ha, $mlss, $from_species, $data, $gdba, $homology_types_allowed, $percent_id_filter);
    
    print $data "\n\tProjecting GO Terms from $from_species to $to_species\n";
    print $data "\t\t$to_species, before projection, ";
    $self->print_GOstats($to_ga, $data);
    
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
         project_go_terms($to_ga, $to_dbea, $ma, $from_gene, $to_gene,$to_taxon_id,$ensemblObj_type, $ensemblObj_type_target,$hDb,$sql);
         $i++;
       }
    }
    print $data "\n\t\t$to_species, after projection, ";
    $self->print_GOstats($to_ga, $data);
    print_full_stats() if ($flag_full_stats==1);
    print $data "\n";
    print $data Dumper %projections_stats;
    close($data);

return;
}

sub write_output {
    my ($self) = @_;


}

######################
## internal methods
######################
sub get_GOA_forbidden_terms {
    my $species = shift;

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

return 0;
}

# Functions called within project_go_terms {
#   + get_canonical_translation {
#   + unwanted_go_term {
#   + go_xref_exists {
sub project_go_terms {
    my ($to_ga, $to_dbea, $ma, $from_gene, $to_gene,$to_taxon_id, $ensemblObj_type, $ensemblObj_type_target, $hDb, $sql) = @_;

    # GO xrefs are linked to translations, not genes
    # Project GO terms between the translations of the canonical transcripts of each gene
    my ($from_translation,$to_translation,$xref_name);    

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
=pod
    if($ensemblObj_type=~/Translation/){ 
       $from_translation   = get_canonical_translation($from_gene);
       $to_translation     = get_canonical_translation($to_gene);
       $xref_name = "GO";
    }    
    else{ # $ensemblObj_type=~/Transcript/ in the case of ncRNA
       $from_translation   = $from_gene->canonical_transcript();
       $to_translation     = get_canonical_translation($to_gene);
       $xref_name = "GO_to_gene";
    }
=cut

    return if (!$from_translation || !$to_translation);

    my $from_latin_species = ucfirst(Bio::EnsEMBL::Registry->get_alias($from_species));
    my $to_go_xrefs        = $to_translation->get_all_DBEntries("GO");
   
    DBENTRY: foreach my $dbEntry (@{$from_translation->get_all_DBEntries($xref_name)}) { 
      $projections_stats{'total'}++;
     
      # Check dbEntry dbname
      next if (!$dbEntry || $dbEntry->dbname() ne $xref_name || ref($dbEntry) ne "Bio::EnsEMBL::OntologyXref");

      # Check if dbEntry evidence codes isn't in the whitelist 
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

      # Check GO term isn't already projected
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

      $projections_stats{'to_be_proj'}++;

      $dbEntry->analysis($analysis);
      $to_translation->add_DBEntry($dbEntry);
      $to_dbea->store($dbEntry, $to_translation->dbID(), $ensemblObj_type_target, 1) if ($flag_store_projections==1);

      print $data "\t\tProject from:".$from_translation->stable_id()."\t";
      print $data "to:".$to_translation->stable_id()."\t";
      print $data "GO term:".$dbEntry->display_id()."\n";
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


1;
