
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

Bio::EnsEMBL::Production::Pipeline::Common::RunCreateReleaseFile

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::RunCreateReleaseFile;

use strict;
use base ('Bio::EnsEMBL::Hive::Process');

use Bio::EnsEMBL::Production::Pipeline::Common::CreateReleaseFile qw/create_release_file/;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);

sub param_defaults {
	return {

	};
      }

sub fetch_input {
	my ($self) = @_;

	return 0;
}

sub run {
	my ($self) = @_;
	create_release_file( $self->param('output_dir'), $self->param('release') );
	return 0;
}

sub write_output {
	my ($self) = @_;

	return 0;
}

1;

