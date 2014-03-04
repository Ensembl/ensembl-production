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


=pod

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 
=cut

package Bio::EnsEMBL::EGPipeline::Common::Dumper;

use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw/assert_ref check_ref/;
use Bio::EnsEMBL::Utils::IO::FASTASerializer;

sub new {
	my ( $class, @args ) = @_;
	my $self = bless( {}, ref($class) || $class );
	( $self->{width}, $self->{chunk}, $self->{header}, $self->{repeat_libs}, $self->{soft_mask}, $self->{cutoff} ) =
	  rearrange( [ 'WIDTH', 'CHUNK', 'HEADER', 'REPEAT_LIBS', 'SOFT_MASK', 'CUTOFF' ], @args );

	$self->{header} ||= sub {
		my $slice = shift;

		if ( check_ref( $slice, 'Bio::EnsEMBL::Slice' ) ) {
			my $id = $slice->seq_region_name;
			return "$id";
		} else {
			# must be a Bio::Seq , or we're doomed
			return $slice->display_id;
		}
	};
	return $self;
}

sub dump_toplevel {
	my ( $self, $dba, $file_name ) = @_;

	# Default is 0, ie no length cutoff
	my $length_cutoff = $self->{cutoff} || 0;
	
	warn("Using $length_cutoff bp as a cutoff\n");
	
	$file_name ||= $dba->species() . '.fa';
	open my $filehandle, '>', $file_name
	  or throw "Could not open $file_name for writing";
	my $serializer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new( $filehandle,
							  $self->{header}, $self->{chunk}, $self->{width} );
	for my $slice ( @{ $dba->get_SliceAdaptor()->fetch_all('toplevel') } ) {
	    if ($slice->length() >= $length_cutoff) {
		# add repeat masking here
		if(defined $self->{repeat_libs}) {
			$slice = $slice->get_repeatmasked_seq($self->{repeat_libs}, $self->{soft_mask});
		}
		$serializer->print_Seq($slice);
	    }
	}
	$filehandle->close();
	return $file_name;
}

1;
