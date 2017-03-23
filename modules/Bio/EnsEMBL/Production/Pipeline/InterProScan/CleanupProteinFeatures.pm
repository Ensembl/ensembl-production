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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::CleanupProteinFeatures;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::CleanupProteinFeatures;

use strict;
use Data::Dumper;
use List::MoreUtils qw/natatime/;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreTsvBase');

sub fetch_input {
    my ($self) 	= @_;

return 0;
}

sub write_output {
    my ($self)  = @_;

    my $exclusion = $self->param('exclusion');
    my $species   = $self->param_required('species');

    if(!grep (/$species/, @$exclusion)){
        $self->dataflow_output_id( { }, 1 );
    }

return 0;
}

sub run {
    my ($self) = @_;

    my $species             = $self->param_required('species');
    my $translation_adaptor = $self->core_dba()->get_TranslationAdaptor();
    my $helper              = $translation_adaptor->dbc()->sql_helper();

    # Query to retrieve all ncoil features
    #  Since the API $t->get_all_ProteinFeatures('ncoils');
    #  Is not returning the correct number of ncoil features
    my $sql_ncoil_pf = q/
SELECT protein_feature_id, translation_id, hit_name, protein_feature.seq_end from protein_feature 
JOIN translation using (translation_id)
JOIN transcript using (transcript_id)
JOIN seq_region using (seq_region_id)
JOIN coord_system using (coord_system_id)
where hit_name="Coil" and species_id=?/;

    # Query to remove protein_features fro ncoil analysis, which ends beyond the length of the translation     
    my $to_del = [];
    my $translation_lengths = {};
    $helper->execute_no_return( -SQL => $sql_ncoil_pf, -PARAMS=>[$translation_adaptor->species_id()],
				-CALLBACK => sub {
				  my ($pf_id, $t_id, $hit_name, $seq_end) = @{shift @_};
				  my $length = $translation_lengths->{$t_id};
				  if(!defined $length) {
				    my $translation = $translation_adaptor->fetch_by_dbID($t_id);
				    $length = $translation->length();
				    $translation_lengths->{$t_id} = $length;
				  }
				  if($seq_end > $length){
				    print "$pf_id lies beyond the end of $t_id\n";
				    push @$to_del, $pf_id;
				  }
				}				
			      );
    
    print "Found ".scalar(@$to_del)." bad features\n";
    my $sql_del_feat = 'DELETE FROM protein_feature WHERE protein_feature_id in (';
    my $it = natatime 1000, @$to_del;
    while (my @vals = $it->())
      {	
	my $sql = $sql_del_feat . join(',',@vals) . ')';
	die $sql;
	$helper->execute_update(-SQL=>$sql);
      }
    

    $translation_adaptor->dbc->disconnect_if_idle();

return;
}


1;


