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

Bio::EnsEMBL::Production::Pipeline::Flatfile::CheckFlatfile

=head1 DESCRIPTION

Validates all compressed files in the pipeline data directory 
(i.e. base_path + type + species) according to the format as 
specified by the type argument (embl|genbank).

Allowed parameters are:

=over 8

=item type - The format to parse

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Flatfile::CheckFlatfile;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Flatfile::Base/;

use Bio::EnsEMBL::Utils::IO qw(filter_dir);
use Bio::EnsEMBL::Production::Pipeline::Flatfile::ValidatorFactoryMethod;

sub fetch_input {
  my ($self) = @_;

  $self->throw("No 'type' parameter specified") unless $self->param('type');

  return;
}

sub run {
  my ($self) = @_;

  # select dat.gz files in the directory
  my $data_path = $self->data_path();
  my $files = filter_dir($data_path, sub { 
			   my $file = shift;
			   return $file if $file =~ /\.dat\.gz$/; 
			 });

  my $validator_factory = 
    Bio::EnsEMBL::Production::Pipeline::Flatfile::ValidatorFactoryMethod->new();
  my $type = $self->param('type');

  foreach my $file (@{$files}) {
    my $full_path = File::Spec->catfile($data_path, $file);
    my $validator = $validator_factory->create_instance($type);

    $validator->file($full_path);
    my $count = 0;
    eval {
      while ( $validator->next_seq() ) {
	$self->fine("%s: OK", $file);
	$count++;
      }
    };
    $@ and $self->throw("Error parsing $type file $file: $@");

    my $msg = sprintf("%s: processed %d record(s)", $file, $count);
    $self->info($msg);
    $self->warning($msg);
  }

  return;
}

1;
