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

 Bio::EnsEMBL::Production::Pipeline::GPAD::ProcessDirectory;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::GPAD::ProcessDirectory;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use base ('Bio::EnsEMBL::Hive::Process');

sub run {
    my ($self) = @_;

    my $dir = $self->param_required('gpad_directory');

    opendir(DIR, $dir) or die $!;

    # Flowing 1 job per *.gpa file
    while (my $file = readdir(DIR)) {
         next unless ($file =~ m/^annotations_ensembl.*gpa$/);
         $file = $dir."/".$file;
         $self->dataflow_output_id( { 'gpad_file' => $file }, 2); 
    }
    closedir(DIR);

return 0;
}

1;
