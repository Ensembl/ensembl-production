=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::VEP::CopyTmpFtpDir;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::VEP::CopyTmpFtpDir;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Hive::Process/;

sub fetch_input {
    my ($self)  = @_;

return 0;
}

sub run {
    my ($self) = @_;

    my $temp_dir = $self->param('tempdir_vep');
    my $ftp_dir  = $self->param('ftpdir_vep');

    opendir(TMP_DIR, $temp_dir) or die $!;

    while (my $subdir = readdir(TMP_DIR)) {
      next unless $subdir=~/bacteria\_\d+\_collection/; 

      my $dir_1 =  "$temp_dir/$subdir";
      opendir(SUB_DIR, $dir_1) or die $!;

      while (my $vep_file = readdir(SUB_DIR)) {
         next unless ($vep_file =~ m/tar.gz$/);
     
         my $dir_2 = "$ftp_dir/$subdir";
    
         unless (-e $dir_2) {
           print STDERR "$dir_2 doesn't exists. I will try to create it\n";
           print STDERR "mkdir $dir_2 (0755)\n";
           die "Impossible create directory $dir_2\n" unless (mkdir $dir_2, 0755 );
         }
     
         my $copy_cmd = "cp $dir_1/$vep_file $dir_2";
         system($copy_cmd);
     }
  }

  closedir(TMP_DIR);
  closedir(SUB_DIR);

return 0;
}

1;
