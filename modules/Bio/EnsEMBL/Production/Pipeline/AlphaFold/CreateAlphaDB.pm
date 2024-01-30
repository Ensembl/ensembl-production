=head1 LICENSE

 Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 Copyright [2016-2024] EMBL-European Bioinformatics Institute

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::AlphaFold::CreateAlphaDB

=head1 SYNOPSIS

 This module prepares a DB with a mapping from Uniprot accession to related
 Alphafold data (Alphafold accession, protein start, end). The DB is created on
 disk in KyotoCabinet format.

=head1 DESCRIPTION

 - We expect the file accession_ids.csv to be available
 - We go through the file and build a DB mapping the Uniprot accession to the Alphafold data

=cut

package Bio::EnsEMBL::Production::Pipeline::AlphaFold::CreateAlphaDB;

use warnings;
use strict;

use parent 'Bio::EnsEMBL::Production::Pipeline::Common::Base';
use Bio::EnsEMBL::Utils::Exception qw(throw info);
use KyotoCabinet;
use File::Temp 'tempdir';


sub fetch_input {
    my $self = shift;
    $self->param_required('alphafold_db_dir');
    return 1;
}

sub run {
    my ($self) = @_;

    my $map_file = $self->param_required('alphafold_db_dir') . '/accession_ids.csv';

    throw ("Data file not found: '$map_file' on host " . `hostname`) unless -f $map_file;

    my $idx_dir = $self->param_required('alphafold_db_dir') . '/uniprot-to-alphafold';
    if (-d $idx_dir) {
        system(qw(rm -rf), $idx_dir);
    }

    my $copy_back = 0;
    my $copy_to;
    if (-d "/dev/shm") {
        $copy_back = 1;
        $copy_to = $idx_dir;
        $idx_dir = tempdir(DIR => '/dev/shm/');
    }
 
    my $db = new KyotoCabinet::DB;

    # Set 4 GB mmap size
    my $mapsize_gb = 4 << 30;

    # Open the DB
    # Open as the exclusive writer, truncate if it exists, otherwise create the DB
    # Open the database as a file hash DB, 600M buckets, 4GB mmap, linear option for
    # hash collision handling. These are tuned for write speed and for approx. 300M entries.
    # As with a regular Perl hash, a duplicate entry will overwrite the previous
    # value.
    $db->open("$idx_dir/uniprot-to-alphafold.kch#bnum=600000000#msiz=$mapsize_gb#opts=l",
        $db->OWRITER | $db->OCREATE | $db->OTRUNCATE
    ) or die "Error opening DB: " . $db->error();

    my $map;
    open($map, '<', $map_file) or die "Opening map file $map_file failed: $!";

    while (my $line = <$map>) {
        # A line from accession_ids.csv looks like this:
        # Uniprot accession, hit start, hit end, Alphafold accession, Alphafold version
        # A0A2I1PIX0,1,200,AF-A0A2I1PIX0-F1,4
        # Currently, all entries in this file have a unique uniprot accession and
        # have a hit starting at 1
        unless ($line =~ /^\w+,\d+,\d+,[\w_-]+,\d+$/) {
            chomp $line;
            die "Data error. Line is not what we expect: '$line'";
        }
        my @x = split(",", $line, 2);

        # This is the DB write operation.
        $db->set($x[0], $x[1]) or die "Error inserting data: " . $db->error();
    }

    $db->close() or die "Error closing DB: " . $db->error();

    if ($copy_back) {
        system (qw(cp -r), $idx_dir, $copy_to);
        system (qw(rm -rf), $idx_dir);
    }

    return 1;
}

1;
