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
use Text::CSV;
use DBI qw(:sql_types);
use JSON;
use Getopt::Long;
use File::Spec::Functions qw(catfile);

use Nextflow::Utils;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Mapper::RangeRegistry;

my ($xref_db_url, $core_db_url, $species_id, $output_dir, $analysis_id);
GetOptions(
  'xref_db_url=s' => \$xref_db_url,
  'core_db_url=s' => \$core_db_url,
  'species_id=i'  => \$species_id,
  'output_dir=s'  => \$output_dir,
  'analysis_id=i' => \$analysis_id
);

# Check that all parameters are passed
foreach my $param ($xref_db_url, $core_db_url, $species_id, $output_dir, $analysis_id) {
  defined $param or croak "Usage: dump_ensembl.pl --xref_db_url <xref_db_url> --core_db_url <core_db_url> --species_id <species_id> --output_dir <output_dir> --analysis_id <analysis_id>";
}

# Initialize the weights for the matching algorithm
my $ens_weight = 3;
my $coding_weight = 2;
my $transcript_score_threshold = 0.75;

# Set the files to use
my $xref_filename = catfile($output_dir, 'xref_coord.txt');
my $object_xref_filename = catfile($output_dir, 'object_xref_coord.txt');
my $unmapped_reason_filename = catfile($output_dir, 'unmapped_reason_coord.txt');
my $unmapped_object_filename = catfile($output_dir, 'unmapped_object_coord.txt');

# Connect to dbs
my ($core_host, $core_port, $core_user, $core_pass, $core_dbname) = parse_url($core_db_url);
my $core_dbi = get_dbi($core_host, $core_port, $core_user, $core_pass, $core_dbname);
my $xref_dbi = get_dbi(parse_url($xref_db_url));

# Figure out the last used IDs in the core DB
my $xref_id = $core_dbi->selectrow_array('SELECT MAX(xref_id) FROM xref') || 0;
my $object_xref_id = $core_dbi->selectrow_array('SELECT MAX(object_xref_id) FROM object_xref') || 0;
my $unmapped_object_id = $core_dbi->selectrow_array('SELECT MAX(unmapped_object_id) FROM unmapped_object') || 0;
my $unmapped_reason_id = $core_dbi->selectrow_array('SELECT MAX(unmapped_reason_id) FROM unmapped_reason') || 0;

my (%unmapped, %mapped);
my $external_db_id;

# Read and store available Xrefs from the Xref database
my $xref_sth = $xref_dbi->prepare("SELECT c.coord_xref_id, s.name, c.accession FROM coordinate_xref c JOIN source s ON c.source_id = s.source_id WHERE c.species_id = ?");
$xref_sth->bind_param(1, $species_id, SQL_INTEGER);
$xref_sth->execute();

while (my $xref = $xref_sth->fetchrow_hashref()) {
  my $sth_external_db = $core_dbi->prepare('SELECT external_db_id FROM external_db WHERE db_name = ?');
  $sth_external_db->execute($xref->{'name'});
  $external_db_id ||= ($sth_external_db->fetchrow_array())[0];
  $sth_external_db->finish();
  $external_db_id ||= 11000;    # FIXME (11000 is 'UCSC')

  $unmapped{$xref->{'coord_xref_id'}} = {
    'external_db_id' => $external_db_id,
    'accession'      => $xref->{'accession'},
    'reason'         => 'No overlap',
    'reason_full'    => 'No coordinate overlap with any Ensembl transcript'
  };
}
$xref_sth->finish();

defined $external_db_id or die "External_db_id is undefined for species_id = $species_id\n";

# Start the coordinate matching
my $core_db_adaptor = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
  -host   => $core_host,
  -port   => $core_port,
  -user   => $core_user,
  -pass   => $core_pass,
  -dbname => $core_dbname,
);

my $slice_adaptor = $core_db_adaptor->get_SliceAdaptor();
my @chromosomes   = @{ $slice_adaptor->fetch_all('Chromosome') };

my $sql = qq(
  SELECT    coord_xref_id, accession,
            txStart, txEnd,
            cdsStart, cdsEnd,
            exonStarts, exonEnds
  FROM      coordinate_xref
  WHERE     species_id = ?
  AND       chromosome = ? AND strand   = ?
  AND       ((txStart BETWEEN ? AND ?)        -- txStart in region
  OR         (txEnd   BETWEEN ? AND ?)        -- txEnd in region
  OR         (txStart <= ? AND txEnd >= ?))   -- region is fully contained
  ORDER BY  accession
);

foreach my $chromosome (@chromosomes) {
  my $chr_name = $chromosome->seq_region_name();
  my @genes = @{ $chromosome->get_all_Genes( undef, undef, 1 ) };

  foreach my $gene (@genes) {
    my @transcripts = @{ $gene->get_all_Transcripts() };
    my %gene_result;

    foreach my $transcript (sort { $a->start() <=> $b->start() } @transcripts) {
      ################################################################
      # For each Ensembl transcript:                                 #
      #   1. Register all Ensembl exons in a RangeRegistry.          #
      #                                                              #
      #   2. Find all transcripts in the external database that are  #
      #      within the range of this Ensembl transcript.            #
      #                                                              #
      # For each of those external transcripts:                      #
      #   3. Calculate the overlap of the exons of the external      #
      #      transcript with the Ensembl exons using the             #
      #      overlap_size() method in the RangeRegistry.             #
      #                                                              #
      #   4. Register the external exons in their own RangeRegistry. #
      #                                                              #
      #   5. Calculate the overlap of the Ensembl exons with the     #
      #      external exons as in step 3.                            #
      #                                                              #
      #   6. Calculate the match score.                              #
      #                                                              #
      #   7. Decide whether or not to keep the match.                #
      ################################################################

      my @exons = @{ $transcript->get_all_Exons() };
      my %transcript_result;

      # '$rr1' is the RangeRegistry holding Ensembl exons for one transcript at a time.
      my $rr1 = Bio::EnsEMBL::Mapper::RangeRegistry->new();

      my $coding_transcript = defined($transcript->translation()) ? 1 : 0;

      foreach my $exon (@exons) {
        # Register each exon in the RangeRegistry.  Register both the
        # total length of the exon and the coding range of the exon.
        $rr1->check_and_register('exon', $exon->start(), $exon->end());

        if ($coding_transcript
          && defined($exon->coding_region_start($transcript))
          && defined($exon->coding_region_end($transcript) ))
        {
          $rr1->check_and_register('coding', $exon->coding_region_start($transcript), $exon->coding_region_end($transcript));
        }
      }

      # Get hold of all transcripts from the external database that
      # overlaps with this Ensembl transcript.

      my $sth = $xref_dbi->prepare_cached($sql);
      $sth->bind_param(1, $species_id,          SQL_INTEGER);
      $sth->bind_param(2, $chr_name,            SQL_VARCHAR);
      $sth->bind_param(3, $gene->strand(),      SQL_INTEGER);
      $sth->bind_param(4, $transcript->start(), SQL_INTEGER);
      $sth->bind_param(5, $transcript->end(),   SQL_INTEGER);
      $sth->bind_param(6, $transcript->start(), SQL_INTEGER);
      $sth->bind_param(7, $transcript->end(),   SQL_INTEGER);
      $sth->bind_param(8, $transcript->start(), SQL_INTEGER);
      $sth->bind_param(9, $transcript->end(),   SQL_INTEGER);
      $sth->execute();

      my ($coord_xref_id, $accession, $txStart, $txEnd, $cdsStart, $cdsEnd, $exonStarts, $exonEnds);

      $sth->bind_columns(\($coord_xref_id, $accession, $txStart, $txEnd, $cdsStart, $cdsEnd, $exonStarts, $exonEnds));

      while ($sth->fetch()) {
        my @exonStarts = split(/,\s*/, $exonStarts);
        my @exonEnds   = split(/,\s*/, $exonEnds);
        my $exonCount = scalar(@exonStarts);

        # '$rr2' is the RangeRegistry holding exons from the external
        # transcript, for one transcript at a time.
        my $rr2 = Bio::EnsEMBL::Mapper::RangeRegistry->new();

        my $exon_match   = 0;
        my $coding_match = 0;
        my $coding_count = 0;

        for (my $i = 0 ; $i < $exonCount ; ++$i) {
          # Register the exons from the external database in the same
          # way as with the Ensembl exons, and calculate the overlap
          # of the external exons with the previously registered
          # Ensembl exons.

          my $overlap = $rr1->overlap_size('exon', $exonStarts[$i], $exonEnds[$i]);
          $exon_match += $overlap/($exonEnds[$i] - $exonStarts[$i] + 1);
          $rr2->check_and_register('exon', $exonStarts[$i], $exonEnds[$i]);

          if (defined($cdsStart) && defined($cdsEnd)) {
            my $codingStart = ($exonStarts[$i] > $cdsStart ? $exonStarts[$i] : $cdsStart);
            my $codingEnd = ($exonEnds[$i] < $cdsEnd ? $exonEnds[$i] : $cdsEnd);

            if ($codingStart < $codingEnd) {
              my $coding_overlap = $rr1->overlap_size('coding', $codingStart, $codingEnd);
              $coding_match += $coding_overlap/($codingEnd - $codingStart + 1);
              $rr2->check_and_register('coding', $codingStart, $codingEnd);

              ++$coding_count;
            }
          }
        }

        my $rexon_match   = 0;
        my $rcoding_match = 0;
        my $rcoding_count = 0;

        foreach my $exon (@exons) {
          # Calculate the overlap of the Ensembl exons with the
          # external exons.

          my $overlap = $rr2->overlap_size('exon', $exon->start(), $exon->end());
          $rexon_match += $overlap/($exon->end() - $exon->start() + 1);

          if ($coding_transcript
            && defined($exon->coding_region_start($transcript))
            && defined($exon->coding_region_end($transcript) ))
          {
            my $coding_overlap = $rr2->overlap_size('coding', $exon->coding_region_start($transcript), $exon->coding_region_end($transcript));

            $rcoding_match += $coding_overlap/($exon->coding_region_end($transcript) - $exon->coding_region_start($transcript) + 1);

            ++$rcoding_count;
          }
        }

        # Calculate the match score.
        my $score = (
          ($exon_match + $ens_weight*$rexon_match) +
          $coding_weight*($coding_match + $ens_weight*$rcoding_match)
        )/
        (
          ($exonCount + $ens_weight*scalar(@exons)) +
          $coding_weight*($coding_count + $ens_weight*$rcoding_count)
        );

        if (!defined($transcript_result{$coord_xref_id}) || $transcript_result{$coord_xref_id} < $score) {
          $transcript_result{$coord_xref_id} = $score;
        }

      }
      $sth->finish();

      # Apply transcript threshold and pick the best match(es) for
      # this transcript.

      my $best_score;
      foreach my $coord_xref_id (sort { $transcript_result{$b} <=> $transcript_result{$a} } keys(%transcript_result)) {
        my $score = $transcript_result{$coord_xref_id};

        if ($score > $transcript_score_threshold) {
          $best_score ||= $score;

          if (sprintf("%.3f", $score) eq sprintf("%.3f", $best_score)) {
            if (exists($unmapped{$coord_xref_id})) {
              $mapped{$coord_xref_id} = $unmapped{$coord_xref_id};
              delete($unmapped{$coord_xref_id});
              $mapped{$coord_xref_id}{'reason'}      = undef;
              $mapped{$coord_xref_id}{'reason_full'} = undef;
              $mapped{$coord_xref_id}{'chr_name'} = $chr_name;
            }

            push(@{ $mapped{$coord_xref_id}{'mapped_to'}}, {
              'ensembl_id'          => $transcript->dbID(),
              'ensembl_object_type' => 'Transcript'
            });

            # This is now a candidate Xref for the gene.
            if (!defined($gene_result{$coord_xref_id}) || $gene_result{$coord_xref_id} < $score) {
              $gene_result{$coord_xref_id} = $score;
            }
          } elsif (exists($unmapped{$coord_xref_id})) {
            $unmapped{$coord_xref_id}{'reason'} = 'Was not best match';
            $unmapped{$coord_xref_id}{'reason_full'} = sprintf("Did not top best transcript match score (%.2f)", $best_score);
            if (!defined($unmapped{$coord_xref_id}{'score'}) || $score > $unmapped{$coord_xref_id}{'score'}) {
              $unmapped{$coord_xref_id}{'score'} = $score;
              $unmapped{$coord_xref_id}{'ensembl_id'} = $transcript->dbID();
            }
          }
        } elsif (exists($unmapped{$coord_xref_id}) && $unmapped{$coord_xref_id}{'reason'} ne 'Was not best match') {
          $unmapped{$coord_xref_id}{'reason'} = 'Did not meet threshold';
          $unmapped{$coord_xref_id}{'reason_full'} = sprintf("Match score for transcript lower than threshold (%.2f)", $transcript_score_threshold);
          if (!defined($unmapped{$coord_xref_id}{'score'}) || $score > $unmapped{$coord_xref_id}{'score'}) {
            $unmapped{$coord_xref_id}{'score'} = $score;
            $unmapped{$coord_xref_id}{'ensembl_id'} = $transcript->dbID();
          }
        }
      }
    }
  }
}

# Ensure we have a db connection
unless ($core_dbi->ping) {
  $core_dbi = get_dbi($core_host, $core_port, $core_user, $core_pass, $core_dbname); 
}

# Make all dumps.  Order is important.
dump_xref($xref_filename, $xref_id, \%mapped, \%unmapped);
dump_object_xref($object_xref_filename, $object_xref_id, $analysis_id, \%mapped);
dump_unmapped_reason($unmapped_reason_filename, $unmapped_reason_id, \%unmapped, $core_dbi);
dump_unmapped_object($unmapped_object_filename, $unmapped_object_id, $analysis_id, \%unmapped);

# Ensure we have a db connection, again
unless ($core_dbi->ping) {
  $core_dbi = get_dbi($core_host, $core_port, $core_user, $core_pass, $core_dbname); 
}

# Upload the dumps. Order is important.
upload_data('unmapped_reason', $unmapped_reason_filename, $external_db_id, $core_dbi);
upload_data('unmapped_object', $unmapped_object_filename, $external_db_id, $core_dbi);
upload_data('object_xref', $object_xref_filename, $external_db_id, $core_dbi);
upload_data('xref', $xref_filename, $external_db_id, $core_dbi);

sub parse_url {
  my ($url) = @_;
  my $parsed_url = Nextflow::Utils::parse($url);
  return @{$parsed_url}{qw(host port user pass dbname)};
}

sub get_dbi {
  my ($host, $port, $user, $pass, $dbname) = @_;
  my $dbconn = defined $dbname ? sprintf("dbi:mysql:host=%s;port=%s;database=%s", $host, $port, $dbname) : sprintf("dbi:mysql:host=%s;port=%s", $host, $port);
  my $dbi = DBI->connect($dbconn, $user, $pass, { 'RaiseError' => 1, 'mysql_auto_reconnect' => 1 }) or croak("Can't connect to database: " . $DBI::errstr);
  return $dbi;
}

sub dump_xref {
  my ($filename, $xref_id, $mapped, $unmapped) = @_;

  my $fh = IO::File->new($filename, 'w') or croak(sprintf("Can not open '%s' for writing", $filename));

  foreach my $xref (values(%{$unmapped}), values(%{$mapped})) {
    # Assign 'xref_id' to this Xref.
    $xref->{'xref_id'} = ++$xref_id;

    my $accession = $xref->{'accession'};
    my ($version) = ($accession =~ /\.(\d+)$/);
    $version ||= 0;

    my $info_text = (defined($xref->{'chr_name'}) && $xref->{'chr_name'} eq 'Y' ? "Y Chromosome" : "");

    $fh->printf("%d\t%d\t%s\t%s\t%d\t%s\t%s\t%s\n",
      $xref->{'xref_id'},
      $xref->{'external_db_id'},
      $accession,
      $accession,
      $version,
      '\N',
      'COORDINATE_OVERLAP',
      $info_text
    );
  }
  $fh->close();
}

sub dump_object_xref {
  my ($filename, $object_xref_id, $analysis_id, $mapped) = @_;

  my $fh = IO::File->new($filename, 'w') or croak(sprintf("Can not open '%s' for writing", $filename));

  foreach my $xref (values(%{$mapped})) {
    foreach my $object_xref (@{ $xref->{'mapped_to'} }) {
      # Assign 'object_xref_id' to this Object Xref.
      $object_xref->{'object_xref_id'} = ++$object_xref_id;

      $fh->printf("%d\t%d\t%s\t%d\t%s\t%s\n",
        $object_xref->{'object_xref_id'},
        $object_xref->{'ensembl_id'},
        $object_xref->{'ensembl_object_type'},
        $xref->{'xref_id'},
        '\N',
        $analysis_id
      );
    }
  }
  $fh->close();
}

sub dump_unmapped_reason {
  my ($filename, $unmapped_reason_id, $unmapped, $core_dbi) = @_;

  # Create a list of the unique reasons.
  my %reasons;

  foreach my $xref (values(%{$unmapped})) {
    if (!exists($reasons{$xref->{'reason_full'}})) {
      $reasons{$xref->{'reason_full'}} = {
        'summary' => $xref->{'reason'},
        'full' => $xref->{'reason_full'}
      };
    }
  }

  my $fh = IO::File->new($filename, 'w') or croak(sprintf("Can not open '%s' for writing", $filename));

  my $sth = $core_dbi->prepare('SELECT unmapped_reason_id FROM unmapped_reason WHERE full_description = ?');

  foreach my $reason (sort({ $a->{'full'} cmp $b->{'full'} } values(%reasons))) {
    # Figure out 'unmapped_reason_id' from the core database.
    $sth->bind_param(1, $reason->{'full'}, SQL_VARCHAR);
    $sth->execute();

    my $id;
    $sth->bind_col(1, \$id);
    $sth->fetch();

    if (defined($id)) {
      $reason->{'unmapped_reason_id'} = $id;
    } else {
      $reason->{'unmapped_reason_id'} = ++$unmapped_reason_id;
    }

    $sth->finish();

    $fh->printf("%d\t%s\t%s\n",
      $reason->{'unmapped_reason_id'},
      $reason->{'summary'},
      $reason->{'full'}
    );

  }
  $fh->close();

  # Assign reasons to the unmapped Xrefs from %reasons.
  foreach my $xref (values(%{$unmapped})) {
    $xref->{'reason'}      = $reasons{$xref->{'reason_full'}};
    $xref->{'reason_full'} = undef;
  }
}

sub dump_unmapped_object {
  my ($filename, $unmapped_object_id, $analysis_id, $unmapped) = @_;

  my $fh = IO::File->new($filename, 'w') or croak(sprintf("Can not open '%s' for writing", $filename));

  foreach my $xref (values(%{$unmapped})) {
    # Assign 'unmapped_object_id' to this Xref.
    $xref->{'unmapped_object_id'} = ++$unmapped_object_id;

    $fh->printf(
      "%d\t%s\t%s\t%d\t%s\t%d\t%s\t%s\t%s\t%s\t%s\n",
      $xref->{'unmapped_object_id'},
      'xref',
      $analysis_id || '\N',    # '\N' (NULL) means no analysis exists and uploading this table will fail.
      $xref->{'external_db_id'},
      $xref->{'accession'},
      $xref->{'reason'}->{'unmapped_reason_id'},
      (defined($xref->{'score'}) ? sprintf("%.3f", $xref->{'score'}) : '\N'),
      '\N',
      $xref->{'ensembl_id'} || '\N',
      (defined($xref->{'ensembl_id'}) ? 'Transcript' : '\N'),
      '\N'
    );
  }
  $fh->close();
}

sub upload_data {
  my ($table_name, $filename, $external_db_id, $dbi) = @_;

  if (!-r $filename) {
    croak(sprintf("Can not open '%s' for reading", $filename));
  }

  my $cleanup_sql = '';
  my $extra_sql = '';
  my @columns;
  if ($table_name eq 'unmapped_reason') {
    $cleanup_sql = qq(
      DELETE  ur
      FROM    unmapped_object uo,
              unmapped_reason ur
      WHERE   uo.external_db_id       = ?
      AND     ur.unmapped_reason_id   = uo.unmapped_reason_id
    );

    @columns = ('unmapped_reason_id', 'summary_description', 'full_description');
    $extra_sql = "ON DUPLICATE KEY UPDATE summary_description=?, full_description=?";
  } elsif ($table_name eq 'unmapped_object') {
    $cleanup_sql = qq(
      DELETE  uo
      FROM    unmapped_object uo
      WHERE   uo.external_db_id = ?
    );

    @columns = ('unmapped_object_id', 'type', 'analysis_id', 'external_db_id', 'identifier', 'unmapped_reason_id', 'query_score', 'target_score', 'ensembl_id', 'ensembl_object_type', 'parent');
  } elsif ($table_name eq 'object_xref') {
    $cleanup_sql = qq(
      DELETE  ox
      FROM    xref x,
              object_xref ox
      WHERE   x.external_db_id    = ?
      AND     ox.xref_id          = x.xref_id
    );

    @columns = ('object_xref_id', 'ensembl_id', 'ensembl_object_type', 'xref_id', 'linkage_annotation', 'analysis_id');
    $extra_sql = "ON DUPLICATE KEY UPDATE analysis_id=?";
  } elsif ($table_name eq 'xref') {
    $cleanup_sql = qq(
      DELETE  x
      FROM    xref x
      WHERE   x.external_db_id    = ?
    );

    @columns = ('xref_id', 'external_db_id', 'dbprimary_acc', 'display_label', 'version', 'description', 'info_type', 'info_text');
  } else {
    croak(sprintf("Table '%s' is unknown\n", $table_name));
  }

  # Cleanup existing data
  my $rows = $dbi->do($cleanup_sql, undef, $external_db_id) or croak($dbi->errstr());

  # Open the file for reading
  my $csv = Text::CSV->new({
    sep_char => "\t"
  }) || confess 'Failed to initialise CSV parser: ' . Text::CSV->error_diag();
  my $file_io = IO::File->new($filename, 'r') or croak(sprintf("Can not open '%s' for reading", $filename));
  $csv->column_names(@columns);

  # Prepare the query for insertion
  my $placeholders = join(',', ('?') x scalar(@columns));
  my $sql = "INSERT INTO $table_name (" . join(',', @columns) . ") VALUES ($placeholders) $extra_sql";
  my $load_sth = $dbi->prepare($sql);

  # Load data
  while (defined(my $line = $csv->getline($file_io))) {
    # Handle "\N" and convert it to undef (NULL in DB)
    for my $i (0..$#$line) {
      $line->[$i] = undef if $line->[$i] eq '\\N';
    }

    if ($table_name eq 'unmapped_reason') {
      $load_sth->execute(@$line, $line->[1], $line->[2]) or die "Failed to insert line: " . $load_sth->errstr;
    } elsif ($table_name eq 'object_xref') {
      $load_sth->execute(@$line, $line->[5]) or die "Failed to insert line: " . $load_sth->errstr;
    } else {
      $load_sth->execute(@$line) or die "Failed to insert line: " . $load_sth->errstr;
    }
  }
  $file_io->close();
  $load_sth->finish();

  # Optimize the table
  $dbi->do("OPTIMIZE TABLE $table_name") or croak($dbi->errstr());
}
