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

Bio::EnsEMBL::Production::Pipeline::FindDirs

=head1 DESCRIPTION

Finds all directories under the given path.

Allowed parameters are:

=over 8

=item path - The path to search

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::FindDirs;

use strict;
use warnings;
use Bio::EnsEMBL::Production::Pipeline::Base;

use base qw/Bio::EnsEMBL::Hive::RunnableDB::JobFactory/;

use File::Spec;

sub fetch_input {
  my ($self) = @_;
  $self->throw("No 'path' parameter specified") unless $self->param('path');
  my $dirs = $self->dirs();
  $self->param('inputlist', $dirs);
  return;
}

sub dirs {
  my ($self) = @_;
  
  my @dirs;
  
  my $dir = $self->param('path');
  $self->info('Searching directory %s', $dir);

  opendir(my $dh, $dir) or die "Cannot open directory $dir";
  my @files = sort { $a cmp $b } readdir($dh);
  closedir($dh) or die "Cannot close directory $dir";

  foreach my $file (@files) {
    next if $file =~ /^\./;         #hidden file or up/current dir
    my $path = File::Spec->catdir($dir, $file);
    if(-d $path) {
      $self->fine('Adding %s to the list of found dirs', $path);
      push(@dirs, $path);
    }
  }
  
  return \@dirs;
}

sub info {
   Bio::EnsEMBL::Production::Pipeline::Base::info(@_); 
}

1;
