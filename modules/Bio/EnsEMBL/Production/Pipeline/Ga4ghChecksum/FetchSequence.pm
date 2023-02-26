=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::FetchSequence

=head1 DESCRIPTION

Fetch the toplevel genomic sequences  chromosomes, super contigs  and other sequence cDNA, CDS and Peptide


=over 8 

=item 1 - Fetch Toplevel sequences

=item 2 - Fetch cDNA, CDS and Peptide sequences

=back

The script is responsible for genomic sequences for given sequence type

Allowed parameters are:

=over 8

=item species - The species to fetch the genomic sequence

=item sequence_type - The data to cetch. T<toplevel>, I<dna>, I<cdna> and I<pep> are allowed

=item release - A required parameter for the version of Ensembl we are dumping for

=item db_types - Array reference of the database groups to use. Defaults to core

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::FetchSequence;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub param_defaults {
  my ($self) = @_;
  return {
  };
}

sub fetch_input {
  my ($self) = @_;
  #my %sequence_types = map { $_ => 1 } @{ $self->param('sequence_type') };
  #$self->param('sequence_types', \%sequence_types);
  my $type = $self->param('group');
  my $sequence_types = $self->param('sequence_types');
  my $hash_types = $self->param('hash_types');
  my %flow = (
    'toplevel' => 2,
    'cdna'     => 3,
    'cds'      => 4,
    'pep'      => 5
  );

  $self->param('flow', \%flow);
  if(defined $sequence_types){
    my @temp_array = grep ( !/toplevel/,  @{$sequence_types});	 
    @{$sequence_types} = grep ( /toplevel/,  @{$sequence_types});
    push @{$sequence_types}, \@temp_array; 
  }else{	  
    $sequence_types = ['toplevel', ['cdna', 'cds', 'pep'] ] 
  }	
  $hash_types = ['sha512', 'md5'] unless $hash_types;
  $self->param('group',  $type);
  $self->param('sequence_types',  $sequence_types);
  $self->param('hash_types',  $hash_types);
  return;
}

sub run {
  my ($self) = @_;
  my $type = $self->param('group');
  my $dba = $self->get_DBAdaptor($type);
  if(! $dba) {
    $self->info("Cannot find adaptor for type %s", $type);
    next;
  }
  my  $sequence_types = $self->param('sequence_types');
  my $slice_adaptor = $dba->get_SliceAdaptor();
  my @slices = @{ $slice_adaptor->fetch_all( 'toplevel', undef, 1, undef, undef ) };
  my $flow = $self->param('flow');  
  foreach my $seq_type (@{$sequence_types}){
    $self->prepare_flow_data($slice_adaptor, $seq_type);
  }	  
	    
}

sub prepare_flow_data {
   my ($self, $slice_adaptor, $seq_type ) = @_;
   my $flow = $self->param('flow');
   my @slices = @{ $slice_adaptor->fetch_all( 'toplevel', undef, 1, undef, undef ) };
   foreach my $slice (@slices) {
     my $flow_data = { 'species' => $self->param('species'),
            'cs_name' => $slice->coord_system()->name(),
            'seq_region_id' => $slice->get_seq_region_id(),
            'seq_type'      => $seq_type,
            'hash_types'    => $self->param('hash_types')
        };
     if($seq_type eq 'toplevel'){
       #$flow_data->{'seq'} = $slice->seq();
       $self->dataflow_output_id($flow_data, $flow->{$seq_type});
     }else{
       #get all transcript from slice
       my @transcripts = @{$slice->get_all_Transcripts()};
       foreach my $transcript  (@transcripts){
	 foreach my $trans_seq_type (@$seq_type){  
	   $flow_data->{'transcript_id'} = $transcript->stable_id;
           $flow_data->{'seq_type'} = $trans_seq_type;
	   $flow_data->{'transcript_dbid'} = $transcript->dbID();
	   my $translation_ad = $transcript->translation();
	   if( $trans_seq_type eq 'pep' ){
	      if( defined $translation_ad ){
	        $flow_data->{'translation_dbid'} = $translation_ad->dbID() ;
	        $self->dataflow_output_id($flow_data, $flow->{$trans_seq_type});	
	      }	      
           }else{
	     $self->dataflow_output_id($flow_data, $flow->{$trans_seq_type});
           }  
         }
       }
     }
   }
}


1;

