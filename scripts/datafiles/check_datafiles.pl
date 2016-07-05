#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
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

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw/throw warning/;
use Fcntl ':mode';
use File::Basename qw/dirname/;
use File::Spec::Functions qw/:ALL/;
use Getopt::Long qw/:config no_ignore_case auto_version bundling_override/;
use Pod::Usage;
use Test::More;

#Optionally bring in Bio::DB::Sam for BAM querying or use the binary. Dependent
#on cmdline options
my $NO_SAM_PERL;
my $NO_SAMTOOLS;

my $Test = Test::Builder->new();

sub run {
  my ($class) = @_;
  my $self = bless({}, $class);
  $self->args();
  $self->check();
  $self->setup();
  $self->process();
  return;
}

sub args {
  my ($self) = @_;
  my $opts = {
    port => 3306
  };
  GetOptions(
    $opts, qw/
      release|version=i
      host|hostname|h=s
      port|P=i
      username|user|u=s
      password|pass|p=s
      datafile_dir|dir=s
      unix_group=s
      species=s
      group=s
      no_bamchecks!
      force_samtools_binary!
      samtools_binary=s
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

sub check {
  my ($self) = @_;
  my $o = $self->opts();

  my @required_params = qw/host username datafile_dir/;

  foreach my $r (@required_params) {
    if (!$o->{$r}) {
      pod2usage(
        -message => "-${r} has not been given at the command line but is a required parameter",
        -verbose => 1,
        -exitval => 1
      );
    }
  }
  
  foreach my $key (qw/datafile_dir/) {
    my $dir = $o->{$key};
    if(! -d $dir) {
      pod2usage(
        -message => "-${key} given location '${dir}' does not exist",
        -verbose => 1,
        -exitval => 1
      );
    }
  }
  
  $o->{unix_group} = 'ensembl' unless $o->{unix_group};
  
  return;
}

sub setup {
  my ($self) = @_;
  my $o = $self->opts();

  $self->v('Detecting which samtools to use');
  $self->_find_perl_samtools();
  $self->_find_samtools();
  
  $self->v('Using the database server %s@%s:%d', map { $o->{$_} } qw/username host port/);
  
  ##SETTING UP REGISTRY
  my %args = (
    -HOST => $o->{host}, -PORT => $o->{port}, 
    -USER => $o->{username}
  );
  $args{-DB_VERSION} = $o->{release};
  $args{-PASS} = $o->{password} if $o->{password};
  my $loaded = Bio::EnsEMBL::Registry->load_registry_from_db(%args);
  $self->v('Loaded %d DBAdaptor(s)', $loaded);
  
  return;
}

sub test_path {
  my ($self, $path, $data_file) = @_;
  
  #Just record the dir and file for later use when looking for extra files
  $path = rel2abs($path);
  my ($vol, $dir, $file) = splitpath($path);
  push(@{$self->{dirs}->{$dir}}, $file);
  
  my $name = $data_file->name();
  my $prefix = "Data file $name | File [$path]";
  
  #First pass. Check file & if not there then bail
  my $file_ok = ok(-f $path, "$prefix exists");
  return unless $file_ok;
  
  #File attributes now we know it's here
  my @stat = stat($path);
  my $mode = $stat[2];
  my $user_r = ($mode & S_IRUSR) >> 6;
  my $user_w = ($mode & S_IWUSR) >> 6;
  my $group_r = ($mode & S_IRGRP) >> 3;
  my $group_w = ($mode & S_IWGRP) >> 3;
  my $other_r = ($mode & S_IROTH) >> 0;
  my $other_w = ($mode & S_IWOTH) >> 0;

  my $file_gid  = $stat[5];
  
  #Now do the tests
  # Files must have read permissions on user/group/other
  # They cannot have write permissions on the user/group/other. 
  # They can be executable (we don't care so don't check)
  ok(-s $path, "$prefix has data");
  is($user_r, 4, "$prefix is Read by user");
  is($user_w, 0, "$prefix cannot have user Write permissions");
  is($group_r, 4, "$prefix is Read by group");
  is($group_w, 0, "$prefix cannot have group Write permissions");
  is($other_r, 4, "$prefix is Read by other");
  is($other_w, 0, "$prefix cannot have have other Write permissions");
  
  if($self->opts->{unix_group}) {
    my $unix_group = $self->opts->{unix_group};
    my $group_gid = $self->_get_gid($unix_group);
    if($group_gid) {
      my $group_ok = ok($group_gid == $file_gid, "$prefix is owned by group $unix_group");
      if(!$group_ok) {
        my $real_group = ( getgrgid $file_gid )[0];
        diag("$prefix belongs to $real_group ($file_gid) not $unix_group ($group_gid)");
      }
    }
    else {
      fail("The UNIX group $unix_group is not known on this system");
    }
  }
  
  return;
}

sub test_dirs {
  my ($self) = @_;
  foreach my $dir (keys %{$self->{dirs}}) {
    my $files = $self->{dirs}->{$dir};
    my %lookup = map { $_ => 1 } @{$files};
    my @all_file_paths = grep { $_ =~ /\/\.$/ && $_ =~ /\/\.{2}$/ } glob catfile($dir, "*.*");
    foreach my $path (@all_file_paths) {
      my ($vol, $dir, $file) = splitpath($path);
      ok($lookup{$file}, "$dir | $file was an expected file");
    }
  }
  return;
}

sub process {
  my ($self) = @_;
  my $dbas = $self->_get_core_like_dbs();
  while (my $dba = shift @{$dbas}) {
    $self->_process_dba($dba);
  }
  $self->test_dirs();
  return;
}

sub _process_dba {
  my ($self, $dba) = @_;
  $self->v('Working with species %s and group %s', $dba->species(), $dba->group());
  my $datafiles = $dba->get_DataFileAdaptor()->fetch_all();
  if(! @{$datafiles}) {
    $self->v("No datafiles found");
  }
  else {
    foreach my $data_file (@{$datafiles}) {
      my $paths = $data_file->get_all_paths($self->opts->{datafile_dir});
      foreach my $path (@{$paths}) {
        $self->test_path($path, $data_file);
      }
      if(!$self->opts->{no_bamchecks} && $data_file->file_type() eq 'BAM') {
        $self->_process_bam($dba, $data_file);
      }
    }
  }
  $dba->dbc()->disconnect_if_idle();
  return;
}

sub _process_bam {
  my ($self, $dba, $data_file) = @_;

  my $bam_info = $self->_get_bam_region_info($data_file);
  return unless $bam_info;

  my $toplevel_slices = $self->_get_toplevel_slice_info($dba);

  my @missing_names;
  my @mismatching_lengths;
  foreach my $bam_seq_name (keys %{$bam_info}) {
    if(! exists $toplevel_slices->{$bam_seq_name}) {
      next if $bam_seq_name =~ /EBV/;
      push(@missing_names, $bam_seq_name);
    } else {
      push(@mismatching_lengths, $bam_seq_name)
	if $toplevel_slices->{$bam_seq_name} != $bam_info->{$bam_seq_name};
    }
  }
  
  my $missing_count = scalar(@missing_names);
  if($missing_count > 0) {
    fail("We have names in the BAM file which are not part of this assembly. Please see note output for more details");
    note(sprintf('Missing names: [%s]', join(q{,}, @missing_names)));
  }
  else {
    pass("All names in the BAM file are toplevel sequence region names");
  }
  my $mismatching_count = scalar(@mismatching_lengths);
  if($mismatching_count > 0) {
    fail("We have regions in the BAM file whose lengths do not agree with EnsEMBL. Please see note output for more details");
    note(sprintf('Mismatching lengths: [%s]', join(q{,}, @mismatching_lengths)));
  }
  else {
    pass("All regions in the BAM file have the same length as the corresponding toplevel sequence regions");
  }

  return;
}

sub _get_core_like_dbs {
  my ($self) = @_;
  my $dbas;
  my %args;
  $args{-SPECIES} = $self->opts->{species};
  $args{-GROUP} = $self->opts->{group};
  if(%args) {
    $dbas = Bio::EnsEMBL::Registry->get_all_DBAdaptors(%args);
  }
  else {
     $dbas = Bio::EnsEMBL::Registry->get_all_DBAdaptors();
  }
  my @final_dbas;
  while(my $dba = shift @{$dbas}) {
    next if $dba->species() eq 'multi';
    next if lc($dba->species()) eq 'ancestral sequences';
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
  note sprintf($msg, @params);
  return;
}

sub _get_gid {
  my ($self, $group) = @_;
  my $group_uid;
  if ($group =~ /^\d+/) {
    $group_uid = $group;
    $group = ( getgrgid $group )[0];
  }
  else {
    $group_uid = (getgrnam($group))[2];
  }
  return $group_uid;
}

sub _get_bam_region_info {
  my ($self, $data_file) = @_;
  my $path = $data_file->path($self->opts->{datafile_dir});
  my $data;
  
  if(!$NO_SAM_PERL) {
    $data = $self->_get_bam_region_info_from_perl($path);
  }
  else {
    diag "Cannot use Bio::DB::Bam as it is not installed. Falling back to samtools compiled binary" if ! $self->{samtools_warning};
    $self->{samtools_warning} = 1;
    if($NO_SAMTOOLS) {
      diag $NO_SAMTOOLS;
    }
    else {
      $data = $self->_get_bam_region_info_from_samtools($path);
    }
  }
  
  return $data;
}

sub _get_bam_region_info_from_perl {
  my ($self, $path) = @_;

  my $bam = eval { Bio::DB::Bam->open($path); };
  throw "Error opening bam file $path" if $@;

  my $header = $bam->header;
  my $targets = $header->n_targets;
  my $target_names = $header->target_name();
  my $target_lengths = $header->target_len();
  my $data;
  $data->{$target_names->[$_]} = $target_lengths->[$_] 
    for 0..($targets-1);

  return $data;
}

sub _get_bam_region_info_from_samtools {
  my ($self, $path) = @_;
  return if $NO_SAMTOOLS;

  my $data;
  my $samtools_binary = $self->opts->{samtools_binary};

  foreach my $line (split(/\n/, `$samtools_binary idxstats $path`)) {
    my ($name, $len) = split(/\s/, $line);
    next if $name eq '*';
    $data->{$name} = $len;
  }

  return $data;
}

# We support top level names and their UCSC synonyms
sub _get_toplevel_slice_info {
  my ($self, $dba) = @_;
  my $species = $dba->species();
  if(! exists $self->{toplevel_names}->{$species}) {
    delete $self->{toplevel_names};
    my $has_ucsc_synonyms = $self->_has_ucsc_synonyms($dba);
    my $has_refseq_synonyms = $self->_has_refseq_synonyms($dba);
    my $core = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
    my $slices = $core->get_SliceAdaptor()->fetch_all('toplevel');
    my %lookup;
    while( my $slice = shift @{$slices}) {
      my $seq_region_len = $slice->seq_region_length;
      $lookup{$slice->seq_region_name()} = $seq_region_len;
      if($has_ucsc_synonyms) {
        my $synonyms = $slice->get_all_synonyms('UCSC');
        $lookup{$_->name()} = $seq_region_len for @{$synonyms};
      }
      if($has_refseq_synonyms) {
        my $synonyms = $slice->get_all_synonyms('RefSeq_genomic');
        $lookup{$_->name()} = $seq_region_len for @{$synonyms};
      }
    }
    $self->{toplevel_names}->{$species} = \%lookup;
  }
  return $self->{toplevel_names}->{$species};
}

#See if there are any UCSC synonyms hanging around. If not then we 
#do not have to look for them
sub _has_synonyms {
  my ($self, $dba, $source) = @_;
  my $source_id = $dba->get_DBEntryAdaptor->get_external_db_id($source);
  return $dba->dbc()->sql_helper()->execute_single_result(
    -SQL => 'select count(*) from seq_region_synonym where external_db_id =?',
    -PARAMS => [$source_id]
  );
}

sub _has_ucsc_synonyms {
  my ($self, $dba) = @_;
  return $self->_has_synonyms($dba, 'UCSC');
}

sub _has_refseq_synonyms {
  my ($self, $dba) = @_;
  return $self->_has_synonyms($dba, 'RefSeq_genomic');
}

sub _find_perl_samtools {
  my ($self) = @_;
  if($self->opts()->{force_samtools_binary}) {
    $NO_SAM_PERL = 'Forced samtools binary usage';
  }
  else {
    eval 'require Bio::DB::Sam';
    $NO_SAM_PERL = $@ if $@;
  }
  return;
}

sub _find_samtools {
  my ($self) = @_;
  #Optionally look for samtools
  if($NO_SAM_PERL) {
    my $opts = $self->opts();
    my $samtools_binary = $opts->{samtools_binary} || 'samtools';
    my $output = `which $samtools_binary`;
    $output = `locate $samtools_binary` unless $output;
    if($output) {
      $opts->{samtools_binary} = $samtools_binary;
    }
    else {
      $NO_SAMTOOLS = 'Unavailable after searching using `which` and `locate` (and using $samtools_binary). Add to your PATH';
    }
  }
  return;
}

Script->run();
done_testing();

1;
__END__

=pod

=head1 NAME

check_datafiles.pl

=head1 SYNOPSIS

  #BASIC
  ./check_datafiles.pl -release VER -user USER -pass PASS -host HOST [-port PORT] -datafile_dir DIR [-unix_group UNIX_GROUP] \
                      [-species SPECIES] [-group GROUP] [-no_bamchecks] \
                      [-help | -man]
  
  #EXAMPLE
  ./check_datafiles.pl -release 69 -host ensembdb.ensembl.org -port 5306 -user anonymous -datafile_dir /my/datafile
  
  #Skipping BAM checks
  ./check_datafiles.pl -release 71 -host ensembdb.ensembl.org -port 5306 -user anonymous -datafile_dir /my/datafile -no_bamchecks
  
=head1 DESCRIPTION

A script which ensures a data files directory works for a single release.

The code outputs the results in Perl's TAP output making the format compatible with any TAP compatible binary such as prove. You should look
for all tests to pass. Scan for 'not ok' if there is an issue.

This code will also check the integrity of a BAM file e.g. that all BAM regions are toplevel sequences in the given Ensembl species. If
you want to disable this check then do so using the C<-no_bamchecks> flag.

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

=item B<--unix_group>

Specify the UNIX group these files should be readable by. Defaults to ensembl

=item B<--datafile_dir | --dir>

  -datafile_dir /datafile/dir

REQUIRED. Source directory which is the intended root of the datafiles.

=item B<--species>

Specify the tests to run over a single species' set of core databases

=item B<--group>

Only run tests on a single type of database registry group

=item B<--no_bamchecks>

Specify to stop any BAM file checks from occuring. This is normally sanity checks such
as are all BAM regions toplevel core regions

=item B<--force_samtools_binary>

Force the use of samtools binary over Perl bindings.

=item B<--samtools_binary>

User specify the location of the SamTools binary. Please note we do not really want to
use samtools binary since the Perl bindings are sufficient to work

=item B<--help>

Help message

=item B<--man>

Man page

=back

=head1 REQUIREMENTS

=over 8

=item Perl 5.8+

=item Bio::EnsEMBL

=item Post 66 databases

=item Bio::DB::Bam or samtools binary on ENV $PATH

=back

=end

