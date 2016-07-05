=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::InterProScan::Interpro2GoLoader;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::Interpro2GoLoader;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBEntry;
use Bio::EnsEMBL::OntologyXref;
use Bio::EnsEMBL::Analysis;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreFeaturesBase');

sub fetch_input {
    my ($self) 	= @_;

    my $file                     = $self->param_required('interpro2go');
    my $species                  = $self->param_required('species');
    my $flag_check_annot_exists  = $self->param_required('flag_check_annot_exists');
    my $core_dbh                 = $self->core_dbh;
    my $dbea                     = Bio::EnsEMBL::Registry->get_adaptor($species,'Core','DBEntry');
    my $ipr_ext_dbid             = $self->fetch_external_db_id($core_dbh, 'Interpro');
    my $go_ext_dbid              = $self->fetch_external_db_id($core_dbh, 'GO');

    # Query to remove from 'ontology_xref' and 'object_xref' records with interpro GO annotation   
    my $sql_clear_table =  'DELETE ox.*, onx.* FROM object_xref ox 
                          INNER JOIN ontology_xref onx USING(object_xref_id)  
                          INNER JOIN xref x ON onx.source_xref_id = x.xref_id 
                          INNER JOIN xref x2 ON ox.xref_id=x2.xref_id 
                          WHERE x.external_db_id =? AND x2.external_db_id =?';

    # Query to get all GO annotated translation_id, 
    # that supports collection species
    my $sql_get_tid     = 'SELECT ox.ensembl_id  FROM xref x 
			 JOIN object_xref ox USING (xref_id) 
			 JOIN translation tl ON (ox.ensembl_id=tl.translation_id) 
			 JOIN transcript tf USING (transcript_id) 
			 JOIN seq_region s USING (seq_region_id) 
			 JOIN coord_system c USING (coord_system_id) 
			 WHERE x.external_db_id=? 
			 AND c.species_id=?';

    #  $sql_get_tid     = 'SELECT ox.ensembl_id FROM object_xref ox 
    #                        JOIN xref x USING (xref_id) 
    #                        WHERE x.external_db_id=? AND ox.ensembl_id=?';


    # Query to get mapping of interpro accession to ensembl translation,
    # 'GROUP BY' to remove duplicates of interpro_ac and translation_id
    # that supports collection species
    my $sql_get_ipr_tid = 'SELECT i.interpro_ac, pf.hit_name, pf.translation_id, tf.transcript_id FROM interpro i 
			 JOIN protein_feature pf ON (hit_name=id) 
			 JOIN translation tl USING (translation_id) 
			 JOIN transcript tf USING (transcript_id) 
			 JOIN seq_region s USING (seq_region_id) 
			 JOIN coord_system c USING (coord_system_id) 
			 WHERE c.species_id=?
			 GROUP BY i.interpro_ac, pf.translation_id';

   # $sql_get_ipr_tid = 'SELECT i.interpro_ac, pf.hit_name, pf.translation_id FROM interpro i
   #                         JOIN protein_feature pf ON (hit_name=id)
   #                         GROUP BY i.interpro_ac, pf.translation_id'; 

   my $sql_del_xref   = 'DELETE FROM xref WHERE external_db_id=1000 AND info_text LIKE "%interpro%"';

   $self->param('file', $file);
   $self->param('species', $species);
   $self->param('flag_check_annot_exists', $flag_check_annot_exists);
   $self->param('core_dbh', $core_dbh);
   $self->param('dbea', $dbea);
   $self->param('ipr_ext_dbid', $ipr_ext_dbid);
   $self->param('go_ext_dbid', $go_ext_dbid);
   $self->param('sql_clear_table', $sql_clear_table);
   $self->param('sql_get_tid', $sql_get_tid);
   $self->param('sql_get_ipr_tid', $sql_get_ipr_tid);

return 0;
}

sub write_output {
    my ($self)  = @_;

return 0;
}

sub run {
    my ($self)       = @_;

    my $file                    = $self->param_required('file');
    my $species                 = $self->param_required('species');
    my $flag_check_annot_exists = $self->param_required('flag_check_annot_exists');
    my $core_dbh                = $self->param_required('core_dbh');
    my $dbea		        = $self->param_required('dbea');
    my $ipr_ext_dbid            = $self->param_required('ipr_ext_dbid');
    my $go_ext_dbid             = $self->param_required('go_ext_dbid');
    my $sql_clear_table         = $self->param_required('sql_clear_table');
    my $sql_get_tid             = $self->param_required('sql_get_tid');
    my $sql_get_ipr_tid         = $self->param_required('sql_get_ipr_tid');
    my $sql_helper 	        = $self->core_dbc()->sql_helper();
    my $sth_clear_table         = $core_dbh->prepare($sql_clear_table);
    my $sth_get_tid             = $core_dbh->prepare($sql_get_tid);
    my $sth_get_ipr_tid         = $core_dbh->prepare($sql_get_ipr_tid);

    # Hash all interpro accessions exist for the species
    my %interpro_xrefs = %{ $self->get_interpro_xrefs("interpro") };

    # get existing translations with GO terms as a hash for lookup
    my %existing = map { $_ => 1 } @{
		$sql_helper->execute_simple(
			-SQL    => $sql_get_tid,
			-PARAMS => [ $go_ext_dbid, $self->core_dba()->species_id() ]
		)
    };

    my $interpro_terms = {};
    
    # Parse into hash interpro2GO the 'interpro2go' file=> http://www.geneontology.org/external2go/interpro2go
    my $interpro2go = $self->parse_interpro2go( $file, \%interpro_xrefs );
    my ($interpro_ac, $domain, $translation, $transcript);

    # $sth_clear_table->execute($ipr_ext_dbid, $go_ext_dbid);
    $sth_get_ipr_tid->execute($self->core_dba()->species_id());
    $sth_get_ipr_tid->bind_columns(\$interpro_ac, \$domain, \$translation, \$transcript);

    while ($sth_get_ipr_tid->fetch()) {
        # If flag_check_annot_exists is 'ON'
        # verify if a translation_id has GO terms annotated from any other source
        next if ($flag_check_annot_exists==1 && exists $existing{$translation});

        if (defined @{ $$interpro2go{$interpro_ac} } ) {
   	    # get GO annotation
	    my @go_string = @{ $$interpro2go{$interpro_ac} };

            my ($go_id,$go_term);
            # update ontology_xref (ensembl_id->IPR)& object_xref (ensembl_id->GO)
	    foreach my $go_string (@go_string){
	       ($go_id, $go_term) = split (/\|/,$go_string);

               # Get existing GO dbentry from db to avoid duplicates
               my $go_dbentry = $dbea->fetch_by_db_accession( 'GO', $go_id );
	       bless( $go_dbentry, "Bio::EnsEMBL::OntologyXref" ) if ( defined $go_dbentry && ref($go_dbentry) ne "Bio::EnsEMBL::OntologyXref" );

	       # Create new go_dbentry only if is it not seen in db & hash 
	       if ( !defined $go_dbentry ) {
		   $go_dbentry = Bio::EnsEMBL::OntologyXref->new(
			-PRIMARY_ID  => $go_id,
			-DBNAME      => 'GO',
			-DISPLAY_ID  => $go_id,
			-DESCRIPTION => $go_term,
			-INFO_TYPE   => 'NONE',
			-INFO_TEXT   => 'via interpro2go'
 			);
	       } 

	       # Get IPR dbentry from hash to avoid db round trips
	       my $ipr_dbentry = $interpro_terms->{$interpro_ac};
				  
	       # Create new ipr_dbentry only if it is not seen in hash 				  
               if ( !defined $ipr_dbentry ) {
   		  # Get existing IPR dbentry from db to avoid duplicates
   		  # Note: IPR dbentry are all loaded into core via analysis 'load_InterPro_xrefs'
   		  #       should all be found, therefore no need to create new ipr_dbentry
		  $ipr_dbentry = $dbea->fetch_by_db_accession( 'Interpro', $interpro_ac );
		  # hash IPR dbentry locally			
                  $interpro_terms->{$interpro_ac} = $ipr_dbentry;
		}

	        my $analysis = Bio::EnsEMBL::Analysis->new(
			-LOGIC_NAME => 'interpro2go',
			-DB         => $ipr_dbentry->dbname,
			-DB_VERSION => 'NULL',
			-PROGRAM    => 'Interpro2GoLoader.pm',
			-DESCRIPTION=>'InterPro2GO file is generated manually by the InterPro team at the EBI.',
			-DISPLAY_LABEL => 'InterPro2GO mapping',
			);
	
   	       $go_dbentry->add_linkage_type( 'IEA', $ipr_dbentry );			    
 			 
 	       # Attach the new analysis
	       $go_dbentry->analysis($analysis);

   	       # Finally add you annotation term to the ensembl object,
   	       if($species eq 'aspergillus_nidulans'){
		   $dbea->store( $go_dbentry, $transcript, 'Transcript', 1 ); 
               } else {
		   $dbea->store( $go_dbentry, $translation, 'Translation', 1 ); 
	       }
	       #$dbea->store( $go_dbentry, $translation, 'Translation', 1 );		    
		    
  	} #  foreach my $go_string (@go_string){		
     }
  }

  $self->core_dbc->disconnect_if_idle();
  $self->hive_dbc->disconnect_if_idle();   

return 0;
}

############
# SUBROUTINE
############
sub annot_exists {
    my $self        = shift;
    my $translation = shift;
    my $dbid        = shift;
    my $sth         = shift;

    $sth->execute($dbid, $translation);
    my $res=$sth->fetchrow_arrayref;

return $res;
}

sub get_interpro_xrefs{
    my ($self,$source_name) = @_;

    my %interpro_xrefs;
    my $core_dbh = $self->core_dbh;
    my $dbid     = $self->fetch_external_db_id($core_dbh, $source_name);
    my $sql      = "SELECT x.dbprimary_acc,x.xref_id 
                     FROM xref x JOIN interpro i 
                     WHERE i.interpro_ac=x.dbprimary_acc 
                     AND x.external_db_id=$dbid";
    my $sth_interpro_xrefs = $core_dbh->prepare($sql);
    $sth_interpro_xrefs->execute();

    while(my @row = $sth_interpro_xrefs->fetchrow_array()){
         $interpro_xrefs{$row[0]} = $row[1];
    }

return \%interpro_xrefs;
}

sub parse_interpro2go {
    my ($self, $file, $interpro_xrefs) = @_;

    my %interpro2go;
    open(FILE, $file) or die "Could not open '$file' for reading : $!";

    while (<FILE>) {
        chomp $_;
        next if $_ =~ /^!/;

        # InterPro:IPR000003 Retinoid X receptor > GO:DNA binding ; GO:0003677
        if( $_ =~ m/^InterPro:(\S+)\s+(.+)\s+>\s+GO:(.+)\s+;\s+(GO:\d+)/ ){
            my $ipro_id   = $1;
            my $ipro_desc = $2;
            my $go_term   = $3;
            my $go_id     = $4;
            my $go_string = join("|",$go_id,$go_term);

            # Hash interpro2go only if the Intepro_acc is found for this species 
            if(defined($$interpro_xrefs{$ipro_id})){
		      $interpro2go{$ipro_id} ||= [];
     		      push @{$interpro2go{$ipro_id}},$go_string;
	    }
        }
   }

return (\%interpro2go);
}


1;


