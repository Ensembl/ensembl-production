#!/usr/bin/env perl
#
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
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
use File::Find;
use File::Spec;
use File::Path qw/mkpath/;
use Bio::EnsEMBL::DBSQL::DataFileAdaptor;  # Required for funcgen
use Getopt::Long qw/:config no_ignore_case auto_version bundling_override/;
use Pod::Usage;

my $rcsid = '$Revision$';
our ($VERSION) = $rcsid =~ /(\d+\.\d+)/;

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
      dry
      host|hostname|h=s
      port|P=i
      username|user|u=s
      password|pass|p=s
      datafile_dir=s
      schema_type=s
      ftp_dir=s
      no_ftp_table
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

sub check {
  my ($self) = @_;
  my $o = $self->opts();

  my @required_params = qw/host username datafile_dir ftp_dir release/;

  foreach my $r (@required_params) {
    if (!$o->{$r}) {
      pod2usage(
        -message => "-${r} has not been given at the command line but is a required parameter",
        -verbose => 1,
        -exitval => 1
      );
    }
  }
  
  foreach my $key (qw/datafile_dir ftp_dir/) {
    my $dir = $o->{$key};
    if(! -d $dir) {
      pod2usage(
        -message => "-${key} given location '${dir}' does not exist",
        -verbose => 1,
        -exitval => 1
      );
    }
  }
  
  return;
}

sub setup {
  my ($self) = @_;
  my $o = $self->opts();
  
  $self->v('Using the database server %s@%s:%d', map { $o->{$_} } qw/username host port/);
  
  ##SETTING UP REGISTRY
  my %args = (
    -HOST => $o->{host}, -PORT => $o->{port}, 
    -USER => $o->{username}, -DB_VERSION => $o->{release},
  ); 
  $args{-PASS} = $o->{password} if $o->{password};
  my $loaded = Bio::EnsEMBL::Registry->load_registry_from_db(%args);
  $self->v('Loaded %d DBAdaptor(s)', $loaded);
  
  return;
}


sub process {
  my ($self) = @_;
  my $dbas = $self->_get_dbs($self->opts->{schema_type});
 
  foreach my $schema_type(keys %{$dbas}){
  
    while (my $dba = shift @{$dbas->{$schema_type}}) {
      $self->_process_dba($dba, $schema_type);
    }
  }
  
  $self->_process_missing_ftp_links;
  return;
}

sub _process_dba {
  my ($self, $dba, $schema_type) = @_;
  $self->v('Working with species %s', $dba->species());
  my $datafiles_method = '_get_'.$schema_type.'_DataFiles';
  my $datafiles        = $self->$datafiles_method($dba);

  if(! @{$datafiles}) {
    $self->v("\tNo datafiles found");
  }
  else {

    foreach my $df (@{$datafiles}) {
      next if $df->absolute();

      if($schema_type eq 'core_like'){
        $self->_process_datafile($df, $self->_target_species_root($df));
      }

      $self->_process_datafile($df, $self->_target_datafiles_root($df));
    }
    # Creating symlinks for README and md5sum files
    if($schema_type eq 'core_like'){
      $self->_process_datafile($datafiles->[0],$self->_target_species_root($datafiles->[0]), 'README');
      $self->_process_datafile($datafiles->[0],$self->_target_species_root($datafiles->[0]), 'md5sum.txt');
    }
    $self->_process_datafile($datafiles->[0],$self->_target_datafiles_root($datafiles->[0]), 'README');
    $self->_process_datafile($datafiles->[0],$self->_target_datafiles_root($datafiles->[0]), 'md5sum.txt');
  }
  $dba->dbc()->disconnect_if_idle();
  return;
}

sub _get_funcgen_DataFiles {
  my ($self, $dba) = @_;
  
  my $species = $dba->species;
  my @funcgen_datafiles_found;
  
  my $data_file_adaptor = Bio::EnsEMBL::DBSQL::DataFileAdaptor->new($dba->dnadb);
  
  my $coord_system_adaptor = $dba->dnadb->get_CoordSystemAdaptor;
  my $all_coord_systems = $coord_system_adaptor->fetch_all;
  my $coord_system = $all_coord_systems->[0];

  if ($species eq 'homo_sapiens') {
  
    my $crispr_adaptor = $dba->get_CrisprSitesFileAdaptor;
    my $crispr_file    = $crispr_adaptor->fetch_file;

    my $data_file = Bio::EnsEMBL::DataFile->new(
        -adaptor      => $data_file_adaptor,
        -coord_system => $coord_system,
        -analysis     => $crispr_file->get_Analysis,
        -name         => $crispr_file->name,
        -url          => $crispr_file->file,
        -file_type    => $crispr_file->file_type,
    );
    push @funcgen_datafiles_found, $data_file;
  }

  my $segmentation_file_adaptor = $dba->get_SegmentationFileAdaptor;
  my $all_segmentation_files = $segmentation_file_adaptor->fetch_all;

  foreach my $current_segmentation_file (@$all_segmentation_files) {
  
    my $data_file = Bio::EnsEMBL::DataFile->new(
        -adaptor      => $data_file_adaptor,
        -coord_system => $coord_system,
        -analysis     => $current_segmentation_file->get_Analysis,
        -name         => $current_segmentation_file->name,
        -url          => $current_segmentation_file->file,
        -file_type    => $current_segmentation_file->file_type,
    );
    push @funcgen_datafiles_found, $data_file;
  }
  
  my $alignment_adaptor = $dba->get_AlignmentAdaptor;
  my $all_alignments    = $alignment_adaptor->fetch_all;
  
  ALIGNMENT:
  foreach my $current_alignment (@$all_alignments) {
  
    # We don't have bigwigs for all alignments, e.g.: technical replicates.
    next ALIGNMENT if (! $current_alignment->has_bigwig_DataFile);
    
    my $bigwig_data_file = $current_alignment->fetch_bigwig_DataFile;
    
    my $data_file = Bio::EnsEMBL::DataFile->new(
        -adaptor      => $data_file_adaptor,
        -coord_system => $coord_system,
        -analysis     => $current_alignment->fetch_Analysis,
        -name         => $current_alignment->name,
        -url          => $bigwig_data_file->path,
        -file_type    => $bigwig_data_file->file_type,
    );
    push @funcgen_datafiles_found, $data_file;
  }

  # Uiuiui
  Bio::EnsEMBL::Registry->add_adaptor($dba->species, 'funcgen', 'datafile', $data_file_adaptor);
  return \@funcgen_datafiles_found;
}

sub _get_core_like_DataFiles{
  my ($self, $dba) = @_;
  return $dba->get_DataFileAdaptor->fetch_all;
}


sub _process_missing_ftp_links {
  my ($self) = @_;
  return unless $self->_webcode_available();
  my $module = 'EnsEMBL::Web::Document::HTML::FTPtable';
  if(exists $self->{ftp}->{missing_types}) {
    foreach my $type (keys %{$self->{ftp}->{missing_types}}) {
      printf("MISSING TYPE: '%s' is missing from the WebCode module '%s'. Please add it\n", $type, $module);
    }
  }
  
  if(exists $self->{ftp}->{missing_species}) {
    foreach my $type (keys %{$self->{ftp}->{missing_species}}) {
      foreach my $species (keys %{$self->{ftp}->{missing_species}->{$type}}) {
        printf("MISSING SPECIES: '%s' is missing from the type '%s' in the WebCode module '%s'. Please add it\n", $species, $type, $module);
      }
    }
  }
  return;
}


sub _process_datafile {
  my ($self, $datafile, $target_dir, $file) = @_;

  if(! -d $target_dir) {
    if($self->opts->{dry}) {
      $self->v("\tWould have created directory '%s'", $target_dir);
    }
    else {
      $self->v("\tCreating directory '%s'", $target_dir);
      mkpath($target_dir) or die "Cannot create the directory $target_dir: $!";
    }
  }
  my $files = $self->_files($datafile,$file);
  # For extra files, sort the array and get the latest version of the file.
  if (defined $file){
    # Sort versionned files
    my @sorted_files = sort @{$files};
    # Only keep latest file
    my $last_file = pop @sorted_files;
    my @files;
    push @files,$last_file;
    $files = \@files;
  }

  foreach my $filepath (@{$files}) {
    # Check if file exist, some directories are missing extra files
    if (defined $filepath){
      my ($file_volume, $file_dir, $name) = File::Spec->splitpath($filepath);
      my $target;
      if (defined $file){
        $target = File::Spec->catfile($target_dir, $file);
      }
      else {
        $target = File::Spec->catfile($target_dir, $name);
      }

      if($self->opts()->{dry}) {
        $self->v("\tWould have linked '%s' -> '%s'", $filepath, $target);
        $self->_flag_missing_ftp_link($datafile);
      }
      else {
        if(-e $target) {
          if(-l $target) {
            unlink $target;
          }
          elsif(-f $target) {
            my $id = $datafile->dbID();
            die "Cannot unlink $target as it is a file and not a symbolic link. Datafile ID was $id";
          }
        }
      
        #Generate the relative link
        my $relative_path_dir = File::Spec->abs2rel($file_dir, $target_dir);
        my $relative_path = File::Spec->catfile($relative_path_dir, $name);
      
        $self->v("\tLinking %s -> %s", $filepath, $target);
        $self->v("\tRelative path is %s", $relative_path);
        symlink($relative_path, $target) or die "Cannot symbolically link $filepath (${relative_path}) to $target: $!";
      
        $self->_flag_missing_ftp_link($datafile);
      }
    }
  }
  return;
}

# Expected path: base/FILETYPE/SPECIES/TYPE/files
# e.g. pub/release-66/bam/pan_trogladytes/genebuild/chimp_1.bam
sub _target_species_root {
  my ($self, $datafile) = @_;
  my $base = $self->opts()->{ftp_dir};
  my $file_type = $self->_datafile_to_type($datafile); 
  my $ftp_type = $self->_dba_to_ftp_type($datafile->adaptor()->db());
  my $species = $datafile->adaptor()->db()->get_MetaContainer()->get_production_name();
  return File::Spec->catdir($base, $file_type, $species, $ftp_type);
}


# Expected path: base/data_files/normalpath
# e.g. pub/release-66/data_files/pan_trogladytes/CHIMP2.14/rnaseq/chimp_1.bam
sub _target_datafiles_root {
  my ($self, $datafile) = @_;
  my $base = File::Spec->catdir($self->opts()->{ftp_dir}, 'data_files');
  my $target_location = $datafile->path($base);
  $target_location =~ s/funcgen\///;  
  my ($volume, $dir, $file) = File::Spec->splitpath($target_location);
  return $dir;
}


sub _flag_missing_ftp_link {
  my ($self, $datafile) = @_;
  if($self->_webcode_available()) {
    my $type = $self->_datafile_to_type($datafile);
    my $species = $datafile->adaptor()->db()->get_MetaContainer()->get_production_name();
    my $missing_type = 1;
    my $missing_species = 1;
    if(exists $self->{_webcode}->{$type}) {
      $missing_type = 0;
    }
    if(! $missing_type && exists $self->{_webcode}->{$type}->{$species}) {
      $missing_species = 0;
    }
    $self->{ftp}->{missing_types}->{$type} = 1 if $missing_type;
    $self->{ftp}->{missing_species}->{$type}->{$species} = 1 if $missing_species;
  }
  return;
}

# This needs updating for funcgen as the file type does not trnaslate to the path in _target_species_root?

sub _datafile_to_type {
  my ($self, $datafile) = @_;
  return lc($datafile->file_type());
}


sub _dba_to_ftp_type {
  my ($self, $dba) = @_;
  my $group = $dba->group();
  my $type = {
    core => 'genebuild',
    rnaseq => 'genebuild',
    otherfeatures => 'genebuild',
    variation => 'variation',
    funcgen => '',
  }->{$group};
  die "No way to convert from $group to a type" unless defined $type;
  return $type;
}


sub _get_dbs {
  my ($self, $schema_type) = @_;
  my $dbas = Bio::EnsEMBL::Registry->get_all_DBAdaptors();
  my %final_dbas;
  my %required_types = (core => 'core_like', funcgen => 'funcgen');  # Merge with _dba_to_ftp_type & make package var?

  if($schema_type){
    if(! exists $required_types{$schema_type}){
      die("Cannot _get_dbs schema_type is not supported:\t".$schema_type);
    }
    %required_types = ($schema_type => $required_types{$schema_type});
  }

  while(my $dba = shift @{$dbas}) {
    next if $dba->species() eq 'multi';
    next if lc($dba->species()) eq 'ancestral sequences';
    next if $dba->dbc()->dbname() =~ /^.+_userdata$/xms;
    
    my $type = $dba->get_MetaContainer()->single_value_by_key('schema_type');
    $dba->dbc()->disconnect_if_idle();
    next unless $type;

    if(exists $required_types{$type}){
      $final_dbas{$required_types{$type}} ||= [];
      push @{$final_dbas{$required_types{$type}}}, $dba;
    }
  }

  foreach my $rtype(values %required_types){
    my $num_dbs = (defined $final_dbas{$rtype}) ? scalar(@{$final_dbas{$rtype}}) : 0;   
    $self->v('Found %d '.$rtype.' like database(s)', $num_dbs);
  }

  return \%final_dbas;
}


sub _files {
  my ($self, $datafile, $file) = @_;
  my $source_file = $datafile->path($self->opts->{datafile_dir});
  $source_file =~ s/funcgen\///;   
  my ($volume, $dir, $name) = File::Spec->splitpath($source_file);
  if (defined $file){
    $name=$file;
  }
  my $escaped_name = quotemeta($name);
  my $regex = qr/^$escaped_name.*/;

  my @files;
  find(sub {
    push(@files, $File::Find::name) if $_ =~ $regex;
  }, $dir);
  return \@files;
}

sub v {
  my ($self, $msg, @params) = @_;
  return unless $self->opts()->{verbose};
  printf(STDERR $msg."\n", @params);
  return;
}

sub _webcode_available {
  my ($self) = @_;
  return $self->{_webcode_available} if exists $self->{_webcode_available};
  if($self->opts()->{no_ftp_table}) {
    $self->{_webcode_available} = 0;
    return $self->{_webcode_available};
  }
  
  eval {
    $self->{_webcode_available} = 0;
    require EnsEMBL::Web::Document::HTML::FTPtable;
    my $types_for_species = EnsEMBL::Web::Document::HTML::FTPtable->required_types_for_species();
    $self->{_webcode} = $types_for_species;
    $self->{_webcode_available} = 1;
  };
  if($@) {
    warn "Trying to setup the webcode to flag those links not on the FTP table. Please fix the error if you want this feature: $@";
  }
  
  return;
}

Script->run();

1;
__END__

=pod

=head1 NAME

build_datafile_ftp_directory.pl

=head1 SYNOPSIS

  #BASIC
  ./build_datafile_ftp_directory.pl -release VER -user USER -pass PASS -host HOST [-port PORT] -datafile_dir DIR -ftp_dir DIR [-dry] [-verbose] [-help | -man]
  
  #EXAMPLE dry
  ./build_datafile_ftp_directory.pl -release 66 -host ensembdb.ensembl.org -port 5306 -user anonymous -verbose -datafile_dir /my/datafile -ftp_dir /target/datafile/pub -dry
  
  #EXAMPLE do it
  ./build_datafile_ftp_directory.pl -release 66 -host ensembdb.ensembl.org -port 5306 -user anonymous -verbose -datafile_dir /my/datafile -ftp_dir /target/datafile/pub

=head1 DESCRIPTION

A script which will link all files for datafiles in a release into a
FTP compatible directory format.

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

=item B<--datafile_dir>

  -datafile_dir /datafile/dir

REQUIRED. Source directory which is the intended root of the datafiles.

=item B<--ftp_dir>

  -ftp_dir /ftp/site/pub/release-66

REQUIRED. Target directory to symbolically link into. Push directly into the
release directory as the script does not assume the directory is publically
available.

=item B<--no_ftp_table>

If flagged the script will not warn about the FTP table and therefore does
not have any dependencies on the webcode.

=item B<--schema_type>

Restrict schema types to process. Valid values are funcgen or core, which 
includes all the core like schema types e.g. rnaseq etc

=item B<--verbose>

Makes the program give more information about what is going on. Otherwise
the program is silent.

=item B<--dry>

If specified the script will inform of the types of commands and actions it 
would have performed.

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

=back

=end
