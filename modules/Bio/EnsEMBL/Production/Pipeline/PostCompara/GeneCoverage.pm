=pod 

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneCoverage

=cut

=head1 DESCRIPTION

 This Runnable uses the cigar lines generated from a Compara run to generate 
 consistency metrics for Compara clusters. Specifically, it compares the 
 extent of each protein sequence in the alignment to the extent of the cluster consensus.

=head1 AUTHOR 

ckong

=cut
package Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneCoverage;

use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Production::Pipeline::PostCompara::Base');
use Bio::EnsEMBL::Utils::Exception qw(throw);

sub run {
    my ($self) = @_;

    my $division     = $self->param_required('division');
    my $root_id      = $self->param_required('root_id');

    my $hive_dbc = $self->dbc;
    $hive_dbc->disconnect_if_idle() if defined $hive_dbc;

    my $sql_geneTree       = "SELECT r.root_id, cigar_line, n.node_id, m.stable_id, m.taxon_id, g.name
                        FROM gene_tree_node n, gene_tree_root r, seq_member m, genome_db g, gene_align_member gam
                        WHERE m.seq_member_id = n.seq_member_id
                        AND gam.seq_member_id = m.seq_member_id
                        AND r.root_id = n.root_id
                        AND r.clusterset_id = 'default'
                        AND gam.gene_align_id = r.gene_align_id
                        AND g.genome_db_id = m.genome_db_id
            AND r.root_id =? ";

    my $dba_compara = Bio::EnsEMBL::Registry->get_DBAdaptor($division, "compara");
    my $array_ref   = $dba_compara->dbc()->sql_helper()->execute(-SQL => $sql_geneTree, -PARAMS => [$root_id]);
    my @cigars;
   
    foreach my $row (@{$array_ref}) {
       my ($root_id, $cigar_line, $node_id, $stable_id, $taxon_id, $name) = @{$row};
       push @cigars, join '^^', $stable_id, $name, $cigar_line;
    }
    $self->process_cigar_line(\@cigars, $root_id);
#Disconnecting from the registry
$dba_compara->dbc->disconnect_if_idle();
return;
}

sub process_cigar_line {
    my $self    = shift;
    my $cigars  = shift;
    my $root_id = shift;

    my $sequence = 0;
    my (@hits, @misses);

    ## parse cigar strings into hit/miss matrix
    for my $x (@$cigars) {
        my ($id, $species, $cigar) = split '\^\^', $x;
        my $position = 0;

        while (length $cigar > 0) {
          my ($number, $letter) = ($cigar =~ /^(\d*)(\w)/);
          $number = 1 if ($number eq '');

          for (my $i = 0; $i < $number; $i++) {
            if ($letter eq 'D') {
              $misses[$position][$sequence] = 1;
              $hits  [$position][$sequence] = 0;
            } else {
              $hits[$position][$sequence]   = 1;
              $misses[$position][$sequence] = 0;
            }
           $position++;
         }
         $cigar =~ s/^\d*\w//;
      }# while (length
      $sequence++;
    } #for my $x

    my @profile;
    my $positions = scalar @hits;

    if ($positions == 0) {
      #print $lastRootId, "\n";
      print STDERR Dumper @hits,   "\n";
      print STDERR Dumper @misses, "\n";
    }

    ## Summing up the hits & misses count on each position
    ## for all sequences
    for (my $i = 0; $i < $positions; $i++) {
        my $hits   = 0;
        my $misses =0;

        for my $sequence (@{$hits[$i]}) {
            if ($hits[$i][$sequence] == 1){ $hits++; }
            elsif ($misses[$i][$sequence] == 1){ $misses++; }
            else { print STDERR join "*",
               #$lastRootId,
               $positions, scalar @hits, $i, $sequence, $hits[$i][$sequence], $misses[$i][$sequence], "\n";
                   die; # asusmptions of code are false
            }
       } #for my $sequence

      ## Summarize hits & misses count into consensus profile for each position
      if ($hits >= $misses) { $profile[$i] = 1; }
      else { $profile[$i] = 0; }
    } # for (my $i=0

    if (! defined $hits[0]) {
       print STDERR "Problem for root ID: $root_id\n";
       print Dumper @hits;
       print "**\n";
       print Dumper @misses;
       die;
    }

    ## For each sequence derive score
    for (my $i = 0; $i < scalar @{$hits[0]}; $i++) {
        my $match = 0; my $unmatched = 0;
        my $extra = 0; my $wc = 0;

        ## Compare each position hit/miss matrix against the consensus profile
        for (my $j = 0; $j < scalar @hits; $j ++) {
          if ($hits[$j][$i] == $profile[$j]) {
             if ($profile[$j] == 1) { $match++; }
             else { $wc++; }
          } else {
         # profile is positive, protein is zero
             if ($profile[$j] == 1) { $unmatched++; }
             # profile is negative, protein is positve
         else { $extra++; }
      }
        } # for (my $j

      ## Derive scores for each sequence
      my ($id, $species, $cigar) = split '\^\^', @$cigars[$i];
      my $score1       = $match / ($match + $extra);
      # score 2: proportion of true positives, could be 0/0!
      my $score2;

      if ($match + $unmatched == 0) {
         print STDERR "Root ID: $root_id has no concensus positives\n";
         $score2 = 0;
      } else { $score2 = $match / ($match + $unmatched); }

      store_gene_attrib($id, $species, $score1, $score2);

    } # for ( my $i

return 0;
}

sub store_gene_attrib {
    my ($id, $species, $score1, $score2) = @_;

    my $db_adaptor;
    eval {
      $db_adaptor  = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
    };
    if(!defined $db_adaptor) {
      warn "Could not find species $species for gene $id - skipping";
      return;      
    }
    my $gene_adaptor   = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Gene');
    my $attrib_adaptor = $db_adaptor->get_AttributeAdaptor();
    my $gene           = $gene_adaptor->fetch_by_translation_stable_id($id);
    if(!defined $gene) {
      warn "Could not find gene with translation stable ID $id for species $species - skipping";
      return;
    }
    my $gene_id        = $gene->dbID();

    # Ensure attrib_types exists in core
    my $attrib_prot    = $attrib_adaptor->fetch_by_code('protein_coverage');
    my $attrib_cons    = $attrib_adaptor->fetch_by_code('consensus_coverage');
    my $attrib_prot_id = @$attrib_prot[0];
    my $attrib_cons_id = @$attrib_cons[0];

    if(!defined @$attrib_cons[1] || !defined @$attrib_prot[1]){
        die( "\n\tEither 'protein_coverage' or 'consensus_coverage' attrib_type is missing. Please check attrib_type table.\n");
    }

    # Cleared up gene_attrib table before loading latest data
    print STDERR "Delete existing 'protein_coverage' & 'consensus_coverage' gene_attrib\n";

    my $sql_clear_tbl = "DELETE from gene_attrib where gene_id=$gene_id AND attrib_type_id IN ($attrib_prot_id, $attrib_cons_id)";
    $gene_adaptor->dbc()->sql_helper()->execute_update(-SQL => $sql_clear_tbl);

    my @attribs;

    my $attrib1 = Bio::EnsEMBL::Attribute->new(
                -CODE        => 'protein_coverage',
                -NAME        => '',
                -DESCRIPTION => '',
                -VALUE       => $score1);

    my $attrib2 = Bio::EnsEMBL::Attribute->new(
                -CODE        => 'consensus_coverage',
                -NAME        => '',
                -DESCRIPTION => '',
                -VALUE       => $score2);

    push @attribs, $attrib1;
    push @attribs, $attrib2;

    $attrib_adaptor->store_on_Gene($gene, \@attribs);
    $gene_adaptor->dbc->disconnect_if_idle();
    $db_adaptor->dbc->disconnect_if_idle();
return 0;
}


1;
