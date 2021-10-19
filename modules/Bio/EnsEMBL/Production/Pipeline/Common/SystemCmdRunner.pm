=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::Common::SystemCmdRunner;

=head1 DESCRIPTION

=head1 MAINTAINER 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::Common::SystemCmdRunner;

use strict;
use Mouse;

has 'debug' => (is => 'rw', isa => 'Bool');

sub run_cmd {
    my $self = shift;
    my $cmd  = shift;
    my $test_for_success = shift;
    my $ignore_exit_code = shift;

    my $param_ok = (!defined $test_for_success) || (ref $test_for_success eq 'ARRAY');

    confess("Parameter error! If test_for_success is set, it must be an array of hashes!") unless ($param_ok);

    $self->warning("Running: $cmd") if ($self->debug);

    system($cmd);

    if (!$ignore_exit_code) {
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
	confess("The command\n\n$cmd\n\nexited with value $exit_value")
	    if (!$program_completed_successfully);
    }

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
