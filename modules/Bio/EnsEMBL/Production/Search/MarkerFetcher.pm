
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

  Bio::EnsEMBL::Production::Search::GenomeFetcher 

=head1 SYNOPSIS

my $fetcher = Bio::EnsEMBL::Production::Search::GenomeFetcher->new();
my $genome = $fetcher->fetch_genome("homo_sapiens");

=head1 DESCRIPTION


Module for rendering a genomic metadata object as a hash

=cut

package Bio::EnsEMBL::Production::Search::MarkerFetcher;

use base qw/Bio::EnsEMBL::Production::Search::BaseFetcher/;

use strict;
use warnings;

use Log::Log4perl qw/get_logger/;
use Carp qw/croak/;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

my $logger = get_logger();

sub new {
	my ( $class, @args ) = @_;
	my $self = bless( {}, ref($class) || $class );

	return $self;
}

sub fetch_markers {
	my ( $self, $name ) = @_;
	$logger->debug("Fetching DBA for $name");
	my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $name, 'core' );
	croak "Could not find database adaptor for $name" unless defined $dba;
	return $self->fetch_markers_for_dba($dba);
}

sub fetch_markers_for_dba {

	my ( $self, $dba ) = @_;

	my $markers = {};

	$dba->dbc()->sql_helper()->execute_no_return(
		-SQL => qq/
		  SELECT m.marker_id, ms2.name, ms1.name, sr.name, mf.seq_region_start, mf.seq_region_end
     FROM marker_synonym ms1
     JOIN marker m USING (marker_id)
     JOIN marker_feature mf USING (marker_id)
     JOIN seq_region sr USING (seq_region_id)
     JOIN coord_system cs USING (coord_system_id)
     LEFT JOIN marker_synonym ms2 USING (marker_synonym_id)
     WHERE cs.species_id=?/,
		-PARAMS   => [ $dba->species_id() ],
		-CALLBACK => sub {
			my ( $id, $name, $synonym, $seq, $start, $end ) =
			  @{ shift @_ };
			my $marker = $markers->{$id};
			if ( !defined $marker ) {
				$marker = { id         => $id,
							name       => $name,
							seq_region => $seq,
							start      => $start,
							end        => $end,
							synonyms   => [] };
				$markers->{$id} = $marker;
			}
			push @{ $marker->{synonyms} }, $synonym
			  if defined $synonym && $synonym ne $marker->{name};
			return;
		} );

	return [ values %$markers ];

} ## end sub fetch_markers_for_dba

1;
