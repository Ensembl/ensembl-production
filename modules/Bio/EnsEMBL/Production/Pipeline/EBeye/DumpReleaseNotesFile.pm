=pod

=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::EBeye::DumpReleaseNotesFile

=head1 DESCRIPTION

Module responsible for creating the release_note.txt file.

Allowed parameters are:

=over 8

=item release - The current release we are emitting

=item release_date - The current release date we are emitting

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::EBeye::DumpReleaseNotesFile;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;

use base qw/Bio::EnsEMBL::Production::Pipeline::EBeye::Base/;

sub fetch_input {
  my ($self) = @_;
  
  throw "Need a release" unless $self->param('release');
  throw "Need a release date" unless $self->param('release_date');

  $self->assert_executable('zgrep');
  
  return;
}

sub run {
  my ($self) = @_;

  my $dir = $self->data_path();
  $self->info('Analysing directory %s', $dir);

  opendir(my $dh, $dir) or die "Cannot open directory $dir";
  my @files = sort { $a cmp $b } readdir($dh);
  closedir($dh) or die "Cannot close directory $dir";

  my $release_notes = 
    {
     'release' => $self->param('release'),
     'release_date' => $self->param('release_date'),
     'entry_count' => 0
    };

  foreach my $file (@files) {
    next unless $file =~ /\.xml\.gz/;
    
    my $path = File::Spec->catfile($dir, $file);
    $release_notes->{'entry_count'} += $self->_count_entries($path);
  }
  
  $self->param('release_notes', $release_notes);  

  return;
}

sub write_output {
  my ($self) = @_;
  my $dir = $self->data_path();
  my $release_note = File::Spec->catfile($dir, 'release_note.txt');

  if(-f $release_note) {
    $self->info('Release note file already exists. Removing');
    unlink $release_note;
  }
  
  my $release_notes = $self->param('release_notes');
  return unless $release_notes;

  work_with_file($release_note, 'w', sub {
		   my ($fh) = @_;
		   printf $fh "release=%s\nrelease_date=%s\nentry_count=%s\n", 
		     $release_notes->{release}, $release_notes->{release_date}, $release_notes->{entry_count};
		   return;
		  });
  
  chmod(0666, $release_note) or 
    $self->throw("Cannot perform the chmod to mode 0666 for file $release_note");

  return;
}

sub _count_entries {
  my ($self, $file) = @_;

  # assume file is zipped
  my $cmd = sprintf "zgrep '<entry' %s | wc ", $file; # | perl -lne '/^\\s+(\\d+)/; print $1'", $file;
  my ($rc, $value) = $self->run_cmd($cmd);
  $value =~ /^\s+(\d+)/;

  return $1;
}

1;
