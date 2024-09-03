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
use Getopt::Long;
use Carp;
use DBI;
use File::Path qw/make_path rmtree/;
use File::Spec::Functions;
use HTTP::Tiny;
use JSON;
use File::Basename;
use POSIX qw(strftime);

use Nextflow::Utils;

my ($base_path, $source_db_url, $source_name, $clean_dir, $clean_files, $version_file, $tax_ids_file, $update_mode, $log_timestamp);
GetOptions(
  'base_path=s'     => \$base_path,
  'source_db_url=s' => \$source_db_url,
  'name=s'          => \$source_name,
  'clean_dir=s'     => \$clean_dir,
  'clean_files=i'   => \$clean_files,
  'version_file:s'  => \$version_file,
  'tax_ids_file:s'  => \$tax_ids_file,
  'update_mode:i'   => \$update_mode,
  'log_timestamp:s' => \$log_timestamp
);

# Check that all mandatory parameters are passed
if (!defined($base_path) || !defined($source_db_url) || !defined($source_name) || !defined($clean_dir) || !defined($clean_files)) {
  croak "Usage: cleanup_source.pl --base_path <base_path> --source_db_url <source_db_url> --name <name> --clean_dir <clean_dir> --clean_files <clean_files> [--version_file <version_file>] [--tax_ids_file <tax_ids_file>] [--update_mode <update_mode>] [--log_timestamp <log_timestamp>]";
}

if (!defined($update_mode)) {$update_mode = 0;}

my $log_file;
if (defined($log_timestamp)) {
  my $log_path = catdir($base_path, 'logs', $log_timestamp);
  make_path($log_path);
  $log_file = catfile($log_path, "tmp_logfile_CleanupSplitSource_".int(rand(500)));

  add_to_log_file($log_file, "CleanupSplitSource starting for source $source_name");
  add_to_log_file($log_file, "Param: tax_ids_file = $tax_ids_file");
}

# Do nothing if not a uniprot or refseq source
if ($source_name !~ /^Uniprot/ && $source_name !~ /^RefSeq_/) {
  add_to_log_file($log_file, "Provided source name is invalid. Can only clean up and split Uniprot or RefSeq files.");
  exit;
}

# Remove last '/' character if it exists
if ($base_path =~ /\/$/) {chop($base_path);}

# Remove / char from source name to access directory
my $clean_name = $source_name;
$clean_name =~ s/\///g;

my $output_path = $clean_dir."/".$clean_name;

# Create needed directories
if (!$update_mode) {
  rmtree($output_path);
}
make_path($output_path);

my $sources_to_remove;
my ($is_uniprot, $is_refseq_dna, $is_refseq_peptide) = (0, 0, 0);

# Decide which files are being processed
my $output_file_name = '';
if ($source_name =~ /^Uniprot/) {
  $is_uniprot = 1;
  $output_file_name = ($source_name =~ /SPTREMBL/ ? 'uniprot_trembl' : 'uniprot_sprot');

  # Set sources to skip in parsing step
  my @source_names = (
    'GO', 'UniGene', 'RGD', 'CCDS', 'IPI', 'UCSC', 'SGD', 'HGNC', 'MGI', 'VGNC', 'Orphanet',
    'ArrayExpress', 'GenomeRNAi', 'EPD', 'Xenbase', 'Reactome', 'MIM_GENE', 'MIM_MORBID', 'MIM',
    'Interpro'
  );
  $sources_to_remove = join("|", @source_names);
} elsif ($source_name =~ /^RefSeq_dna/) {
  $is_refseq_dna = 1;
  $output_file_name = 'refseq_rna';
} elsif ($source_name =~ /^RefSeq_peptide/) {
  $is_refseq_peptide = 1;
  $output_file_name = 'refseq_protein';
} else {
  croak "Unknown file type $source_name";
}

# Extract taxonomy IDs
my %tax_ids;
my ($skipped_species, $added_species) = (0, 0);
if ($tax_ids_file && $update_mode) {
  open my $fh, '<', $tax_ids_file;
  chomp(my @lines = <$fh>);
  close $fh;
  %tax_ids = map { $_ => 1 } @lines;

  # Check if any taxonomy IDs already have files
  foreach my $tax_id (keys(%tax_ids)) {
    my @tax_files = glob($output_path . "/**/**/**/**/" . $output_file_name . "-" . $tax_id);
    if (scalar(@tax_files) > 0) {
      $tax_ids{$tax_id} = 0;
      $skipped_species++;
    }
  }

  # Do nothing if all taxonomy IDs already have files
  if ($skipped_species == scalar(keys(%tax_ids))) {
    add_to_log_file($log_file, "All provided tax IDs already have files. Doing nothing.");
    exit;
  }
}

# Get all files for source
my $files_path = $base_path."/".$clean_name;
my @files = glob($files_path."/*");
my $out_fh;
my $current_species_id;

# Process each file
foreach my $input_file_name (@files) {
  local $/ = "//\n";

  add_to_log_file($log_file, "Splitting up file $input_file_name");

  $input_file_name = basename($input_file_name);
  my $input_file = $files_path."/".$input_file_name;
  my $in_fh;

  # Skip the release file
  if (defined($version_file) && $input_file eq $version_file) {next;}

  # Open file normally or with zcat for zipped filed
  if ($input_file_name =~ /\.(gz|Z)$/x) {
    open($in_fh, "zcat $input_file |") or die "Couldn't call 'zcat' to open input file '$input_file' $!";
    $output_file_name =~ s/\.[^.]+$//;
  } else {
    open($in_fh, '<', $input_file) or die "Couldn't open file input '$input_file' $!";
  }

  # Only start processing if could get filehandle
  if (defined($in_fh)) {
    my ($write_path, $write_file);

    # Read full records
    while (my $record = $in_fh->getline()) {
      # Extract the species id from record
      my $species_id;
      if ($is_uniprot) {
        ($species_id) = $record =~ /OX\s+[a-zA-Z_]+=([0-9 ,]+).*;/;
        $species_id =~ s/\s// if $species_id;
      } else {
        ($species_id) = $record =~ /db_xref=.taxon:(\d+)/;
      }

      # Only continue with wanted species
      next if (!$species_id);
      next if ($tax_ids_file && (!defined($tax_ids{$species_id}) || !$tax_ids{$species_id}));

      # Clean up data
      if ($clean_files) {
        if ($is_uniprot) {
          $record =~ s/\nR(N|P|X|A|T|R|L|C|G)\s{3}.*//g; # Remove references lines
          $record =~ s/\nCC(\s{3}.*)CAUTION: The sequence shown here is derived from an Ensembl(.*)/\nCT$1CAUTION: The sequence shown here is derived from an Ensembl$2/g; # Set specific caution comment to temporary
          $record =~ s/\nCC\s{3}.*//g; # Remove comments
          $record =~ s/\nCT(\s{3}.*)CAUTION: The sequence shown here is derived from an Ensembl(.*)/\nCC$1CAUTION: The sequence shown here is derived from an Ensembl$2/g; # Set temp line back to comment
          $record =~ s/\nFT\s{3}.*//g; # Remove feature coordinates
          $record =~ s/\nDR\s{3}($sources_to_remove);.*//g; # Remove sources skipped at processing
        } else {
          my $skip_data = 0;
          my @lines = split("\n", $record);
          my @new_record;

          for my $line (@lines) {
            if ($is_refseq_dna) {
              if ($line =~ /^REFERENCE/ || $line =~ /^COMMENT/ || $line =~ /^\s{5}exon/ || $line =~ /^\s{5}misc_feature/ || $line =~ /^\s{5}variation/) {
                $skip_data = 1;
              } elsif ($line =~ /^\s{5}source/ || $line =~ /^ORIGIN/) {
                $skip_data = 0;
              }
            } elsif ($is_refseq_peptide) {
              if ($line =~ /^REFERENCE/ || $line =~ /^COMMENT/ || $line =~ /^\s{5}Protein/) {
                $skip_data = 1;
              } elsif ($line =~ /^\s{5}source/ || $line =~ /^\s{5}CDS/ || $line =~ /^ORIGIN/) {
                $skip_data = 0;
              }
            }

            if (!$skip_data) {
              push(@new_record, $line);
            }

            $record = join("\n", @new_record);
          }
        }
      }

      # Write the record in the appropriate file
      if (!defined($current_species_id) || (defined($current_species_id) && $species_id ne $current_species_id)) {
        close($out_fh) if (defined($current_species_id));

        my $species_id_str = sprintf("%04d", $species_id);
        my @digits = split('', $species_id_str);

        $write_path = catdir($output_path, $digits[0], $digits[1], $digits[2], $digits[3]);
        make_path($write_path);

        $write_file = $write_path."/".$output_file_name."-".$species_id;

        # Check if creating new file
        if (!-e $write_file) {
          $added_species++;
        }

        open($out_fh, '>>', $write_file) or die "Couldn't open output file '$write_file' $!";

        $current_species_id = $species_id;
      }

      print $out_fh $record.($is_uniprot ? "" : "\n");
    }

    close($in_fh);
    close($out_fh) if $out_fh;
  }
}

add_to_log_file($log_file, "Source $source_name cleaned up");
add_to_log_file($log_file, "$source_name skipped species = $skipped_species");
add_to_log_file($log_file, "$source_name species files created = $added_species");

# Save the clean files directory in source db
my ($user, $pass, $host, $port, $source_db) = parse_url($source_db_url);
my $dbi = get_dbi($host, $port, $user, $pass, $source_db);
my $update_version_sth = $dbi->prepare("UPDATE IGNORE version set clean_uri=? where source_id=(SELECT source_id FROM source WHERE name=?)");
$update_version_sth->execute($output_path, $source_name);
$update_version_sth->finish();

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
