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

 Bio::EnsEMBL::Production::Utils::WaitForFile

=head1 DESCRIPTION

=head1 AUTHOR

 mchakiachvili@ebi.ac.uk

=cut

use Time::Local;
use Time::Duration;

package Bio::EnsEMBL::Production::Utils::WaitForFile;
use strict;
use warnings FATAL => 'all';

sub default_options {
    my ($self) = @_;

    return {
        # inherit other stuff from the base class
        %{$self->SUPER::default_options},
        'scan_dir' => '',
        'files'    => '', # Hard coded file list to check
        'wait_for' => 24  # time to wait in hours before failure
    }
} ## end sub default_options

sub run {
    my ($self) = @_;
    my $start = time();
    my $end = $start + Time::Duration->new(days => $self->param_required('wait_for'));
    my $scan_dir = $self->param_required('scan_dir');
    my @files = $self->param_required('files'); # files pattern or files list
    # Open scan dir
    # for all files:
    # scan for all files matching
    # if found add it / them to output
    # if all files completed
    # output the files list
    # else if we reach timeout ?
    # stop and error
    # wait 5 minutes and reloop
    my @output_files = ();
    opendir(DIR, $scan_dir) or die $!;
    while ($start < $end) {
        for my $pattern (@files) {
            print("$pattern", "\n");
            while (my $file = readdir(DIR)) {
                next if !($file =~ m/$pattern/);
                push @output_files, $file;
                print "$file\n";
            }
        }
    }
    $self->dataflow_output_id({ 'gpad_files' => $output_files }, 1);
    close(DIR)
}
1;