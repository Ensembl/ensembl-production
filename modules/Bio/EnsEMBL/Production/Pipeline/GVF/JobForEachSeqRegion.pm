=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::GVF::JobForEachSeqRegion;

=head1 DESCRIPTION

=head1 MAINTAINER 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::GVF::JobForEachSeqRegion;

use strict;
use Data::Dumper;
use Hash::Util qw( lock_hash );
#use base ('EGVar::FTP::RunnableDB::GVF::Base');
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub run {
    my $self = shift @_;

    my $species  = $self->param('species');
    my $division = $self->param('division'),
    my $gvf_type = $self->param('gvf_type');
    confess('Type error!') unless (ref $gvf_type eq 'ARRAY');

    my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor( $species, 'Core', 'Slice' );
    confess('Type error!') unless ($slice_adaptor->isa('Bio::EnsEMBL::DBSQL::SliceAdaptor'));

    # Fetch all toplevel sequences.
    # This may consume a lot of memory, so if there are memory issues, they
    # are likely to be here.
    print "\nFetching all toplevel slices.\n" if($self->debug);
    my $slices = $slice_adaptor->fetch_all('toplevel', undef, 1);
    print "\nDone fetching all toplevel slices. Got ".@$slices." slices.\n" if($self->debug);

    use Bio::EnsEMBL::Production::Pipeline::GVF::BatchSeqRegions;
    my $batch_seq_regions = Bio::EnsEMBL::Production::Pipeline::GVF::BatchSeqRegions->new();

    my @batch_to_dump;

    my $callback = sub {
	my $batch = shift;
	# We can't create the jobs here right away, because they rely on the
	# gvf_species and gvf_merge tables. In order to create these tables 
	# we need to know the total number of files and a species id.
	#
	# So the batches are collected here first and dump jobs are created
	# at the end.
	push @batch_to_dump, $batch;
    };

    print "\nCreating batches.\n" if($self->debug);

    $batch_seq_regions->batch_slices({
	slices   => $slices,
	callback => $callback
    });
    print "\nDone creating batches.\n" if($self->debug);

    #
    # Write to gvf_species table
    #
    my $job_parameters = {
	    species     => $species,
	    total_files => scalar @batch_to_dump,
	    division    => $division,
    };

    print "\nFlowing to gvf_species table:\n" . Dumper($job_parameters) if($self->debug);

    $self->dataflow_output_id($job_parameters, 3);
    my $species_entry = $self->fetch_species($species);
    my $species_id    = $species_entry->{species_id};

    #
    # Write to gvf_merge table
    #
    foreach my $current_gvf_type (@$gvf_type) {
	my $job_parameters = {
		species_id  => $species_id,
		type        => $current_gvf_type,
		created     => undef,
	};

	if ($self->debug) {
	    print "\nWriting gvf_merge entry for '$current_gvf_type':\n";
	    print Dumper($job_parameters);
	}
	$self->dataflow_output_id($job_parameters, 4);
    }
    print "\nDone writing gvf_merge entries.\n" if($self->debug);

    #
    # Create the dump jobs.
    #
    # Important:
    # The jobs we create here rely on data being in the
    # gvf_merge merge table. Therefore the jobs must be
    # created only after the loop above has run.
    foreach my $current_batch_to_dump (@batch_to_dump) {
	foreach my $current_gvf_type (@$gvf_type) {
	    #
	    # Create job to dump this batch of seq regions in the specified
	    # gvf_type.
	    #
	    $self->dataflow_output_id( {
		batch    => $current_batch_to_dump,
		species  => $species,
		gvf_type => $current_gvf_type,
	    }, 2);
	}
    }
}

#### TODO: Can move to GVF/Base.pm

=head1 fetch_species

Returns a has for the species like this:

$VAR1 = {
          'total_files' => '13',
          'species' => 'plasmodium_falciparum',
          'species_id' => '1'
        };

=cut
sub fetch_species {
    my $self = shift;
    my $species_name = shift;

    my $adaptor = $self->db->get_NakedTableAdaptor();
    $adaptor->table_name( 'gvf_species' );
    my $hash = $adaptor->fetch_by_species( $species_name );
    lock_hash(%$hash);

return $hash;
}

1;
