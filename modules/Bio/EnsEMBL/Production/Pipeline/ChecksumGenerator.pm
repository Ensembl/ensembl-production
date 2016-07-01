=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::ChecksumGenerator

=head1 DESCRIPTION

Creates a CHECKSUMS file in the given directory which is produced from running
the sum command over every file in the directory. This excludes the CHECKSUMS
file, parent directory or any hidden files.

Allowed parameters are:

=over 8

=item dir - The directory to generate checksums for

=item gzip - If the resulting file should be gzipped. Defaults to false

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::ChecksumGenerator;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

use File::Spec;
use Bio::EnsEMBL::Utils::IO qw/work_with_file gz_work_with_file/;

sub param_defaults {
  my ($self) = @_;
  return {
    gzip => 0
  };
}

sub fetch_input {
  my ($self) = @_;
  my $dir = $self->param('dir');
  $self->throw("No 'dir' parameter specified") unless $dir;
  $self->throw("Dir $dir does not exist") unless -d $dir;
  return;
}

sub run {
  my ($self) = @_;
  my @checksums;
  
  my $dir = $self->param('dir');
  $self->info('Checksumming directory %s', $dir);

  opendir(my $dh, $dir) or die "Cannot open directory $dir";
  my @files = sort { $a cmp $b } readdir($dh);
  closedir($dh) or die "Cannot close directory $dir";

  foreach my $file (@files) {
    next if $file =~ /^\./;         #hidden file or up/current dir
    next if $file =~ /^CHECKSUM/;
    my $path = File::Spec->catfile($dir, $file);
    my $checksum = $self->checksum($path);
    push(@checksums, [$checksum, $file])
  }
  
  $self->param('checksums', \@checksums);
  return;
}

sub write_output {
  my ($self) = @_;
  my $dir = $self->param('dir');
  my $checksum = File::Spec->catfile($dir, 'CHECKSUMS');
  $checksum .= '.gz' if $self->param('gzip');
  if(-f $checksum) {
    $self->info('Checksum file already exists. Removing');
    unlink $checksum;
  }
  
  my @checksums = @{$self->param('checksums')};
  
  return unless @checksums;
  
  my $writer = sub {
    my ($fh) = @_;
    foreach my $entry (@checksums) {
      my $line = join(qq{\t}, @{$entry});
      print $fh $line;
      print $fh "\n"; 
    }
    return;
  };
  my @params = ($checksum, 'w', $writer);
  
  
  if($self->param('gzip')) {
    gz_work_with_file(@params);
  } 
  else {
    work_with_file(@params);
  } 
  
  $self->permissions($checksum);
  return;
}

sub checksum {
  my ($self, $path) = @_;
  my $checksum = `sum $path`;
  $checksum =~ s/\s* $path//xms;
  chomp($checksum);
  return $checksum;
}

sub permissions {
  my ($self, $file) = @_;
  my $mode = 0666;
  chmod($mode, $file) or $self->throw("Cannot perform the chmod to mode $mode for file $file");
  return;
}

1;
