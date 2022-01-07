
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::Common::GetDivision;

=head1 DESCRIPTION

 Determine the division of a database; the simple functionality might
 not seem like it warrants a module, but it makes it easy to slot into
 a pipeline. Requires 'dbname' and 'reg_conf' parameters.

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::GetDivision;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Hive::Process/;

use Bio::EnsEMBL::Registry;

sub run {
  my ($self) = @_;
  my $dbname = $self->param_required('dbname');

  my ($dba) = @{
    Bio::EnsEMBL::Registry->get_all_DBAdaptors_by_dbname($dbname)
  };

  my $division;
  if ($dba->group eq 'compara') {
    $division = $dba->get_division();
  } else {
    my $mca = $dba->get_adaptor("MetaContainer");
    $division = $mca->single_value_by_key('species.division');
  }

  if (defined $division) {
    $division =~ s/^Ensembl//;
    $division = lc($division);
  }

  $self->param('division', $division);
}

sub write_output {
  my ($self) = @_;

  $self->dataflow_output_id(
    {
      division => $self->param('division')
    },
    1
  );
}

1;
