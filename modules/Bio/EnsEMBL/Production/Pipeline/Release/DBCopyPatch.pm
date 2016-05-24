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

Bio::EnsEMBL::Production::Pipeline::Release::DBCopyPatch;

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::Release::DBCopyPatch;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base('Bio::EnsEMBL::Production::Pipeline::Base');

sub fetch_input {
    my ($self) 	= @_;

return 0;
}

sub run {
    my ($self) = @_;

return 0;
}

sub write_output {
    my ($self)  = @_;

    my $db           = $self->param_required('db');
    my $from_staging = $self->param_required('from_staging');
    my $to_staging   = $self->param_required('to_staging');

    my $cmd = '~/bin/copy_and_patch_db.sh '.$from_staging." ".$to_staging." ".$db;
    $self->warning("Running $cmd"); 

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

    $self->dbc()->disconnect_if_idle(); 

return 0;
}


1;


