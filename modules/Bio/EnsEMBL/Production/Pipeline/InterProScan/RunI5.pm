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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::RunI5;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::RunI5;

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;
use Hash::Util qw(lock_hash);
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::Base');

my ($protein_file, $run_mode, $interproscan_exe, $applications);

sub fetch_input {
    my ($self) = @_;

    $protein_file     = $self->param_required('protein_file');
    $run_mode         = $self->param_required('run_mode');
    $interproscan_exe = $self->param_required('interproscan_exe');
    $applications     = $self->param_required('interproscan_applications');
  
    if (!-e $protein_file) {
      $self->throw("File '$protein_file' does not exist");
    } elsif (-s $protein_file == 0) {
      $self->warning("File $protein_file is empty, so not running interproscan on it.");
    exit;
    }

}

sub run {
    my ($self) = @_;
  
    my $outfile_xml_base = "$protein_file.$run_mode";
    my $outfile_xml      = "$outfile_xml_base.xml";
    
    $self->get_logger->info("Interproscan results in XML format will go to: $outfile_xml");
  
    # Must use /tmp for short temporary file names.
    # decodeanhmm from TMHMM can't cope with longer ones.
    my $tmp_dir = "/tmp/$ENV{USER}";

    if (!-e $tmp_dir) {
      $self->warning("Output directory '$tmp_dir' does not exist. I shall create it.");
      make_path($tmp_dir) or $self->throw("Failed to create output directory '$tmp_dir'");
    }
  
    # Single quotes, because ${USER} should be interpreted by the shell
    my $extra_options = '--iprlookup --goterms -f XML --tempdir /tmp/${USER} ';
    $extra_options .= '--applications '.join(',', @$applications).' ';
    my $input_option  = "-i $protein_file ";
    my $output_option = "--output-file-base $outfile_xml_base ";  
  
    if ($run_mode =~ /^(nolookup|local)$/) {
      $extra_options .= "--disable-precalc ";
    }
  
    my $interpro_cmd  = qq($interproscan_exe $extra_options $input_option $output_option);
 
    #$self->dbc->disconnect_when_inactive(1);
 
    $self->run_cmd(
      $interpro_cmd, 
      [ 
        { 
          test     => sub { return -e $outfile_xml }, 
          fail_msg => "$outfile_xml was not created, interproscan.sh may have failed silently." 
        },
        { 
          test     => sub { return -s $outfile_xml!=0 }, 
          fail_msg => "$outfile_xml has size of zero, interproscan.sh may have failed silently." 
        },
     ]
   );

   $self->dbc->disconnect_if_idle() if $self->dbc->connected();  

   $self->param('interpro_xml_file', $outfile_xml);
  
}

sub run_cmd {
    my ($self, $cmd, $test_for_success) = @_;

    my $param_ok = (!defined $test_for_success) || (ref $test_for_success eq 'ARRAY');
    $self->throw("Parameter error! If test_for_success is set, it must be an array of hashes!") 
    unless ($param_ok);

    $self->warning("Running: $cmd") if ($self->debug);
  
    system($cmd);

    my $execution_failed = $? == -1;    
    $self->throw("Could not execute command:\n$cmd\n") if ($execution_failed);

    my $program_died = $? & 127;
    $self->throw(
      sprintf (
        "Child died with signal %d, %s coredump\n",
        ($? & 127), ($? & 128) ? 'with' : 'without'
      )
    ) if ($program_died);
  
    my $exit_value = $? >> 8;
    my $program_completed_successfully = $exit_value == 0;
    $self->throw("exited with value $exit_value") if (!$program_completed_successfully);
  
    if ($test_for_success) {
      foreach my $current_test_for_success (@$test_for_success) {
        $self->throw('Type error') unless(ref $current_test_for_success eq 'HASH');
        lock_hash(%$current_test_for_success);

        my $current_test = $current_test_for_success->{test};
        $self->throw('Test must be a sub!') unless (ref $current_test eq 'CODE');
      
        my $test_succeeded = $current_test->();

        $self->throw(
          "The following command failed:\n\n$cmd\n\n".
          "Reason: " . $current_test_for_success->{fail_msg} . "\n"
        ) unless ($test_succeeded);
      }
    }
}


sub write_output {
    my ($self) = @_;
  
    my $interpro_xml_file = $self->param('interpro_xml_file');
    $self->dataflow_output_id({'interpro_xml_file' => $interpro_xml_file}, 1);
  
}

1;

