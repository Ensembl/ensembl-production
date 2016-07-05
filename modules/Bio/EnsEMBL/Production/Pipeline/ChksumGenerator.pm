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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::ChksumGenerator

=head1 DESCRIPTION

Creates a CHECKSUMS file in the given directory which is produced from running
the sum command over every file in the directory. This excludes the CHECKSUMS
file, parent directory or any hidden files.

=head1 MAINTAINER

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::ChksumGenerator;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;
use Cwd;
use File::Spec;
use Data::Dumper;

sub param_defaults {
  my ($self) = @_;
  return {
  };
}

sub fetch_input {
  my ($self) = @_;

return;
}

sub run {
    my ($self) = @_;
    my $dirs   = get_dirs($self, $self->param_required('base_path'));

    foreach my $dir (@{$dirs}) {
      $self->info('Producing CHECKSUM on directory %s', $dir);

      my $contents = get_contents($self, $dir);

      if(leaf_directory($self, $contents)) {
        $self->info('Directory is a leaf; Will generate checksum');
        remove_checksums($self, $dir, $contents);
        generate_checksums($self, $dir, $contents);
      }
    }
    $self->info('CHECKSUM generating done');

return;
}

sub write_output {
  my ($self) = @_;

return;
}

sub get_dirs {
    my ($self, $base_path) = @_;
   
    my $output    = `find $base_path -type d`;
    my @dirs      = map { chomp $_; $_ } split /\n/, $output;

return \@dirs;
}

sub get_contents {
    my ($self, $dir) = @_;

    my $output = { dirs => [], files => [] };
    my $cwd    = cwd();
    chdir($dir);
  
    opendir my $dh, $dir or die "Cannot open directory '$dir': $!";
    my @contents = readdir($dh);
    closedir $dh or die "Cannot close directory '$dir': $!";
  
    foreach my $c (@contents) {
      if(-f $c) {
        push(@{$output->{files}}, $c);
      }
      elsif($c eq '.' || $c eq '..') {
        next;
      }
      elsif(-d $c) {
        push(@{$output->{dirs}}, $c);
      }
      else {
        #Don't know what type this is ... symbolic link?
      }
    }
    chdir($cwd);

return $output;
}

sub leaf_directory {
    my ($self, $contents) = @_;

return (scalar(@{$contents->{dirs}}) == 0) ? 1 : 0;
}

sub remove_checksums {
    my ($self, $dir, $contents) = @_;

    remove_file($self, $dir, 'CHECKSUMS');
    remove_file($self, $dir, 'MD5SUM');
    my @filtered_files = grep { $_ ne 'CHECKSUMS' } grep { $_ ne 'MD5SUM' } @{$contents->{files}};
    $contents->{files} = \@filtered_files;

return;
}

sub remove_file {
    my ($self, $dir, $file) = @_;

    #return if ! $OPTIONS->{replace};
    my $target = File::Spec->catfile($dir, $file);
    if(-f $target) { unlink $target; }

return;
}

sub generate_checksums {
    my ($self, $dir, $contents) = @_;

    my $files = $contents->{files};
    return if scalar(@{$files}) == 0;
    my $checksum_file = File::Spec->catfile($dir, 'CHECKSUMS');

    if(-f $checksum_file) {
      $self->info("Skipping generating checksum file as $checksum_file as exists");
    }

    open my $fh, '>', $checksum_file or die "Cannot open $checksum_file for writing: $!";

    foreach my $file (sort {$a cmp $b} @{$files}) {
      my $target = File::Spec->catfile($dir, $file);
      next if ! -f $target; # skip if the file was removed
      my $checksum = `sum $target`;
      chomp($checksum);
      print $fh "$checksum $file\n";
    }

    close $fh or die "Cannot close $checksum_file: $!";
    # User rw, Group r, Others r
    chmod 0644, $checksum_file or die "Couldn't change the permission to $checksum_file: $!";
    #chmod S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH, $checksum_file;
    $self->info("Finished writing checksum file $checksum_file");

return;
}



1;
