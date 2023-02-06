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

 Bio::EnsEMBL::Production::Pipeline::AlphaFold::CreateUniparcDB

=head1 SYNOPSIS

 This module prepares a DB with a mapping from Uniparc accession to Uniprot
 accession. The DB is created on disk in LevelDB format.

=head1 DESCRIPTION

 - We expect the file idmapping_selected.tab.gz to be available
 - We go through the file and build a LevelDB mapping the Uniparc accessions to Uniprot accessions

=cut

package Bio::EnsEMBL::Production::Pipeline::AlphaFold::CreateUniparcDB;

use warnings;
use strict;

use parent 'Bio::EnsEMBL::Production::Pipeline::Common::Base';

use Bio::EnsEMBL::Utils::Exception qw(throw info);
use Tie::LevelDB;
use IO::Zlib;
use File::Temp 'tempdir';

sub fetch_input {
    my $self = shift;
    $self->param_required('uniparc_db_dir');
    return 1;
}

sub run {
    my ($self) = @_;

    my $map_file = $self->param_required('uniparc_db_dir') . '/idmapping_selected.tab.gz';

    throw ("Data file not found: '$map_file' on host " . `hostname`) unless -f $map_file;

    my $idx_dir = $self->param_required('uniparc_db_dir') . '/uniparc-to-uniprot.leveldb';
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

    my $map = new IO::Zlib;
    $map->open($map_file, 'rb') or die "Opening map file $map_file with IO::Zlib failed: $!";

    # A line from idmapping_selected.tab.gz looks like:
    # Q6GZX4	001R_FRG3G	2947773	YP_031579.1	81941549; 49237298		GO:0046782	UniRef100_Q6GZX4	UniRef90_Q6GZX4	UniRef50_Q6GZX4	UPI00003B0FD4		654924			15165820	AY548484	AAT09660.1				
    # We pick out the Uniparc accession and Uniprot accession
    # index[10] (Uniparc): UPI00003B0FD4; index[0] (Uniprot): Q6GZX4
    my $line;
    while ($line = <$map>) {
        unless ($line =~ /^\w+\t[[:print:]\t]+$/) {
                warn "Data error: Line is not what we expect: '$line'";
                next;
        }
        my @x = split("\t", $line, 12);
        unless ($x[10] and $x[10] =~ /^UPI\w+$/) {
            warn "Data error: Uniparc accession is not what we expect: '$line'";
            next;
        }
        # This is the DB write operation. Tie::LevelDB will croak on errors (e.g. disk full)
        $idx{$x[10]} = $x[0];
    }

    $map->close;
    untie %idx;

    if ($copy_back) {
        system (qw(cp -r), $idx_dir, $copy_to);
        system (qw(rm -rf), $idx_dir);
    }

    return 1;
}


1;
