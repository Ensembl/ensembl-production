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

 Bio::EnsEMBL::Production::Pipeline::GVF::BatchSeqRegions;

=head1 DESCRIPTION

=head1 MAINTAINER 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::GVF::BatchSeqRegions;

use Mouse;

has 'min_bases_per_batch'        => (is => 'rw', isa => 'Int', default => 1_000_000 );
has 'max_length_seq_region_name' => (is => 'rw', isa => 'Int', default => 200 );

sub batch_slices {
    my $self     = shift;

    my $param    = shift;
    my $slices   = $param->{slices};
    my $callback = $param->{callback};
    confess('Type error!') unless(ref $slices eq 'ARRAY');
    confess('Type error!') unless(ref $callback eq 'CODE');

    my $bases_in_current_batch = 0;
    my $sum_of_length_of_seq_region_names_in_current_batch = 0;
    my $current_batch = [];

    foreach my $slice (@$slices) {

	confess('Type error!') unless ($slice->isa('Bio::EnsEMBL::Slice'));

	my $seq_region_id     = $slice->get_seq_region_id();
	my $seq_region_name   = $slice->seq_region_name();
	my $seq_region_length = $slice->seq_region_length();

	my $length_of_name = length($seq_region_name);

	my $current_seq_region = {
	    seq_region_id     => $seq_region_id,
	    seq_region_name   => $seq_region_name,
	    seq_region_length => $seq_region_length
	};

	use Hash::Util qw( lock_hash );
	lock_hash(%$current_seq_region);

	push @$current_batch, $current_seq_region;

	$bases_in_current_batch += $seq_region_length;
	$sum_of_length_of_seq_region_names_in_current_batch+=$length_of_name;

	my $base_threshold_reached = $bases_in_current_batch>$self->min_bases_per_batch;
	my $name_length_threshold_reached
	    = $sum_of_length_of_seq_region_names_in_current_batch
		>
		$self->max_length_seq_region_name;
	
	if ($base_threshold_reached || $name_length_threshold_reached)  {

	    $callback->($current_batch);

	    $current_batch = [];
	    $bases_in_current_batch = 0;
	    $sum_of_length_of_seq_region_names_in_current_batch=0;
	}
    }
}

1;
