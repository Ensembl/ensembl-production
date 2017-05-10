=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::InterProScanPrograms;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

sub run {
  my ($self) = @_;
  my $analyses = $self->param_required('analyses');
  
  my @all_applications;
  my @lookup_applications;
  my @nolookup_applications;
  
  foreach my $analysis (@{$analyses}) {
    if (exists $$analysis{'ipscan_name'}) {
      if (exists $$analysis{'ipscan_lookup'} && $$analysis{'ipscan_lookup'}) {
        push @lookup_applications, $$analysis{'ipscan_name'};
      } else {
        push @nolookup_applications, $$analysis{'ipscan_name'};
      }
    }
  }
  @all_applications = (@lookup_applications, @nolookup_applications);
  
  $self->param(
    'interproscan_applications',
    {
      'interproscan_lookup_applications'   => \@lookup_applications,
      'interproscan_nolookup_applications' => \@nolookup_applications,
      'interproscan_local_applications'    => \@all_applications,
    }
  );
}

sub write_output {
  my ($self) = @_;
  
  $self->dataflow_output_id($self->param('interproscan_applications'), 1 );
}

1;
