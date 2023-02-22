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

my $DNA_INDEXING_FLOW = 1;
my $PEPTIDE_INDEXING_FLOW = 2;
my $GENE_INDEXING_FLOW = 3;
my $CDS_INDEXING_FLOW = 4;

sub param_defaults {
  my ($self) = @_;
  return {
    #user configurable
    allow_appending => 1,
    overwrite_files => 0,
    
    dna_chunk_size => 17000,
    
    skip_logic_names => [],
    process_logic_names => [],
    
    #DON'T MESS
    #used to track if we need to reopen a file in append mode or not
    generated_files => {}, 
    remove_files_from_dir => {},
    dataflows => [],
    process_logic_active => 0,
    skip_logic_active => 0,
  };
}

sub fetch_input {
  my ($self) = @_;
  #my %sequence_types = map { $_ => 1 } @{ $self->param('sequence_type') };
  #$self->param('sequence_types', \%sequence_types);
  my $types = $self->param('db_types');
  $types = ['core'] unless $types;
  $self->param('db_types', $types);

  return;
}

sub run {
  my ($self) = @_;
  #my $types = $self->param('db_types');
  my $type = 'core';
  my $dba = $self->get_DBAdaptor($type);
    if(! $dba) {
      $self->info("Cannot continue with %s as we cannot find a DBAdaptor", $type);
      next;
    }
    #get all toplevel sequences
    #my ($chr, $non_chr, $non_ref) = $self->get_slices($dba);
    #$self->print_to_file($chr, 'chr', $sm_filename, '>', $repeat_analyses);
    my $sa = $dba->get_SliceAdaptor();
    my @slices = @{ $sa->fetch_all( 'toplevel', undef, 1, undef, undef ) };
    foreach my $slice (@slices) {
	    #print($slice->seq());
      print($dba->dbc->dbname,"\n");
      print($slice->coord_system()->name(), "\n");
      print($slice->seq_region_name(), "\n");
    }
#   foreach my $type (@{$types}) {
    



#     #https://www.ensembl.org/info/docs/api/core/core_tutorial.html#genes
#     ## The spliced_seq() method returns the concatenation of the exon
#     # sequences. This is the cDNA of the transcript
#     #print "cDNA: ", $transcript->spliced_seq(), "\n";

# # The translateable_seq() method returns only the CDS of the transcript
# #print "CDS: ", $transcript->translateable_seq(), "\n";

#     #$self->run_type($type);
# #     my $transcript_adaptor =
# #   $registry->get_adaptor( 'Human', 'Core', 'Transcript' );
# # my $transcript = $transcript_adaptor->fetch_by_stable_id($stable_id);

# # print $transcript->translation()->stable_id(), "\n";
# # print $transcript->translate()->seq(),         "\n";

# # print $transcript->translation()->transcript()->stable_id(), "\n";


#   }
  return;
}



1;

