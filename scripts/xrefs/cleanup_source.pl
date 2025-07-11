#!/usr/bin/env perl
#  Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
#  Copyright [2016-2025] EMBL-European Bioinformatics Institute
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
use Getopt::Long;
use Carp;
use DBI;
use File::Path qw/make_path/;
use File::Spec::Functions;

use Nextflow::Utils;

my ($base_path, $source_db_url, $source_name, $clean_dir, $skip_download, $clean_files, $version_file, $log_timestamp);
GetOptions(
  'base_path=s'     => \$base_path,
  'source_db_url=s' => \$source_db_url,
  'name=s'          => \$source_name,
  'clean_dir=s'     => \$clean_dir,
  'skip_download=i' => \$skip_download,
  'clean_files=i'   => \$clean_files,
  'version_file:s'  => \$version_file,
  'log_timestamp:s' => \$log_timestamp
);

# Check that all mandatory parameters are passed
if (!defined($base_path) || !defined($source_db_url) || !defined($source_name) || !defined($clean_dir) || !defined($skip_download) || !defined($clean_files)) {
  croak "Usage: cleanup_source.pl --base_path <base_path> --source_db_url <source_db_url> --name <name> --clean_dir <clean_dir> --skip_download <skip_download> --clean_files <clean_files> [--version_file <version_file>] [--log_timestamp <log_timestamp>]";
}

my $log_file;
if (defined($log_timestamp)) {
  my $log_path = catdir($base_path, 'logs', $log_timestamp);
  make_path($log_path);
  $log_file = catfile($log_path, "tmp_logfile_CleanupSource_".int(rand(500)));

  add_to_log_file($log_file, "CleanupSource starting for source $source_name");
}

# Do nothing if not cleaning files, not a uniprot or refseq source, or no new download
if ($clean_files && ($source_name =~ /^Uniprot/ || $source_name =~ /^RefSeq_/)) {
  # Remove last '/' character if it exists
  if ($base_path =~ /\/$/) {chop($base_path);}

  # Remove / char from source name to access directory
  my $clean_name = $source_name;
  $clean_name =~ s/\///g;

  my $output_path = $clean_dir."/".$clean_name;
  my $update_clean_uri = 0;

  # If not a new download, check if clean files exist
  if ($skip_download) {
    if (-d $output_path) {
      $update_clean_uri = 1
    }
  } else {
    # Create needed directories
    make_path($output_path);

    $update_clean_uri = 1;

    my $sources_to_remove;
    my ($is_uniprot, $is_refseq_dna, $is_refseq_peptide) = (0, 0, 0);
    my $file_size = 0;

    # Set sources to skip in parsing step (uniprot only)
    if ($source_name =~ /^Uniprot/) {
      $is_uniprot = 1;
      my @source_names = (
        'GO', 'UniGene', 'RGD', 'CCDS', 'IPI', 'UCSC', 'SGD', 'HGNC', 'MGI', 'VGNC', 'Orphanet',
        'ArrayExpress', 'GenomeRNAi', 'EPD', 'Xenbase', 'Reactome', 'MIM_GENE', 'MIM_MORBID', 'MIM',
        'Interpro'
      );
      $sources_to_remove = join("|", @source_names);
      $file_size = 200000;
    } elsif ($source_name =~ /^RefSeq_dna/) {
      $is_refseq_dna = 1;
    } elsif ($source_name =~ /^RefSeq_peptide/) {
      $is_refseq_peptide = 1;
    } else {
      croak "Unknown file type $source_name";
    }

    # Get all files for source
    my $files_path = $base_path."/".$clean_name;
    my @files = `ls $files_path`;
    foreach my $file_name (@files) {
      $file_name =~ s/\n//;
      my $file = $files_path."/".$file_name;

      # Skip the release file
      if (defined($version_file) && $file eq $version_file) {next;}

      my ($in_fh, $out_fh);
      my $output_file = $file_name;

      # Open file normally or with zcat for zipped filed
      if ($file_name =~ /\.(gz|Z)$/x) {
        open($in_fh, "zcat $file |")
          or die "Couldn't call 'zcat' to open input file '$file' $!";

        $output_file =~ s/\.[^.]+$//;
      } else {
        open($in_fh, '<', $file)
          or die "Couldn't open file input '$file' $!";
      }

      # Only start cleaning up if could get filehandle
      my $count = 0;
      my $file_count = 1;
      if (defined($in_fh)) {
        if ($is_uniprot) {
          local $/ = "//\n";

          my $write_file = $output_path."/".$output_file . "-$file_count";
          open($out_fh, '>', $write_file) or die "Couldn't open output file '$write_file' $!";

          # Read full records
          while ($_ = $in_fh->getline()) {
            # Remove unused data
            $_ =~ s/\nR(N|P|X|A|T|R|L|C|G)\s{3}.*//g; # Remove references lines
            $_ =~ s/\nCC(\s{3}.*)CAUTION: The sequence shown here is derived from an Ensembl(.*)/\nCT$1CAUTION: The sequence shown here is derived from an Ensembl$2/g; # Set specific caution comment to temporary
            $_ =~ s/\nCC\s{3}.*//g; # Remove comments
            $_ =~ s/\nCT(\s{3}.*)CAUTION: The sequence shown here is derived from an Ensembl(.*)/\nCC$1CAUTION: The sequence shown here is derived from an Ensembl$2/g; # Set temp line back to comment
            $_ =~ s/\nFT\s{3}.*//g; # Remove feature coordinates
            $_ =~ s/\nDR\s{3}($sources_to_remove);.*//g; # Remove sources skipped at processing

            # Added lines that we do need into output
            print $out_fh $_;

            # Check how many lines have been processed and write to new file if size exceeded
            $count++;
            if ($count > $file_size) {
              close($out_fh);
              $file_count++;
              $write_file = $output_path."/".$output_file . "-$file_count";
              open($out_fh, '>', $write_file)
                or die "Couldn't open output file '$write_file' $!";
              $count = 0;
            }
          }

          close($in_fh);
          close($out_fh);
        } else {
          $output_file = $output_path."/".$output_file;
          open($out_fh, '>', $output_file) or die "Couldn't open output file '$output_file' $!";

          # Remove unuused data
          my $skip_data = 0;
          while (<$in_fh>) {
            if ($is_refseq_dna) {
              if ($_ =~ /^REFERENCE/ || $_ =~ /^COMMENT/ || $_ =~ /^\s{5}exon/ || $_ =~ /^\s{5}misc_feature/ || $_ =~ /^\s{5}variation/) {
                $skip_data = 1;
              } elsif ($_ =~ /^\s{5}source/ || $_ =~ /^ORIGIN/) {
                $skip_data = 0;
              }
            } elsif ($is_refseq_peptide) {
              if ($_ =~ /^REFERENCE/ || $_ =~ /^COMMENT/ || $_ =~ /^\s{5}Protein/) {
                $skip_data = 1;
              } elsif ($_ =~ /^\s{5}source/ || $_ =~ /^\s{5}CDS/ || $_ =~ /^ORIGIN/) {
                $skip_data = 0;
              }
            }

            if (!$skip_data) {print $out_fh $_;}
          }

          close($in_fh);
          close($out_fh);
        }
      }
    }

    add_to_log_file($log_file, "Source $source_name cleaned up");
  }

  # Save the clean files directory in source db
  if ($update_clean_uri) {
    my ($user, $pass, $host, $port, $source_db) = parse_url($source_db_url);
    my $dbi = get_dbi($host, $port, $user, $pass, $source_db);
    my $update_version_sth = $dbi->prepare("UPDATE IGNORE version set clean_uri=? where source_id=(SELECT source_id FROM source WHERE name=?)");
    $update_version_sth->execute($output_path, $source_name);
    $update_version_sth->finish();
  }
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

sub add_to_log_file {
  my ($log_file, $message) = @_;

  if (defined($log_file)) {
    my $current_timestamp = strftime "%d-%b-%Y %H:%M:%S", localtime;

    open(my $fh, '>>', $log_file);
    print $fh "$current_timestamp | INFO | $message\n";
    close($fh);
  }
}