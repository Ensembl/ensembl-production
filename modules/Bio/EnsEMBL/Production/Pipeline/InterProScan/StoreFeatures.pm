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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreFeatures;

=head1 DESCRIPTION

  This module will parse the xml results from InterproScan into tsv file
  and store protein features and xref information into the core database

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreFeatures;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use XML::Simple;
use Bio::EnsEMBL::DBSQL::AnalysisAdaptor;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreFeaturesBase');

sub fetch_input {
    my $self = shift @_;

    my $core_dbh             = $self->core_dbh;
    confess('Type error!') unless($core_dbh->isa('DBI::db'));

    my $species              = $self->param_required('species');
    my $external_db_id       = $self->fetch_external_db_id($core_dbh, 'Interpro');
    my $go_external_db_id    = $self->fetch_external_db_id($core_dbh, 'GO');
    my $xml_file             = $self->param_required('interpro_xml_file');
    my $tsv_file             = qq($xml_file.tsv);

    $self->param('xml_file', $xml_file);
    $self->param('tsv_file', $tsv_file);

    if (-s $xml_file == 0) {
        $self->warning("File $xml_file is empty, so not running processing on it.");
    return;
    }

    # For protein features
    $self->get_logger->info("Creating adaptors needed for storing protein features");
    my $analysis_adaptor             = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Analysis');
    my $protein_feature_adaptor      = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'ProteinFeature');
    $self->{analysis_adaptor}        = $analysis_adaptor;
    $self->{protein_feature_adaptor} = $protein_feature_adaptor;

    # For interpro xref
    $self->get_logger->info("Creating sql needed for storing interpro xref");
    my $sth_insert_interpro = $core_dbh->prepare("insert into interpro (interpro_ac, id) values (?,?)");
    my $sth_check_interpro  = $core_dbh->prepare("select count(*) from interpro where interpro_ac=? and id=?");
    confess('Type error!') unless($sth_insert_interpro->isa('DBI::st'));
    confess('Type error!') unless($sth_check_interpro->isa('DBI::st'));

    my %store_protein_interpro_xref_params = (
        sth_insert_interpro => $sth_insert_interpro,
        sth_check_interpro  => $sth_check_interpro,
        core_dbh            => $core_dbh,
        external_db_id      => $external_db_id,
    );
    $self->{store_protein_interpro_xref_params} = \%store_protein_interpro_xref_params;

    # For interpro2Pathway annotation
    $self->get_logger->info("Creating adaptors needed for storing interpro2pathway annotation");
    my $dbea            = Bio::EnsEMBL::Registry->get_adaptor($species,'Core','DBEntry');

    my %store_pathway_xref_params = (
         dbea    => $dbea,
    );
    $self->{store_pathway_xref_params} = \%store_pathway_xref_params;

return;
}

sub run {
    my $self = shift @_;

    my $xml_file = $self->param_required('xml_file');
    my $tsv_file = $self->param_required('tsv_file');

    $self->get_logger->info("Converting xml file: $xml_file to tsv file: $tsv_file");
    
    my $ref = XMLin($xml_file,KeyAttr =>[] , ForceArray => []);
    open my $file, ">", "$tsv_file" or die $!;

    return if(ref($ref->{protein}) ne 'ARRAY');
 
    foreach my $protein (@{$ref->{protein}}) {

	#  'xref' => [
	#                                   {
	#                                     'id' => '801'
	#                                   },
	#                                   {
	#                                     'id' => '802'
	#                                   }
	#                                 ],
        # is bit odd to do this but needed since there are cases 
        # where there are 2 xref id with the same matches
       if(ref($protein->{xref}) eq 'ARRAY'){
          foreach my $xref (@{$protein->{xref}}){
      	     my $trans_id  = $xref->{id};
       	     my $md5       = $protein->{sequence}->{md5};
       	     my $seq_len   = length($protein->{sequence}->{content});

             next unless scalar(keys %{$protein->{matches}}) > 0;

       	     foreach my $match (keys %{$protein->{matches}}){
          	my $location;
          	
		if(ref($protein->{matches}->{$match}) eq 'ARRAY'){
              	       foreach my $m (@{$protein->{matches}->{$match}}){
                          parse_data($self, $m, $match, $trans_id, $md5, $seq_len, $file);
              	       }
          	}else{
              		my $m = $protein->{matches}->{$match};
              		parse_data($self, $m, $match, $trans_id, $md5, $seq_len, $file);
          	}
             }
       	  }
       }else{

       my $trans_id  = $protein->{xref}->{id};
       my $md5       = $protein->{sequence}->{md5};
       my $seq_len   = length($protein->{sequence}->{content});

       # Skip if there is no matches for a protein
       next unless scalar(keys %{$protein->{matches}}) > 0;

       foreach my $match (keys %{$protein->{matches}}){
          my $location;

	  # Check in the event there are multiple hits for a $match type
          if(ref($protein->{matches}->{$match}) eq 'ARRAY'){
              foreach my $m (@{$protein->{matches}->{$match}}){
                 parse_data($self, $m, $match, $trans_id, $md5, $seq_len, $file);
              }
          }else{
              my $m = $protein->{matches}->{$match};
              parse_data($self, $m, $match, $trans_id, $md5, $seq_len, $file);
          }
      }
     }

   }
   close($file);


return;
}

sub write_output {
    my $self = shift @_;

    my $xml_file = $self->param_required('xml_file');
    my $tsv_file = $self->param_required('tsv_file');
    my $required_externalDb = $self->param_required('required_externalDb');

    $self->validating_parser($self->param('validating_parser'));
    $self->get_logger->info("Storing protein features & interpro xref from: $tsv_file");

    open IN, "$tsv_file";

    LINE:while (my $current_tsv_line = <IN>) {
         next LINE if ($current_tsv_line =~ /^\s*$/);
         my $parsed_line;

         eval {$parsed_line = $self->parse_interproscan_line($current_tsv_line);};

         if ($@) {
             confess("\n\nThe following problem occurred when parsing the file\n$tsv_file:\n\n".$@);
         }
         next LINE if ($self->line_is_forgiveable_error({
                parsed_line  => $parsed_line,
                protein_file => $tsv_file,
              }));

         $parsed_line = $self->rename_analysis_from_i5_to_eg_nomenclature($parsed_line);

         # Storing into 'protein_features' table 
         $self->store_domain($parsed_line);

         # Storing interpro xref into 'interpro' & 'xref' table
         $self->store_interpro_and_xref({
           %{$self->{store_protein_interpro_xref_params}},
           parsed_line => $parsed_line
         });

         # Storing Pathway xref into  
         $self->store_pathway_xref({
           %{$self->{store_pathway_xref_params}},
           parsed_line => $parsed_line,
           required_externalDb => $required_externalDb            
         });

   }
   close IN;

   $self->dbc->disconnect_if_idle();

return;
}

############
# SUBROUTINE
############
sub parse_data {
    my ($self, $m, $match, $trans_id, $md5, $seq_len, $file) = @_;

    my $ipr_analysis_nm ='-na-';
    my $ipr_sign_acc    ='-na-';
    my $ipr_sign_desc   ='-na-';
    my $start           ='-na-';
    my $end             ='-na-';
    my $score           ='-na-';
    my $ipr_acc         ='-na-';
    my $ipr_entry_desc  ='-na-';
    my $ipr_entry_nm    ='-na-';
    my $hmm_start       ='-na-';
    my $hmm_end         ='-na-';
    my $evalue          ='-na-';
    my $go_string       ='-na-';
    my $pathway_string  ='-na-';
    my $location;

    $location  = $self->get_location($match);

    if(!defined $location){
     $self->get_logger->warning("match location needs to be defined");
    }

    $ipr_analysis_nm = $m->{signature}->{'signature-library-release'}->{library} if(defined $m->{signature}->{'signature-library-release'}->{library});

    if(ref($m->{signature}->{models}->{model}) eq 'HASH'){
       $ipr_sign_acc    = $m->{signature}->{models}->{model}->{ac}   if(defined $m->{signature}->{models}->{model}->{ac});
       $ipr_sign_desc   = $m->{signature}->{models}->{model}->{desc} if(defined $m->{signature}->{models}->{model}->{desc}); 
    }
    else {
       $ipr_sign_acc    = $m->{signature}->{ac} if(defined $m->{signature}->{ac});
    }

    if(ref($m->{locations}->{$location}) eq 'HASH'){
       $start           = $m->{locations}->{$location}->{start}       if(defined $m->{locations}->{$location}->{start});
       $end             = $m->{locations}->{$location}->{end}         if(defined $m->{locations}->{$location}->{end});
       # $score           = $m->{locations}->{$location}->{score}      if(defined $m->{locations}->{$location}->{score});
       # use 'score' from <xxx-match tag instead of <xxx-locations
       $score           = $m->{score}                                 if (defined $m->{score});
       $ipr_acc         = $m->{signature}->{entry}->{ac}              if(defined $m->{signature}->{entry}->{ac});
       $ipr_entry_desc  = $m->{signature}->{entry}->{desc}            if(defined $m->{signature}->{entry}->{desc});
       $ipr_entry_nm    = $m->{signature}->{entry}->{name}            if(defined $m->{signature}->{entry}->{name});
       $hmm_start       = $m->{locations}->{$location}->{'hmm-start'} if(defined $m->{locations}->{$location}->{'hmm-start'});
       $hmm_end         = $m->{locations}->{$location}->{'hmm-end'}   if(defined $m->{locations}->{$location}->{'hmm-end'});
       # $evalue         = $m->{locations}->{$location}->{'evalue'}    if(defined $m->{locations}->{$location}->{'evalue'});
       # use 'evalue' from <xxx-match tag instead of <xxx-locations
       $evalue          = $m->{evalue}                                if (defined $m->{evalue});

       if(ref($m->{signature}->{entry}->{'go-xref'}) eq 'ARRAY'){
            $go_string = $self->get_go_string($m,$go_string);
       }

       if(ref($m->{signature}->{entry}->{'pathway-xref'}) eq 'ARRAY'){
            $pathway_string = $self->get_pathway_string($m,$pathway_string);
       }

       print_tsv($file, $trans_id, $md5, $seq_len, $ipr_analysis_nm, $ipr_sign_acc, $ipr_sign_desc, $start, $end, $score, $ipr_acc, $ipr_entry_desc, $ipr_entry_nm, $hmm_start, $hmm_end, $evalue,$go_string, $pathway_string);
    } 
    else {
      foreach my $loc (@{$m->{locations}->{$location}}) {
	 $start           = $loc->{start}                    if(defined $loc->{start});
	 $end             = $loc->{end}       		     if(defined $loc->{end});
         # $score         = $loc->{score}       	     if(defined $loc->{score});
         # use 'score' from <xxx-match tag instead of <xxx-locations
         $score           = $m->{score} 		     if(defined $m->{score});  
         $ipr_acc         = $m->{signature}->{entry}->{ac}   if(defined $m->{signature}->{entry}->{ac});
         $ipr_entry_desc  = $m->{signature}->{entry}->{desc} if(defined $m->{signature}->{entry}->{desc});
         $ipr_entry_nm    = $m->{signature}->{entry}->{name} if(defined $m->{signature}->{entry}->{name});
         $hmm_start       = $loc->{'hmm-start'} 	     if(defined $loc->{'hmm-start'});
         $hmm_end         = $loc->{'hmm-end'}   	     if(defined $loc->{'hmm-end'});
         # $evalue          = $loc->{'evalue'}    	     if(defined $loc->{'evalue'});
         # use 'evalue' from <xxx-match tag instead of <xxx-locations
         $evalue          = $m->{evalue}                     if (defined $m->{evalue});
       
         if(ref($m->{signature}->{entry}->{'go-xref'}) eq 'ARRAY'){
            $go_string = $self->get_go_string($m,$go_string);
         }

         if(ref($m->{signature}->{entry}->{'pathway-xref'}) eq 'ARRAY'){
            $pathway_string = $self->get_pathway_string($m,$pathway_string);
         }

       print_tsv($file, $trans_id, $md5, $seq_len, $ipr_analysis_nm, $ipr_sign_acc, $ipr_sign_desc, $start, $end, $score, $ipr_acc, $ipr_entry_desc, $ipr_entry_nm, $hmm_start, $hmm_end, $evalue, $go_string, $pathway_string);

     }
    }

return 0;
}


sub print_tsv {
    my ($file, $trans_id, $md5, $seq_len, $ipr_analysis_nm, $ipr_sign_acc, $ipr_sign_desc, $start, $end, $score, $ipr_acc, $ipr_entry_desc, $ipr_entry_nm, $hmm_start, $hmm_end, $evalue, $go_string, $pathway_string) = @_;

    print $file "$trans_id\t$md5\t$seq_len\t";
    print $file "$ipr_analysis_nm\t$ipr_sign_acc\t$ipr_sign_desc\t";
    print $file "$start\t$end\t$score\t";
    print $file "$ipr_acc\t$ipr_entry_desc\t$ipr_entry_nm\t";
    print $file "$hmm_start\t$hmm_end\t$evalue\t";
    print $file "$go_string\t$pathway_string\n";

return 0;
}


1;





