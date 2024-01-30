#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2024] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Script;

use strict;
use warnings;
use feature 'say';

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw/throw warning/;
use HTTP::Tiny;
use Text::CSV;
use Getopt::Long qw/:config no_ignore_case auto_version bundling_override/;
use Pod::Usage;
use File::Spec;

sub run {
  my ($class) = @_;
  my $self = bless({}, $class);
  $self->args();
  $self->setup();
  $self->process();
  return;
}

sub args {
  my ($self) = @_;
  my $opts = {
    port => 3306,
    refget => 'https://www.ebi.ac.uk/ena/cram',
  };
  GetOptions(
    $opts, qw/
      release|version=i
      host|hostname|h=s
      port|P=i
      username|user|u=s
      password|pass|p=s
      species=s
      group=s
      refget=s
      output_dir=s
      check_refget
      verbose
      help
      man
      /
  ) or pod2usage(-verbose => 1, -exitval => 1);
  pod2usage(-verbose => 1, -exitval => 0) if $opts->{help};
  pod2usage(-verbose => 2, -exitval => 0) if $opts->{man};
  $self->{opts} = $opts;
  return;
}

sub opts {
  my ($self) = @_;
  return $self->{'opts'};
}

sub setup {
  my ($self) = @_;
  my $o = $self->opts();

  if(!$o->{output_dir}) {
    throw("No output location given. Exiting");
  }
  my $output_dir = $o->{output_dir};
  if(! -d $output_dir) {
    throw("Output directory '${output_dir}' does not exist. Exiting");
  }

  $self->v('Using the database server %s@%s:%d', map { $o->{$_} } qw/username host port/);

  ##SETTING UP REGISTRY
  my %args = (
    -HOST => $o->{host}, -PORT => $o->{port},
    -USER => $o->{username}
  );
  $args{-DB_VERSION} = $o->{release};
  $args{-PASS} = $o->{password} if $o->{password};
  # $args{-VERBOSE} = 1 if $o->{verbose};
  my $loaded = Bio::EnsEMBL::Registry->load_registry_from_db(%args);
  $self->v('Loaded %d DBAdaptor(s)', $loaded);

  return;
}

sub process {
  my ($self) = @_;
  my $dbas = $self->_get_dbs();
  while (my $dba = shift @{$dbas}) {
    $self->_process_dba($dba);
  }
  return
}

sub _process_dba {
  my ($self, $dba) = @_;
  $self->v('Working with species %s and group %s', $dba->species(), $dba->group());
  my $production_name = $dba->get_MetaContainer()->get_production_name();

  #Setup files
  my $output_file = "${production_name}.csv";
  my $output = File::Spec->catfile($self->opts()->{output_dir}, $output_file);
  open(my $fh, ">:encoding(utf8)", $output) or throw("${output}: $!");
  my $csv = $self->csv();

  my $checksums = $self->_get_checksums($dba);
  my @slices = @{$dba->get_SliceAdaptor()->fetch_all('toplevel', undef, 1, undef, undef)};
  while(my $slice = shift @slices) {
    my $seq_region_id = $slice->get_seq_region_id();
    my $region_name = $slice->seq_region_name();
    my $length = $slice->length();
    my $md5 = $checksums->{$seq_region_id};
    my $exists = $self->sequence_exists($md5);
    my $row = [$production_name, $seq_region_id, $md5, $region_name, $length, $exists];
    $csv->say($fh, $row);
  }
  #Cleanup
  $dba->dbc()->disconnect_if_idle();
  close($fh) or throw("Cannot close ${output}: $!");
  return;
}

sub sequence_exists {
    my ($self, $md5) = @_;
    if(! $self->opts()->{check_refget}) {
      return -1;
    }
    my $url = $self->opts->{refget};
    my $full_url = "${url}/sequence/${md5}/metadata";
    my $headers = {};
    # ENA server issue. Does not accept application/json but does return correct
    # data if you omit this.
    if($url !~ /www\.ebi\.ac\.uk\/ena\/cram/) {
        $headers->{Accept} = 'application/json';
    }
    my $res = $self->http_tiny()->get($full_url, { headers => $headers } );
    return ($res->{success}) ? 1 : 0;
}

sub http_tiny {
  my ($self) = @_;
  if(! exists $self->{http_tiny}) {
    $self->{http_tiny} = HTTP::Tiny->new();
  }
  return $self->{http_tiny};
}

sub csv {
  my ($self) = @_;
  if(! exists $self->{csv}) {
    $self->{csv} = Text::CSV->new ({ binary => 1, auto_diag => 1 });
  }
  return $self->{csv};
}

sub _get_checksums {
  my ($self, $dba) = @_;
  my $sql = << 'EOF';
  SELECT sr.seq_region_id, att.value
FROM seq_region sr
JOIN coord_system cs on cs.coord_system_id = sr.coord_system_id
JOIN seq_region_attrib att ON sr.seq_region_id = att.seq_region_id
JOIN attrib_type at on att.attrib_type_id = at.attrib_type_id
WHERE cs.species_id =?
AND at.code =?
EOF
  my $params = [$dba->species_id(), 'md5_toplevel'];
  my $lookup = $dba->dbc()->sql_helper()->execute_into_hash(-SQL => $sql, -PARAMS => $params);
  return $lookup;
}

sub _get_dbs {
  my ($self) = @_;
  my $dbas;
  my %args;
  $args{-SPECIES} = $self->opts->{species} if $self->opts->{species};
  $args{-GROUP} = $self->opts->{group} if $self->opts->{group};
  if(%args) {
    $dbas = Bio::EnsEMBL::Registry->get_all_DBAdaptors(%args);
  }
  else {
     $dbas = Bio::EnsEMBL::Registry->get_all_DBAdaptors();
  }
  my @final_dbas;
  while(my $dba = shift @{$dbas}) {
    next if $dba->species() eq 'multi';
    next if lc($dba->species()) =~ /ancestral sequences/;
    next if $dba->dbc()->dbname() =~ /^.+_userdata$/xms;

    my $type = $dba->get_MetaContainer()->single_value_by_key('schema_type');
    $dba->dbc()->disconnect_if_idle();
    next unless $type;
    push(@final_dbas, $dba) if $type eq 'core';
  }
  $self->v('Found %d core like database(s)', scalar(@final_dbas));
  return [sort { $a->species() cmp $b->species() } @final_dbas];
}

sub v {
  my ($self, $msg, @params) = @_;
  return unless $self->opts()->{verbose};
  say sprintf($msg, @params);
  return;
}

Script->run();

1;
__END__

=pod

=head1 NAME

check_sequence_refget.pl

=head1 SYNOPSIS

  #BASIC
  ./check_sequence_refget.pl -release VER -user USER -pass PASS -host HOST [-port PORT] \
                      [-species SPECIES] [-group GROUP] \
                      [-output_dir PATH] \
                      [-check_refget] \
                      [-verbose] \
                      [-help | -man]

  #EXAMPLE
  ./check_sequence_refget.pl -release 110 -host ensembdb.ensembl.org -port 5306 -user anonymous -species homo_sapiens -group core

  #Everything for a release
  ./check_sequence_refget.pl -release 110 -host ensembdb.ensembl.org -port 5306 -user anonymous -group core -check_refget

=head1 DESCRIPTION

A script which goes through a given genome and looks to see if its sequences are all to be found in the specified refget instance. It 
does this by looking for the md5 checksum attribute C<md5_toplevel> (so a DB must have had checksums run against it) and
queries refget for the sequence's existence. Will write data to the specified file. It is recommended to run this once. 
Primary use is to record existence in ENA's refget instance

=head1 OPTIONS

=over 8

=item B<--username | --user | -u>

REQUIRED. Username of the connecting account

=item B<--password | -pass | -p>

REQUIRED. Password of the connecting user.

=item B<--release | --version>

REQUIRED. Indicates the release of Ensembl to process

=item B<--host | --host | -h>

REQUIRED. Host name of the database to connect to

=item B<--port | -P>

Optional integer of the database port. Defaults to 3306.

=item B<--species>

Specify the tests to run over a single species' set of core databases

=item B<--group>

Only run tests on a single type of database registry group

=item B<--refget>

Run tests against the given refget server. Defaults to C<https://www.ebi.ac.uk/ena/cram>.

=item B<--output_dir>

REQUIRED. Write information about the sequence's existence in ENA. Will write to a CSV file 
with the columns C<production_name,seq_region_id,md5,region_name,length,exists> where exists is set to a 1 or 0 (or -1 
if C<--check_refget> wasn't on). Will create a file per species processed of the format C<[production_name].csv>.

=item B<--check_refget>

Run the check against refget for every md5 checksum. If not set, then the output in the CSV will be B<-1>.

=item B<--verbose>

Write messages about progress

=item B<--help>

Help message

=item B<--man>

Man page

=back

=head1 REQUIREMENTS

=over 8

=item Perl 5.10+

=item Bio::EnsEMBL

=item Text::CSV

=item HTTP::Tiny

=back

=end
