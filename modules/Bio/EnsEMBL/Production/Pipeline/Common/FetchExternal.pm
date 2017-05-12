=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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

=head1 NAME

Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FetchExternal

=head1 DESCRIPTION

Download data from ftp site or local path.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FetchExternal;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

use File::Copy qw(copy);
use File::Spec::Functions qw(catdir);
use Net::FTP;
use URI;

sub write_output {
  my ($self) = @_;
  
  my $output_id = {
    $self->param('file_varname') => $self->param('output_file'),
  };
  $self->dataflow_output_id($output_id, 1);
}

sub fetch_ebi_file {
  my ($self, $file, $local_file) = @_;

  my $ebi_size = -s $file;
  my $ebi_mdtm = (stat $file)[9];
  
  if (-e $local_file) {
    my $local_size = -s $local_file;
    my $local_mdtm = (stat $local_file)[9];
    
    if ( ($ebi_size == $local_size) && ($ebi_mdtm == $local_mdtm) ) {
      $self->warning("Using existing file '$local_file' with matching timestamp.");
    } else {
      copy($file, $local_file) or $self->throw("Failed to get '$file': $@");
    }
  } else {
    copy($file, $local_file) or $self->throw("Failed to get '$file': $@");
  }
  
  # Set the local timestamp to match the remote one.
  utime $ebi_mdtm, $ebi_mdtm, $local_file;
  
  if (! -e $local_file) {
    $self->throw("Failed to copy file '$file'.");
  }
}

sub get_ftp {
  my ($self, $uri) = @_;
  
  my $ftp_uri  = URI->new($uri);
  my $ftp_host = $ftp_uri->host;
  my $ftp_path = $ftp_uri->path;
  
  my $ftp = Net::FTP->new($ftp_host) or $self->throw("Failed to reach FTP host '$ftp_host': $@");
  $ftp->login or $self->throw(printf("Anonymous FTP login failed: %s.\n", $ftp->message));
  $ftp->cwd($ftp_path) or $self->throw(printf("Failed to change directory to '$ftp_path': %s.\n", $ftp->message));
  $ftp->binary();
  
  return $ftp;
}

sub fetch_ftp_file {
  my ($self, $ftp, $file, $local_file) = @_;
  
  my $remote_size = $ftp->size($file);
  my $remote_mdtm = $ftp->mdtm($file);
  
  if (-e $local_file) {
    my $local_size = -s $local_file;
    my $local_mdtm = (stat $local_file)[9];
    
    if ( ($remote_size == $local_size) && ($remote_mdtm == $local_mdtm) ) {
      $self->warning("Using existing file '$local_file' with matching timestamp.");
    } else {
      $ftp->get($file, $local_file) or $self->throw("Failed to get '$file': $@");
    }
  } else {
    $ftp->get($file, $local_file) or $self->throw("Failed to get '$file': $@");
  }
  
  # Set the local timestamp to match the remote one.
  utime $remote_mdtm, $remote_mdtm, $local_file;
  
  if (! -e $local_file) {
    $self->throw("Failed to download file '$file'.");
  }
}

sub fetch_ftp_files {
  my ($self, $ftp, $files_pattern, $out_dir) = @_;
  
  my @all_files = $ftp->ls();
  my @local_files;
  
  my @files = grep { $_ =~ /$files_pattern/ } @all_files;
  for my $file (@files) {
    my $remote_size = $ftp->size($file);
    my $remote_mdtm = $ftp->mdtm($file);
    
    my $local_file = catdir($out_dir, $file);
    
    if (-e $local_file) {
      my $local_size = -s $local_file;
      my $local_mdtm = (stat $local_file)[9];
      
      if ( ($remote_size == $local_size) && ($remote_mdtm == $local_mdtm) ) {
        $self->warning("Using existing file '$local_file' with matching timestamp.");
      } else {
        $ftp->get($file, $local_file) or $self->throw("Failed to get '$file': $@");
      }
    } else {
      $ftp->get($file, $local_file) or $self->throw("Failed to get '$file': $@");
    }
    
    # Set the local timestamp to match the remote one.
    utime $remote_mdtm, $remote_mdtm, $local_file;
    
    if (! -e $local_file) {
      $self->throw("Failed to download file '$file'.");
    } else {
      push @local_files, $local_file;
    }
  }
  
  return \@local_files;
}

1;
