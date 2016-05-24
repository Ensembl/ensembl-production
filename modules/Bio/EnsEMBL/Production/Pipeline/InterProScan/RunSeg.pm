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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::RunSeg;

=head1 DESCRIPTION


=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::RunSeg;

use strict;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::Base');

sub fetch_input {
    my $self = shift @_;

    my $seg_exe    = $self->param_required('seg_exe');
    my $seg_params = $self->param_required('seg_params');
    my $seg_infile = $self->param_required('file');
    my $seg_outfile;

    $self->get_logger->info("Processing sequences in file: $seg_infile");

    $seg_outfile = qq($seg_infile.seg.txt);

    $self->get_logger->info("Results of the seg analysis will go to: $seg_outfile");

    if (-z $seg_infile) {
    #if (-s $seg_infile == 0) {
        $self->warning("File $seg_infile is empty, so not running seg analysis on it.");
        return;
    }

    $self->param('seg_exe',    $seg_exe);
    $self->param('seg_params', $seg_params);
    $self->param('seg_infile', $seg_infile);
    $self->param('seg_outfile', $seg_outfile);

return;
}

sub run {
    my $self = shift @_;

    my $seg_exe    = $self->param_required('seg_exe');
    my $seg_params = $self->param_required('seg_params');
    my $seg_infile = $self->param_required('seg_infile');
    my $seg_outfile= $self->param_required('seg_outfile');

    $self->input_job->autoflow(0); #?

    my $seg_cmd = qq($seg_exe $seg_infile $seg_params > $seg_outfile);

    $self->warning($seg_cmd);
    
    $self->run_cmd(
        $seg_cmd, 
        [ 
        { 
            test     => sub { return -e $seg_outfile }, 
            fail_msg => "$seg_outfile was not created, seg analysis may have failed." 
        },
        ]
    );

    $self->dbc->disconnect_if_idle();

return;
}

sub write_output {
  my $self = shift @_;

  my $seg_outfile= $self->param_required('seg_outfile');

  $self->dataflow_output_id({'file'=>$seg_outfile}, 1 );

return;
}

sub run_cmd {
    my $self = shift;
    my $cmd  = shift;
    my $test_for_success = shift;

    my $param_ok = (!defined $test_for_success) || (ref $test_for_success eq 'ARRAY');

    confess("Parameter error! If test_for_success is set, it must be an array of hashes!") 
      unless ($param_ok);

    $self->warning("Running: $cmd")
        if ($self->debug);
    
    system($cmd);

    my $execution_failed = $? == -1;    
    confess("Could not execute command:\n$cmd\n")
      if ($execution_failed);

    my $program_died = $? & 127;
    confess(
        sprintf (
            "Child died with signal %d, %s coredump\n",
            ($? & 127), ($? & 128) ? 'with' : 'without'
        )
    ) if ($program_died);

    my $exit_value = $? >> 8;
    my $program_completed_successfully = $exit_value == 0;
    confess("exited with value $exit_value")
        if (!$program_completed_successfully);

    if ($test_for_success) {

      foreach my $current_test_for_success (@$test_for_success) {

        confess('Type error') unless(ref $current_test_for_success eq 'HASH');

        use Hash::Util qw( lock_hash );
        lock_hash(%$current_test_for_success);

        my $current_test = $current_test_for_success->{test};
        confess('Test must be a sub!') unless (ref $current_test eq 'CODE');

        my $test_succeeded = $current_test->();

        confess(
            "The following command failed:\n"
            . "\n" . $cmd . "\n\n"
            . "Reason: " . $current_test_for_success->{fail_msg} . "\n"
        ) unless($test_succeeded);
      }
    }
}




1;

