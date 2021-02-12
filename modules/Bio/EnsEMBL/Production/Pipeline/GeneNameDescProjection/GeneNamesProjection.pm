=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::GeneNamesProjection

=cut

=head1 DESCRIPTION

 Pipeline to project gene names from one species to another 
 by using the homologies derived from the Compara ProteinTree pipeline. 

=cut
package Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::GeneNamesProjection;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;

use base ('Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::Base');

sub run {
  my ($self) = @_;

  my $to_species             = $self->param_required('species');
  my $from_species           = $self->param_required('source');
  my $compara                = $self->param_required('compara');
  my $release                = $self->param_required('release');
  my $output_dir             = $self->param_required('output_dir');
  my $method_link_type       = $self->param_required('method_link_type');
  my $homology_types_allowed = $self->param_required('homology_types_allowed');
  my $is_tree_compliant      = $self->param_required('is_tree_compliant');
  my $percent_id_filter      = $self->param_required('percent_id_filter');
  my $percent_cov_filter     = $self->param_required('percent_cov_filter');
  my $project_xrefs          = $self->param_required('project_xrefs');

  my $reg = 'Bio::EnsEMBL::Registry';

  my $from_ga = $reg->get_adaptor($from_species, 'core', 'Gene');
  my $to_ga   = $reg->get_adaptor($to_species  , 'core', 'Gene');
  my $to_ta   = $reg->get_adaptor($to_species  , 'core', 'Transcript');
  my $to_dbea = $reg->get_adaptor($to_species  , 'core', 'DBEntry');
  my $aa      = $reg->get_adaptor($to_species  , 'core', 'Analysis');
  if (!$from_ga || !$to_ga || !$to_ta || !$to_dbea) {
    die("Problem getting core db adaptor(s)");
  }
  my $analysis = $aa->fetch_by_logic_name('xref_projection');

  my $mlssa = $reg->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet'); 
  my $ha    = $reg->get_adaptor($compara, 'compara', 'Homology'); 
  my $gdba  = $reg->get_adaptor($compara, 'compara', 'GenomeDB'); 
  if (!$mlssa || !$ha || !$gdba) {
    die("Problem getting compara db adaptor(s)");
  }

  $self->check_directory($output_dir);
  my $log_file  = "$output_dir/$from_species-$to_species\_GeneNamesProjection_logs.txt";
  open my $log, ">", "$log_file" or die $!;
  print $log "\n\tProjection log :\n";
  print $log "\t\tsoftware release :$release\n";
  print $log "\t\tfrom :".$from_ga->dbc()->dbname()." to :".$to_ga->dbc()->dbname()."\n";

  my $from_GenomeDB = $gdba->fetch_by_registry_name($from_species);
  if (!defined $from_GenomeDB) {
    print $log "Aborting: Genome DB not found for $from_species";
    return;
  }
  my $to_GenomeDB = $gdba->fetch_by_registry_name($to_species);
  if (!defined $to_GenomeDB) {
    print $log "Aborting: Genome DB not found for $to_species";
    return;
  }
  my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$from_GenomeDB, $to_GenomeDB]);
  if (!defined $mlss) {
    print $log "Aborting: No orthology found for $from_species to $to_species";
    return;
  }
  my $mlss_id = $mlss->dbID();

  # build hash of external db name -> ensembl object type mappings
  my $source_db_to_type = $self->build_db_to_type($from_ga);

  # Get homologies from compara - comes back as a hash of arrays
  print $log "\n\tRetrieving homologies of method link type $method_link_type for mlss_id $mlss_id \n";
  my $homologies = $self->fetch_homologies(
    $ha, $mlss, $from_species, $log, $gdba, $homology_types_allowed, $is_tree_compliant, $percent_id_filter, $percent_cov_filter
  );

  print $log "\n\tProjecting Gene Names from $from_species to $to_species\n\n";

  while (my ($from_stable_id, $to_genes) = each %{$homologies}) {
    my $from_gene = $from_ga->fetch_by_stable_id($from_stable_id);
    next if (!$from_gene);

    my $to_gene_count = scalar(@{$to_genes});

    foreach my $to_stable_id (@{$to_genes}) {
      my $to_gene  = $to_ga->fetch_by_stable_id($to_stable_id);
      next if (!$to_gene);

      if ($project_xrefs) {
        $self->project_all_xrefs($to_dbea, $from_gene, $to_gene, $to_gene_count, $source_db_to_type, $analysis, $log);
      }

      $self->project_gene_names($to_ga, $to_ta, $to_dbea, $from_gene, $to_gene, $to_gene_count, $analysis, $log);
    }
  }

  close($log);

  # Explicit disconnect to free up database connections
  $from_ga->dbc->disconnect_if_idle();
  $to_ga->dbc->disconnect_if_idle();
  $mlssa->dbc->disconnect_if_idle();
}

# Project all the xrefs from one species to another
sub project_all_xrefs {
  my ($self, $to_dbea, $from_gene, $to_gene, $to_gene_count, $source_db_to_type, $analysis, $log)  = @_;

  my $from_species      = $self->param_required('source');
  my $store_projections = $self->param_required('store_projections');
  my $white_list        = $self->param_required('white_list');

  foreach my $dbEntry (@{$from_gene->get_all_DBLinks()}) {
    my @to_transcripts = @{$to_gene->get_all_Transcripts};
    my $to_transcript = $to_transcripts[0];

    my $from_gene_dbname = $dbEntry->dbname();
    my $type = $source_db_to_type->{$from_gene_dbname};

    # Only project xrefs from the white list.
    if (grep (/$from_gene_dbname/, @$white_list)) {
      print $log "\t\tProject xref from:".$from_gene->stable_id()."\t";
      print $log "to: ".$to_gene->stable_id()."\t";
      print $log "Xref: ".$dbEntry->display_id()."\t";
      print $log "Source: ".$from_gene_dbname."\n";

      if ($store_projections) {
        # Modify the dbEntry to indicate it's not from this species
        my $info_txt = "from $from_species gene " . $from_gene->stable_id();

        # Modify the display_id to have "(1 of many)" if this is a one-to-many ortholog
        if ($to_gene_count > 1) {
          my $tuple_txt = " (1 of many)";
          $info_txt .= $tuple_txt;

          my $existing = $dbEntry->display_id();
          if ($existing !~ / \(1 of many\)/) {
            $dbEntry->display_id($existing . $tuple_txt);
          }
        }

        $dbEntry->info_type("PROJECTION");
        $dbEntry->info_text($info_txt);
        $dbEntry->analysis($analysis);

        if ($type eq "Gene") {
          $to_gene->add_DBEntry($dbEntry);
          $to_dbea->store($dbEntry, $to_gene->dbID(), 'Gene', 1);
        } elsif ($type eq "Transcript") {
          $to_transcript->add_DBEntry($dbEntry);
          $to_dbea->store($dbEntry, $to_transcript->dbID(), 'Transcript', 1);
        } elsif ($type eq "Translation") {
          my $to_translation = $to_transcript->translation();
          return if (!$to_translation);
          $to_translation->add_DBEntry($dbEntry);
          $to_dbea->store($dbEntry, $to_translation->dbID(), 'Translation',1);
        }
      }
    }
  }
}

sub project_gene_names {
  my ($self, $to_ga, $to_ta, $to_dbea, $from_gene, $to_gene, $to_gene_count, $analysis, $log)  = @_;

  my $from_species        = $self->param_required('source');
  my $to_species          = $self->param_required('species');
  my $compara             = $self->param_required('compara');
  my $store_projections   = $self->param_required('store_projections');
  my $gene_name_source    = $self->param_required('gene_name_source');
  my $project_trans_names = $self->param_required('project_trans_names');

  # Checking that source passed the rules
  if (defined $from_gene->display_xref()) {
    if ($self->is_target_ok($from_gene, $to_gene, $from_species, $to_species)) {
      my $from_gene_dbname     = $from_gene->display_xref->dbname();
      my $from_gene_primary_id = $from_gene->display_xref->primary_id();
      my $from_gene_display_id = $from_gene->display_xref->display_id();

      if (grep (/$from_gene_dbname/, @$gene_name_source)) {
        print $log "\t\tProject name from:".$from_gene->stable_id()."\t";
        print $log "to: ".$to_gene->stable_id()."\t";
        print $log "Gene Name: $from_gene_display_id\t";
        print $log "Source: $from_gene_dbname\n";

        if ($store_projections) {
          my $to_gene_display_id = $from_gene_display_id;
          my $info_txt = "from $from_species gene " . $from_gene->stable_id();
          my $description = $from_gene->display_xref->description();

          if ($to_gene_count > 1) {
            my $tuple_txt = " (1 of many)";
            $to_gene_display_id .= $tuple_txt;
            $info_txt .= $tuple_txt;
          }

          my $dbEntry = Bio::EnsEMBL::DBEntry->new(
            -PRIMARY_ID  => $from_gene_primary_id,
            -DISPLAY_ID  => $from_gene_display_id,
            -DBNAME      => $from_gene_dbname,
            -INFO_TYPE   => 'PROJECTION',
            -INFO_TEXT   => $info_txt,
            -DESCRIPTION => $description,
            -ANALYSIS    => $analysis,
          );

          $to_dbea->store($dbEntry, $to_gene->dbID(), 'Gene', 1);
          $to_gene->display_xref($dbEntry);

          if ($project_trans_names) {
            $self->project_transcript_names($to_dbea, $to_ta, $dbEntry, $to_gene, $log);
          }

          $to_ga->update($to_gene);
        }
      }
    }
  }
}

sub project_transcript_names {
  my ($self, $to_dbea, $to_ta, $dbEntry, $to_gene, $log)  = @_;

  # Force loading of external synonyms for the xref
  $dbEntry->get_all_synonyms();

  my $from_gene_dbname = $dbEntry->dbname();
  my $dbname = "$from_gene_dbname\_trans_name";

  my $base_name = $dbEntry->display_id();
  my $offset = 201;

  foreach my $transcript (@{$to_gene->get_all_Transcripts}) {
    my $name = sprintf('%s-%03d', $base_name, $offset);

    print $log "\t\t\tProject transcript names\t";
    print $log "to: ".$transcript->stable_id()."\t";
    print $log "Transcript Name: $name\t";
    print $log "DB: $from_gene_dbname\n";

    my $t_dbEntry = Bio::EnsEMBL::DBEntry->new(
      -PRIMARY_ID  => $name,
      -DISPLAY_ID  => $name,
      -DBNAME      => $dbname,
      -INFO_TYPE   => 'PROJECTION',
      -INFO_TEXT   => $dbEntry->info_text(),
      -DESCRIPTION => $dbEntry->description(),
      -ANALYSIS    => $dbEntry->analysis(),
    );
    $to_dbea->store($t_dbEntry, $transcript->dbID(), 'Transcript', 1);
    $transcript->display_xref($t_dbEntry);
    $to_ta->update($transcript);

    $offset++;
  }
}

sub build_db_to_type {
  my ($self, $to_ga) = @_;

  my $db_to_type;

  my $sql = q/
    SELECT DISTINCT
      db_name,
      ensembl_object_type
    FROM
      external_db INNER JOIN
      xref USING (external_db_id) INNER JOIN
      object_xref ox USING (xref_id)  
  /;
  my $sth = $to_ga->dbc()->prepare($sql);
  $sth->execute();
  my ($db_name, $type);
  $sth->bind_columns(\$db_name, \$type);
  while($sth->fetch()){
    $db_to_type->{$db_name} = $type;
  }
  $sth->finish;

  return $db_to_type;
}

sub is_target_ok {
  my ($self, $from_gene, $to_gene, $from_species, $to_species) = @_;

  my $from_dbname = $from_gene->display_xref->dbname();
  my $to_dbname   = $to_gene->display_xref->dbname() if ($to_gene->display_xref());
  $to_dbname ||= q{}; #can be empty; this stops warning messages

  # Exit early if we have a gene name & the species was not danio_rerio, sus_scrofa or mouse
  return 1 if (!$to_gene->external_name() && $to_species ne "danio_rerio" && $to_species ne 'sus_scrofa' && $to_species ne 'mus_musculus');

  # Exit early if it was a RefSeq predicted name & source was a vetted good symbol
  if ($to_dbname eq "RefSeq_mRNA_predicted" || $to_dbname eq "RefSeq_ncRNA_predicted" || $to_dbname eq "RefSeq_peptide_predicted") {
    if (($from_species eq "homo_sapiens" && $from_dbname =~ /HGNC/) ||
        ($from_species eq "mus_musculus" && $from_dbname =~ /MGI/) ||
        ($from_species eq "danio_rerio" && $from_dbname =~ /ZFIN_ID/))
    {
      if ($to_species eq "danio_rerio" and $self->is_in_blacklist($from_gene->display_xref)) {
        return 0;
      }
      return 1;
    }
  }
  # Zebrafish specific logic; do not re-write!
  elsif ($to_species eq "danio_rerio"){
    my $to_dbEntry = $to_gene->display_xref();
    my $from_dbEntry = $from_gene->display_xref();
    my $to_seq_region_name = $to_gene->seq_region_name();

    return 1 if ($to_dbname eq "Clone_based_ensembl_gene" or $to_dbname eq "Clone_based_vega_gene");

    my $name = $from_gene->display_xref->display_id;
    $name =~ /(\w+)/; # remove (x of y) in name.
    $name = $1;

    if ($name =~ /C(\w+)orf(\w+)/) {
      my $new_name = "C".$to_seq_region_name."H".$1."orf".$2;
      $from_gene->display_xref->display_id($new_name);
      return 1;
    }

    if (!defined ($to_dbEntry) || (($to_dbEntry->display_id =~ /:/) and $to_dbname eq "ZFIN_ID")) {
      return !($self->is_in_blacklist($from_dbEntry));
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

sub is_in_blacklist{
  # Catches clones and analyses when projecting display xrefs.
  my ($self, $dbentry) = @_;

  if (($dbentry->display_id =~ /KIAA/) || ( $dbentry->display_id =~ /LOC/)) {
    return 1;
  } elsif ($dbentry->display_id =~ /\-/) {
    return 1;
  } elsif ($dbentry->display_id =~ /\D{2}\d{6}\.\d+/) {
    return 1;
  } else {
    return 0;
  }
}

1;
