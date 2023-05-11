=head1 LICENSE

 Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 Copyright [2016-2023] EMBL-European Bioinformatics Institute

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
 disk in LevelDB format.

=head1 DESCRIPTION

 - We expect the file accession_ids.csv to be available
 - We go through the file and build a LevelDB mapping the Uniprot accession to the Alphafold data

=cut

package Bio::EnsEMBL::Production::Pipeline::AlphaFold::CreateAlphaDB;

use warnings;
use strict;

use parent 'Bio::EnsEMBL::Production::Pipeline::Common::Base';
use Bio::EnsEMBL::Utils::Exception qw(throw info);
use Tie::LevelDB;
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

    my $idx_dir = $self->param_required('alphafold_db_dir') . '/uniprot-to-alpha.leveldb';
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

    tie(my %idx, 'Tie::LevelDB', $idx_dir)
        or die "Error trying to tie Tie::LevelDB $idx_dir: $!";

    my $map;
    open($map, '<', $map_file) or die "Opening map file $map_file failed: $!";

    # A line from accession_ids.csv looks like this:
    # Uniprot accession, hit start, hit end, Alphafold accession, Alphafold version
    # A0A2I1PIX0,1,200,AF-A0A2I1PIX0-F1,4
    # Currently, all entries in this file have a unique uniprot accession and
    # have a hit starting at 1

    while (my $line = <$map>) {
        unless ($line =~ /^\w+,\d+,\d+,[\w_-]+,\d+$/) {
            chomp $line;
            warn "Data error. Line is not what we expect: '$line'";
            next;
        }
        my @x = split(",", $line, 2);

        # This is the DB write operation. Tie::LevelDB will croak on errors (e.g. disk full)
        $idx{$x[0]} = $x[1];
    }

    close($map);
    untie %idx;

    if ($copy_back) {
        system (qw(cp -r), $idx_dir, $copy_to);
        system (qw(rm -rf), $idx_dir);
    }

    return 1;
}

1;
