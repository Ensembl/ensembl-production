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
use IO::File;
use Getopt::Long;
use Carp;

use Nextflow::Utils;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::IO::FASTASerializer;

my ($cdna_path, $pep_path, $species, $core_db_url, $release);
GetOptions(
  'cdna_path=s'   => \$cdna_path,
  'pep_path=s'    => \$pep_path,
  'species=s'     => \$species,
  'core_db_url=s' => \$core_db_url,
  'release=s'     => \$release
);

# Check that all parameters are passed
foreach my $param ($cdna_path, $pep_path, $species, $core_db_url, $release) {
  defined $param or croak "Usage: dump_ensembl.pl --cdna_path <cdna_path> --pep_path <pep_path> --species <species> --core_db_url <core_db_url> --release <release>";
}

# Open fasta files for writing
my $cdna_fh = IO::File->new($cdna_path, 'w') or croak "Cannot create filehandle $cdna_path";
my $cdna_writer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new($cdna_fh);
my $pep_fh = IO::File->new($pep_path, 'w') or croak "Cannot create filehandle $pep_path";
my $pep_writer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new($pep_fh);

# Load the registry
my ($host, $port, $user, $pass, $dbname) = parse_url($core_db_url);
my $registry = 'Bio::EnsEMBL::Registry';
my %registry_params = (-HOST => $host, -PORT => $port, -USER => $user, -DB_VERSION => $release);
$registry_params{-PASS} = $pass if $pass;
$registry->load_registry_from_db(%registry_params);

# Get transcripts
my $transcript_adaptor = $registry->get_adaptor($species, 'Core', 'Transcript');
my $transcript_list = $transcript_adaptor->fetch_all();

# Dump sequence data
foreach my $transcript (@$transcript_list) {
  my $sequence = $transcript->seq();
  $sequence->id($transcript->dbID());
  $cdna_writer->print_Seq($sequence);

  # Get and dump translation data
  if (my $translation = $transcript->translation) {
    $sequence = $transcript->translate;
    $sequence->id($translation->dbID());
    $pep_writer->print_Seq($sequence);
  }
}

# Close file handles
$cdna_fh->close;
$pep_fh->close;

sub parse_url {
  my ($url) = @_;
  my $parsed_url = Nextflow::Utils::parse($url);
  return @{$parsed_url}{qw(host port user pass dbname)};
}
