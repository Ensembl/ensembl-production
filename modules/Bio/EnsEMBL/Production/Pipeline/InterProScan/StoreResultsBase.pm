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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreResultBase;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreResultsBase;

use strict;
use Carp;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::Base');

=head2 validating_parser

  Getter and setter for the boolean attribute 'validating_parser' which 
  determines whether the parser will perform additional checks on the
  values it gets from the tsv file.
=cut
sub validating_parser {
    my $self  = shift;
    my $value = shift;

    if (defined $value) {

      if ($value==0) {
        $self->{_validating_parser} = undef;
      } else {
        $self->{_validating_parser} = 1;
      }

    return;
    }
return $self->{_validating_parser};
}

=head2 store_protein_feature
=cut
sub store_protein_feature {
    my $self  = shift;
    my $param = shift;

    my $analysis_adaptor        = $param->{analysis_adaptor};
    my $protein_feature_adaptor = $param->{protein_feature_adaptor};
    my $parsed_line             = $param->{parsed_line};

    confess('Type error!') unless(ref $parsed_line eq 'HASH');
    confess('Type error!') unless($analysis_adaptor->isa('Bio::EnsEMBL::DBSQL::AnalysisAdaptor'));

    my $analysis = $analysis_adaptor->fetch_by_logic_name($parsed_line->{analysis});

    confess('Type error!') unless($analysis->isa('Bio::EnsEMBL::Analysis'));
    
    if (!defined $analysis) {

    die(
      "Can't find an analysis of type '" . $parsed_line->{analysis} 
      . "' in the core database. Probably the analysis table in " 
      . $self->database_string_for_user . " has to"
      . " be populated with this type of analysis."
    );
   }
   my $protein_feature = $self->create_protein_feature($parsed_line, $analysis);

   #use Data::Dumper;
   #$self->warning("Parsed line: ". Dumper($parsed_line) ." ------- " . Dumper($protein_feature));
   confess('Type error!') unless($protein_feature->isa('Bio::EnsEMBL::ProteinFeature'));

   $protein_feature_adaptor->store($protein_feature, $protein_feature->translation_id);
}

=head rename_analysis_from_i5_to_eg_nomenclature

    See http://www.ebi.ac.uk/seqdb/confluence/display/EnsGen/Run+InterProScan+pipeline#RunInterProScanpipeline-Renamingofanalysisnames
    for details.
=cut
sub rename_analysis_from_i5_to_eg_nomenclature {
    my $self        = shift;
    my $parsed_line = shift;

    # Email with Arnaud, EG has different logic_names for these 
    # analyses. They are mapped to the EG names here.
    if (lc($parsed_line->{analysis}) eq 'coils') {
      $parsed_line->{analysis} = 'ncoils';
    }
    #if ($parsed_line->{analysis} eq 'ProSitePatterns') {
    if ($parsed_line->{analysis} eq 'PROSITE_PATTERNS') {
      $parsed_line->{analysis} = 'scanprosite';
    }
    #if ($parsed_line->{analysis} eq 'ProSiteProfiles') {
    if ($parsed_line->{analysis} eq 'PROSITE_PROFILES') {    
       $parsed_line->{analysis} = 'pfscan';
    }
  
    # More renaming from Arnaud because of new analysis names in the
    # production database.
    if (uc($parsed_line->{analysis}) eq 'PANTHER') {
      $parsed_line->{analysis} = 'hmmpanther';
    }
    if (uc($parsed_line->{analysis}) eq 'PRODOM') {
      $parsed_line->{analysis} = 'blastprodom';
    }

    # Map all SignalP models to SignalP
    if (
      $parsed_line->{analysis} eq 'SIGNALP_EUK'
    ) {
      $parsed_line->{analysis} = 'SignalP';
    }
    if (
      $parsed_line->{analysis} eq 'SIGNALP_GRAM_NEGATIVE'
      || $parsed_line->{analysis} eq 'SIGNALP_GRAM_POSITIVE'
    ) {
      $parsed_line->{analysis} = 'SignalP';
    }

return $parsed_line;
}

=head insert_xref
=cut
sub insert_xref {
    my $self  = shift;
    my $dbh   = shift;
    my $param = shift;

    my $external_db_id = $param->{external_db_id};
    my $dbprimary_acc  = $param->{dbprimary_acc};
    my $display_label  = $param->{display_label};
    my $description    = $param->{description};

    confess("Type error!") unless ($dbh->isa('DBI::db'));

    my $sql = "INSERT INTO xref (
      external_db_id,
      dbprimary_acc,
      display_label,
      version,
      description,
      info_type,
      info_text
    ) VALUES (?,?,?,1,?, 'DIRECT', '')";

    my $sth = $dbh->prepare($sql);

    $sth->execute(
	$external_db_id,
	$dbprimary_acc,
	$display_label,
	$description
    );
}

=head xref_exists
=cut
sub xref_exists {
    my $self           = shift;
    my $dbh            = shift;
    my $dbprimary_acc  = shift;
    my $external_db_id = shift;

    confess("Type error!") unless ($dbh->isa('DBI::db'));

    my $sql = "select * from xref where dbprimary_acc='$dbprimary_acc' and external_db_id='$external_db_id'";
    my $array_ref = $dbh->selectall_arrayref($sql);

    return @$array_ref>0;
}

=head fetch_external_db_id

  Fetches the external_db_id for the external database name given. Will 
  confess, if there is not exactly one.
=cut
sub fetch_external_db_id {
    my $self             = shift;
    my $dbh              = shift;
    my $external_db_name = shift;

    confess("Type error!") unless ($dbh->isa('DBI::db'));

    my $sql = "select * from external_db where db_name='$external_db_name'";
    my $hash_ref = $dbh->selectall_hashref($sql, 'external_db_id');
    my @external_db_id = keys %$hash_ref;

    if (@external_db_id<1) {
      confess("No external_db with db_name '$external_db_name' found!");
    }
    if (@external_db_id>1) {
      confess("More than one external_db with db_name '$external_db_name' found!");
    }

return $external_db_id[0];
}

=head create_protein_feature
=cut
sub create_protein_feature {
    my $self     = shift;
    my $parsed   = shift;
    my $analysis = shift;

    die('Type error!') unless (ref $parsed eq 'HASH') ;
    die('Type error!') unless ($analysis->isa('Bio::EnsEMBL::Analysis'));

    use Bio::EnsEMBL::ProteinFeature;

    my $protein_feature_score = $parsed->{score};

    #if (($protein_feature_score eq '-') || ($protein_feature_score eq '')) {
    if (($protein_feature_score eq '-')) {
       $protein_feature_score = undef;
    }

    my $protein_feature = Bio::EnsEMBL::ProteinFeature->new(
     -start          => $parsed->{start_location},
     -end            => $parsed->{stop_location},
     -hstart         => defined $parsed->{start_model} ? $parsed->{start_model} : 0,
     -hend           => defined $parsed->{end_model} ? $parsed->{end_model} : 0,
     -percent_id     => undef,
     -score          => $protein_feature_score,
     -p_value        => $parsed->{evalue},
     -hseqname       => $parsed->{signature_accession},
     -seqname        => undef,
     -translation_id => $parsed->{protein_accession},
     -analysis       => $analysis,
     -idesc          => $parsed->{interpro_description},
     -interpro_ac    => $parsed->{interpro_accession},
   );

  # This line is responsible that the column hit_description in the
  # protein_feature table gets set.
  # 
  # The property "idesc" of the ProteinFeature object is not used by
  # the ProteinFeatureAdaptor for this, but hdescription. I think this is a
  # bug and emailed Ensembl about it at the time, but they are not changing
  # it, so the hack has to stay in.
  $protein_feature->{hdescription} = $parsed->{interpro_description};

return $protein_feature;
}

=head parse_interproscan_line
  
  Parse a line of the InterProScan tab separated value output to a hash.
=cut
sub parse_interproscan_line {
    my $self = shift;
    my $line = shift;

    chomp $line;
  
    # Originally defined here:
    # http://code.google.com/p/interproscan/wiki/RunningStandaloneInterProScan#Output_Format
    #
    # The tsv file we use is no the one generated by the script anymore. The 
    # xml output is used and converted to tsv with interproXml2Tsv.xslt. That
    # is what is parsed here.
   (
    my $protein_accession,
    my $md5,
    my $sequence_length,
    my $analysis,
    my $signature_accession,
    my $signature_description,
    my $start_location,
    my $stop_location,
    my $score,
    my $status,
    my $date,
    my $interpro_accession,
    my $interpro_description,
    my $interpro_name,
    my $start_model,
    my $end_model,
    my $evalue,
    )
    = split "\t", $line;

    my $parsed = {
     protein_accession     => $protein_accession,
     md5                   => $md5,
     sequence_length       => $sequence_length,
     analysis              => $analysis,
     signature_accession   => $signature_accession,
     signature_description => $signature_description,
     start_location        => $start_location,
     stop_location         => $stop_location,
     score                 => $score,
     status                => $status,
     date                  => $date,
     interpro_accession    => $interpro_accession,
     interpro_description  => $interpro_description,
     interpro_name         => $interpro_name,
     start_model           => $start_model,
     end_model             => $end_model,
     evalue                => $evalue,
   };

   use Hash::Util qw( lock_keys );
   lock_keys(%$parsed);

   if ($self->validating_parser) {
     eval {
	$self->validate_parsed_line($parsed)
     };
     if ($@) {
	use Data::Dumper;
	confess(
	    "\n\nProblem with this line of tsv:\n\n"
	    . "\"$line\"\n\n"
	    . "which is parsed as \n\n"
	    . Dumper($parsed) . "\n\n"
	    . "the problem is: $@\n\n"
	);
     }
   }

  $self->set_undefined_values($parsed);
  $parsed->{evalue} = $self->parse_number($parsed->{evalue});

return $parsed;
}

sub parse_number {
    my $self   = shift;
    my $number = shift;

    return unless($number);

    use String::Numeric qw( is_decimal );
    my $is_decimal = is_decimal($number);
    return $number if ($is_decimal);

    my $is_scientific_notation = $number =~ /^(.*)[eE]([-+]?)(.*)$/;
    confess("Can't understand format of number: $number")
	unless($is_scientific_notation);

    my $mantissa          = $1;
    my $e_sign            = $2;
    my $exponent_absolute = $3;

    my $exponent  = $e_sign eq '+' ? $exponent_absolute : -1 * $exponent_absolute;
    my $converted = $mantissa * (10 ** $exponent);

return $converted;
}

=head set_undefined_values

  Undefined values can be named to make sure the value really wasn't there and #'
  this is not just a bug. See the interproXml2Tsv.xslt for details.

  This method removes the named undef values and replaces them with proper 
  undef values.
=cut
sub set_undefined_values {
    my $self   = shift;
    my $parsed = shift;

    foreach my $current_tsv_column (keys %$parsed) {
      my $current_value = $parsed->{$current_tsv_column};

      # The string captured by the brackets is the type of data that is missing.
      # See the interproXml2Tsv.xslt file for the values returned.
      my $value_is_missing = $current_value=~/^-(.*)-$/;

      $parsed->{$current_tsv_column} = undef
      if ($value_is_missing);

    }
return;
}

=head validate_parsed_line

  Insert any by line checks of the tsv file in here.
=cut
sub validate_parsed_line {
    my $self   = shift;
    my $parsed = shift;

    use String::Numeric qw( is_float is_int );
    my $interpro_accession = $parsed->{interpro_accession};
    my $is_valid_interpro_accession = $interpro_accession eq '-no ac-' || $interpro_accession =~ /IPR\d+/;
    die("\"$interpro_accession\" is not a valid interpro accession!") unless($is_valid_interpro_accession);

    my $evalue = $parsed->{evalue};
    my $is_valid_evalue = $evalue eq '-no evalue-' || is_float($evalue);
    die("\"$is_valid_evalue\" is not a valid evalue!") unless($is_valid_evalue);

    my $start_model = $parsed->{start_model};
    my $is_valid_start_model = $start_model eq '-no start-' || is_int($start_model);
    die("\"$is_valid_start_model\" is not a valid start!") unless($is_valid_start_model);

    my $end_model = $parsed->{end_model};
    my $is_valid_end_model = $end_model eq '-no end-' || is_int($end_model);
    die("\"$is_valid_end_model\" is not a valid end!") unless($is_valid_end_model);

    my $model_coords_ok = $parsed->{start_model} <= $parsed->{end_model};

    if (!$model_coords_ok) {
     die(
        "start_model must be smaller or equals end_model!\n"
     );
    }

return;
}

1;



