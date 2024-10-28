#!/usr/bin/env perl
#  Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
#  Copyright [2016-2024] EMBL-European Bioinformatics Institute
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;
use Data::Dumper;
use Carp;
use DBI;
use JSON;
use Getopt::Long;

use Nextflow::Utils;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Mapper::RangeRegistry;

my ($xref_db_url, $core_db_url, $otherf_db_url, $source_ids_json, $species_id, $species_name, $release);
GetOptions(
  'xref_db_url=s'   => \$xref_db_url,
  'core_db_url=s'   => \$core_db_url,
  'otherf_db_url=s' => \$otherf_db_url,
  'source_ids=s'    => \$source_ids_json,
  'species_id=i'    => \$species_id,
  'species_name=s'  => \$species_name,
  'release=i'       => \$release
);

# Check that all parameters are passed
if (!defined($xref_db_url) || !defined($core_db_url) || !defined($otherf_db_url) || !defined($source_ids_json) || !defined($species_id) || !defined($species_name) || !defined($release)) {
  croak "Usage: dump_ensembl.pl --xref_db_url <xref_db_url> --core_db_url <core_db_url> --otherf_db_url <otherf_db_url> --source_ids <source_ids [json]> --species_id <species_id> --species_name <species_name> --release <release>";
}

my $transcript_score_threshold = 0.75;
my $tl_transcript_score_threshold = 0.75;

# Extract the source ids
my $source_ids = decode_json($source_ids_json);

# Connect to the xref db
my ($user, $pass, $host, $port, $xref_db) = parse_url($xref_db_url);
my $dbi = get_dbi($host, $port, $user, $pass, $xref_db);

# Load the registry
my $registry = 'Bio::EnsEMBL::Registry';
my ($core_user, $core_pass, $core_host, $core_port, $core_dbname) = parse_url($core_db_url);
my ($otherf_user, $otherf_pass, $otherf_host, $otherf_port, $otherf_dbname) = parse_url($otherf_db_url);
$registry->load_registry_from_multiple_dbs(
  {
    -host => $core_host,
    -port => $core_port,
    -user => $core_user,
    -pass => $core_pass || '',
    -fb_version => $release
  },
  {
    -host => $otherf_host,
    -port => $otherf_port,
    -user => $otherf_user,
    -pass => $otherf_pass || '',
    -fb_version => $release
  },
);

# Get the EntrezGene and WikiGene accessions
my (%entrez_ids) = %{ get_valid_codes("EntrezGene", $species_id, $dbi) };
my (%wiki_ids)   = %{ get_valid_codes('WikiGene', $species_id, $dbi) };

# Prepare link sql
my $add_dependent_xref_sth = $dbi->prepare("INSERT INTO dependent_xref (master_xref_id, dependent_xref_id, linkage_source_id) VALUES (?,?,?)");

# Get the db adaptors
my $otherf_dba = $registry->get_DBAdaptor($species_name, 'otherfeatures');
my $core_dba = $otherf_dba->dnadb();

# Get the slice adaptors
my $otherf_sa = $otherf_dba->get_SliceAdaptor();
my $core_sa = $core_dba->get_SliceAdaptor();

# Fetch analysis object for refseq
my $logic_name;
my $otherf_aa = $otherf_dba->get_AnalysisAdaptor();
foreach my $analysis_adaptor (@{ $otherf_aa->fetch_all() }) {
  if ($analysis_adaptor->logic_name =~ /refseq_import/) {
    $logic_name = $analysis_adaptor->logic_name;
  }
}

# Not all species have refseq_import data, skip if not found
if (!defined $logic_name) {
  print STDERR "No data found for RefSeq_import, skipping import\n";;
  exit 1;
}

# Get otherfeatures chromosomes
my $otherf_chromosomes = $otherf_sa->fetch_all('toplevel', undef, 1);
foreach my $otherf_chromosome (@$otherf_chromosomes) {
  my $chr_name = $otherf_chromosome->seq_region_name();

  # Get otherfeatures genes
  my $otherf_genes = $otherf_chromosome->get_all_Genes($logic_name, undef, 1);
  while (my $otherf_gene = shift @$otherf_genes) {
    # Get otherfeatures transcripts
    my $otherf_transcripts = $otherf_gene->get_all_Transcripts();
    foreach my $otherf_transcript (sort { $a->start() <=> $b->start() } @$otherf_transcripts) {
      # Get the RefSeq accession (either the display xref or the stable ID)
      my $refseq_acc;
      if (defined $otherf_transcript->display_xref) {
        $refseq_acc = $otherf_transcript->display_xref->display_id;
      } elsif (defined $otherf_transcript->stable_id) {
        $refseq_acc = $otherf_transcript->stable_id;
      } else {
        # Skip non conventional accessions
        next;
      }
      next if (!defined($refseq_acc) || $refseq_acc !~ /^[NXMR]{2}_[0-9]+/);

      my (%transcript_result, %tl_transcript_result);
      my ($start, $end, $overlap);

      # Get otherfeatures exons
      my $otherf_exons = $otherf_transcript->get_all_Exons();
      my $otherf_tl_exons = $otherf_transcript->get_all_translateable_Exons();

      # Create a range registry for all the exons of the refseq transcript
      my $rr1 = Bio::EnsEMBL::Mapper::RangeRegistry->new();
      my $rr3 = Bio::EnsEMBL::Mapper::RangeRegistry->new();

      foreach my $otherf_exon (@$otherf_exons) {
        $start = $otherf_exon->seq_region_start();
        $end = $otherf_exon->seq_region_end();
        $rr1->check_and_register('exon', $start, $end);
      }

      foreach my $otherf_tl_exon (@$otherf_tl_exons) {
        $start = $otherf_tl_exon->seq_region_start();
        $end = $otherf_tl_exon->seq_region_end();
        $rr3->check_and_register('exon', $start, $end);
      }

      # Fetch slice in core database which overlaps refseq transcript
      my $core_chromosome = $core_sa->fetch_by_region('toplevel', $chr_name, $otherf_transcript->seq_region_start, $otherf_transcript->seq_region_end);

      # Get core transcripts
      my $core_transcripts = $core_chromosome->get_all_Transcripts(1);
      foreach my $core_transcript (@$core_transcripts) {
        next if ($core_transcript->strand != $otherf_transcript->strand);

        # Get core exons
        my $core_exons = $core_transcript->get_all_Exons();
        my $core_tl_exons = $core_transcript->get_all_translateable_Exons();

        # Create a range registry for all the exons of the ensembl transcript
        my $rr2 = Bio::EnsEMBL::Mapper::RangeRegistry->new();
        my $rr4 = Bio::EnsEMBL::Mapper::RangeRegistry->new();

        my ($core_exon_match, $core_tl_exon_match, $otherf_exon_match, $otherf_tl_exon_match) = (0, 0, 0, 0);

        foreach my $core_exon (@$core_exons) {
          $start = $core_exon->seq_region_start();
          $end = $core_exon->seq_region_end();
          $overlap = $rr1->overlap_size('exon', $start, $end);
          $core_exon_match += $overlap/($end - $start + 1);
          $rr2->check_and_register('exon', $start, $end);
        }

        foreach my $core_tl_exon (@$core_tl_exons) {
          $start = $core_tl_exon->seq_region_start();
          $end = $core_tl_exon->seq_region_end();
          $overlap = $rr3->overlap_size('exon', $start, $end);
          $core_tl_exon_match += $overlap/($end - $start + 1);
          $rr4->check_and_register('exon', $start, $end);
        }

        # Look for oeverlap between the two sets of exons
        foreach my $otherf_exon (@$otherf_exons) {
          $start = $otherf_exon->seq_region_start();
          $end = $otherf_exon->seq_region_end();
          $overlap = $rr2->overlap_size('exon', $start, $end);
          $otherf_exon_match += $overlap/($end - $start + 1);
        }

        foreach my $otherf_tl_exon (@$otherf_tl_exons) {
          $start = $otherf_tl_exon->seq_region_start();
          $end = $otherf_tl_exon->seq_region_end();
          $overlap = $rr4->overlap_size('exon', $start, $end);
          $otherf_tl_exon_match += $overlap/($end - $start + 1);
        }

        # Compare exon matching with number of exons to give a score
        my $score = ( ($otherf_exon_match + $core_exon_match)) / (scalar(@$otherf_exons) + scalar(@$core_exons) );
        my $tl_score = 0;
        if (scalar(@$otherf_tl_exons) > 0) {
          $tl_score = ( ($otherf_tl_exon_match + $core_tl_exon_match)) / (scalar(@$otherf_tl_exons) + scalar(@$core_tl_exons) );
        }
        if ($core_transcript->biotype eq $otherf_transcript->biotype) {
          $transcript_result{$core_transcript->stable_id} = $score;
          $tl_transcript_result{$core_transcript->stable_id} = $tl_score;
        } else {
          $transcript_result{$core_transcript->stable_id} = $score * 0.90;
          $tl_transcript_result{$core_transcript->stable_id} = $tl_score * 0.90;
        }
      }

      my ($best_score, $best_tl_score) = (0, 0);
      my ($best_id, $score, $tl_score);

      # Compare the scores based on coding exon overlap
      # If there is a stale mate, chose best exon overlap score
      foreach my $tid (sort { $transcript_result{$b} <=> $transcript_result{$a} } keys(%transcript_result)) {
        $score = $transcript_result{$tid};
        $tl_score = $tl_transcript_result{$tid};

        if ($score > $transcript_score_threshold || $tl_score > $tl_transcript_score_threshold) {
          if ($tl_score >= $best_tl_score) {
            if ($tl_score > $best_tl_score) {
              $best_id = $tid;
              $best_score = $score;
              $best_tl_score = $tl_score;
            } elsif ($tl_score == $best_tl_score) {
              if ($score > $best_score) {
                $best_id = $tid;
                $best_score = $score;
              }
            }
          }
          if (!defined $best_id) { 
            if ($score >= $best_score) {
              $best_id = $tid;
              $best_score = $score;
            }
          }
        }
      }

      # If a best match was defined for the refseq transcript, store it as direct xref for ensembl transcript
      if ($best_id) {
        my ($acc, $version) = split(/\./, $refseq_acc);
        $version =~ s/\D//g if $version;

        # Set the appropriate source ID
        my $source_id;
        $source_id = $source_ids->{'mrna'} if $acc =~ /^NM_/;
        $source_id = $source_ids->{'ncrna'} if $acc =~ /^NR_/;
        $source_id = $source_ids->{'mrna_predicted'} if $acc =~ /^XM_/;
        $source_id = $source_ids->{'ncrna_predicted'} if $acc =~ /^XR_/;
        next if (!defined($source_id));

        my $xref_id = add_xref({
          acc        => $acc,
          version    => $version,
          label      => $refseq_acc,
          desc       => undef,
          source_id  => $source_id,
          species_id => $species_id,
          dbi        => $dbi,
          info_type  => 'DIRECT'
        });
        add_direct_xref($xref_id, $best_id, "Transcript", "", $dbi);

        my $otherf_gene = $otherf_transcript->get_Gene();
        my $entrez_id = $otherf_gene->stable_id();
        my $otherf_translation = $otherf_transcript->translation();
        my $core_ta = $core_dba->get_TranscriptAdaptor();
        my $transcript = $core_ta->fetch_by_stable_id($best_id);
        my $translation = $transcript->translation();

        # Add link between Ensembl gene and EntrezGene (and WikiGene)
        if (defined $entrez_ids{$entrez_id} ) {
          foreach my $dependent_xref_id (@{$entrez_ids{$entrez_id}}) {
            $add_dependent_xref_sth->execute($xref_id, $dependent_xref_id, $source_ids->{'entrezgene'});
          }
          foreach my $dependent_xref_id (@{$wiki_ids{$entrez_id}}) {
            $add_dependent_xref_sth->execute($xref_id, $dependent_xref_id, $source_ids->{'wikigene'});
          }
        }

        # Also store refseq protein as direct xref for ensembl translation, if translation exists
        if (defined $translation && defined $otherf_translation && ($otherf_translation->seq eq $translation->seq)) {
          my $translation_id = $otherf_translation->stable_id();
          my @xrefs = grep {$_->{dbname} eq 'GenBank'} @{$otherf_translation->get_all_DBEntries};
          if (scalar @xrefs == 1) {
            $translation_id = $xrefs[0]->primary_id();
          }

          ($acc, $version) = split(/\./, $translation_id);

          $source_id = $source_ids->{'peptide'};
          $source_id = $source_ids->{'peptide_predicted'} if $acc =~ /^XP_/;
          my $tl_xref_id = add_xref({
            acc => $acc,
            version => $version,
            label => $translation_id,
            desc => undef,
            source_id => $source_id,
            species_id => $species_id,
            dbi => $dbi,
            info_type => 'DIRECT'
          });
          add_direct_xref($tl_xref_id, $translation->stable_id(), "Translation", "", $dbi);
        }
      }
    }
  }
}

sub parse_url {
  my ($url) = @_;

  my $parsed_url = Nextflow::Utils::parse($url);
  my $user = $parsed_url->{'user'};
  my $pass = $parsed_url->{'pass'};
  my $host = $parsed_url->{'host'};
  my $port = $parsed_url->{'port'};
  my $db   = $parsed_url->{'dbname'};

  return ($user, $pass, $host, $port, $db);
}

sub get_dbi {
  my ($host, $port, $user, $pass, $dbname) = @_;

  my $dbconn;
  if (defined $dbname) {
    $dbconn = sprintf("dbi:mysql:host=%s;port=%s;database=%s", $host, $port, $dbname);
  } else {
    $dbconn = sprintf("dbi:mysql:host=%s;port=%s", $host, $port);
  }
  my $dbi = DBI->connect( $dbconn, $user, $pass, { 'RaiseError' => 1 } ) or croak( "Can't connect to database: " . $DBI::errstr );

  return $dbi;
}

sub get_valid_codes{
  my ($source_name, $species_id, $dbi) = @_;

  my %valid_codes;
  my @sources;

  my $big_name = uc $source_name;
  my $sql = "select source_id from source where upper(name) like '%$big_name%'";
  my $sth = $dbi->prepare($sql);
  $sth->execute();
  while(my @row = $sth->fetchrow_array()){
    push @sources,$row[0];
  }
  $sth->finish;

  foreach my $source (@sources){
    $sql = "select accession, xref_id from xref where species_id = $species_id and source_id = $source";
    $sth = $dbi->prepare($sql);
    $sth->execute();
    while(my @row = $sth->fetchrow_array()){
      push @{$valid_codes{$row[0]}}, $row[1];
    }
  }
  $sth->finish();

  return \%valid_codes;
}

sub add_xref {
  my ($arg_ref) = @_;

  my $acc         = $arg_ref->{acc}        || croak 'add_xref needs aa acc';
  my $source_id   = $arg_ref->{source_id}  || croak 'add_xref needs a source_id';
  my $species_id  = $arg_ref->{species_id} || croak 'add_xref needs a species_id';
  my $label       = $arg_ref->{label}      // $acc;
  my $description = $arg_ref->{desc};
  my $version     = $arg_ref->{version}    // 0;
  my $info_type   = $arg_ref->{info_type}  // 'MISC';
  my $info_text   = $arg_ref->{info_text}  // q{};
  my $dbi         = $arg_ref->{dbi};

  # See if it already exists. If so return the existing xref_id
  my $xref_id;
  my $get_xref_sth = $dbi->prepare('SELECT xref_id FROM xref WHERE accession = ? AND source_id = ? AND species_id = ?');
  $get_xref_sth->execute($acc, $source_id, $species_id) or croak( $dbi->errstr() );
  if (my @row = $get_xref_sth->fetchrow_array()) {
    $xref_id = $row[0];
  }
  $get_xref_sth->finish();

  if(defined $xref_id){
    return $xref_id;
  }

  my $add_xref_sth = $dbi->prepare('INSERT INTO xref (accession,version,label,description,source_id,species_id, info_type, info_text) VALUES(?,?,?,?,?,?,?,?)');

  # If the description is more than 255 characters, chop it off
  if (defined $description && ((length $description) > 255 )) {
    my $truncmsg = ' /.../';
    substr $description, 255 - (length $truncmsg), length $truncmsg, $truncmsg;
  }

  # Add the xref and croak if it fails
  $add_xref_sth->execute($acc, $version || 0, $label, $description, $source_id, $species_id, $info_type, $info_text) 
    or croak("$acc\t$label\t\t$source_id\t$species_id\n");

  $add_xref_sth->finish();

  return $add_xref_sth->{'mysql_insertid'};
}

sub add_direct_xref {
  my ($general_xref_id, $ensembl_stable_id, $ensembl_type, $linkage_type, $dbi) = @_;

  # Check if such a mapping exists yet
  my @existing_xref_ids = get_direct_xref($ensembl_stable_id, $ensembl_type, $linkage_type, $dbi);
  if (scalar grep { $_ == $general_xref_id } @existing_xref_ids) {
    return;
  }

  $ensembl_type = lc($ensembl_type);
  my $add_direct_xref_sth = $dbi->prepare('INSERT INTO ' . $ensembl_type . '_direct_xref VALUES (?,?,?)');

  $add_direct_xref_sth->execute($general_xref_id, $ensembl_stable_id, $linkage_type);
  $add_direct_xref_sth->finish();

  return;
}

sub get_direct_xref{
  my ($stable_id, $type, $link, $dbi) = @_;

  $type = lc $type;

  my $sql = "SELECT general_xref_id FROM ${type}_direct_xref d WHERE ensembl_stable_id = ? AND linkage_xref";
  my @sql_params = ( $stable_id );
  if (defined $link) {
    $sql .= '= ?';
    push @sql_params, $link;
  } else {
    $sql .= 'is null';
  }
  my $direct_sth = $dbi->prepare($sql);

  $direct_sth->execute( @sql_params ) || croak( $dbi->errstr() );
  if (wantarray ()) {
    # Generic behaviour
    my @results;

    my $all_rows = $direct_sth->fetchall_arrayref();
    foreach my $row_ref ( @{ $all_rows } ) {
      push @results, $row_ref->[0];
    }

    return @results;
  } else {
    # Backwards-compatible behaviour
    if (my @row = $direct_sth->fetchrow_array()) {
      return $row[0];
    }
  }
  $direct_sth->finish();

  return;
}