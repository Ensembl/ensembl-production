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

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::StoreSegFeatures;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    'logic_name' => 'seg',
  };
}

sub run {
  my ($self) = @_;
  
  my $logic_name   = $self->param_required('logic_name');
  my $seg_out_file = $self->param_required('seg_out_file');
  
  if (-s $seg_out_file == 0) {
    $self->warning("seg output file '$seg_out_file' is empty");
    
  } else {
    my $aa  = $self->core_dba->get_adaptor('Analysis');
    my $pfa = $self->core_dba->get_adaptor('ProteinFeature');
    
    my $analysis = $aa->fetch_by_logic_name($logic_name);
    
    open (my $fh, '<', $seg_out_file) or die "Failed to open $seg_out_file: $!\n";
    
    while (my $line = <$fh>) {
      next if ($line !~ /^\>/);
      
      my ($translation_id, $start, $end) = $line =~ /\>(\d+)\((\d+)\-(\d+)/;
      
      my %pf_args = (
        -start    => $start,
        -end      => $end,
        -hseqname => $logic_name,
        -hstart   => 0,
        -hend     => 0,
        -analysis => $analysis,
      );
      
      my $protein_feature = Bio::EnsEMBL::ProteinFeature->new(%pf_args);
      $pfa->store($protein_feature, $translation_id);
    }
    
    close $fh;
  }
}

1;
