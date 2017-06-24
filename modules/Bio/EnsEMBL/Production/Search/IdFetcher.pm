
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Search::IdFetcher;

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

sub fetch_ids {
	my ( $self, $name ) = @_;
	$logger->debug("Fetching DBA for $name");
	my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $name, 'core' );
	croak "Could not find database adaptor for $name" unless defined $dba;
	return $self->fetch_ids_for_dba($dba);
}

sub fetch_ids_for_dba {

	my ( $self, $dba ) = @_;

	my $ids = [];

	my $helper             = $dba->dbc()->sql_helper();
	my $species_id         = $dba->species_id();
	my $types              = [ 'gene', 'transcript', 'translation' ];
	my $current_stable_ids = {};
	for my $type (@$types) {
		$current_stable_ids->{$type} =
		  $helper->execute_into_hash( -SQL => "select stable_id,1 from $type" );
	}

	my $mapping = {};
	$helper->execute_no_return(
		-SQL =>
q/SELECT sie.type, sie.old_stable_id, if(isnull(sie.new_stable_id),'NULL',sie.new_stable_id),
           ms.old_release*1.0 as X, ms.new_release*1.0 as Y
      FROM $dbname.mapping_session as ms, $dbname.stable_id_event as sie
     WHERE ms.mapping_session_id = sie.mapping_session_id 
       AND ( old_stable_id != new_stable_id or isnull(new_stable_id) )
     ORDER by Y desc, X desc/,
		-CALLBACK => sub {
			my ( $type, $osi, $nsi, $old_release, $new_release ) =
			  @{ shift @_ };
			return
			  if $current_stable_ids->{$type}
			  {$osi};    ## Don't want to show current stable IDs.
			return if $osi eq $nsi;    ##
			   #if the mapped ID is current set it as an example, as long as it's post release 62
			if ( !$mapping->{$type}{$osi}{'example'} && $new_release > 62 ) {
				if ( $current_stable_ids->{$type}{$nsi} ) {
					$mapping->{$type}{$osi}{'example'} = $nsi;
				}
			}
			$mapping->{$type}{$osi}{'matches'}{$nsi}++;
		} );

	my $other_count = 0;
	foreach my $type ( keys %$mapping ) {
		foreach my $osi ( keys %{ $mapping->{$type} } ) {
			my @current_sis    = ();
			my @deprecated_sis = ();
			my $desc;
			foreach my $nsi ( keys %{ $mapping->{$type}{$osi}{'matches'} } ) {
				if ( $current_stable_ids->{$type}{$nsi} ) {
					push @current_sis, $nsi;
				}
				elsif ( $_ ne 'NULL' ) {
					push @deprecated_sis, $nsi;
				}
			}
			if (@current_sis) {
				$other_count++;
				my $example_id   = $mapping->{$type}{$osi}{'example'};
				my $current_id_c = scalar(@current_sis);
				my $cur_txt =
				  $current_id_c > 1 ? "$current_id_c current identifiers" :
				                      "$current_id_c current identifier";
				$cur_txt .= $example_id ? " (eg $example_id)" : '';
				$desc = qq(Ensembl $type $osi is no longer in the database.);
				my $deprecated_id_c = scalar(@deprecated_sis);
				if ($deprecated_id_c) {
					my $dep_txt =
					  $deprecated_id_c > 1 ?
					  "$deprecated_id_c deprecated identifiers" :
					  "$deprecated_id_c deprecated identifier";
					$desc .= " It has been mapped to $dep_txt";
					$desc .= $current_id_c ? " and $cur_txt." : '.';
				}
				elsif ($current_id_c) {
					$desc .= "It has been mapped to $cur_txt.";
				}
			}
			elsif (@deprecated_sis) {
				$other_count++;
				my $deprecated_id_c = scalar(@deprecated_sis);
				my $id = $deprecated_id_c > 1 ? 'identifiers' : 'identifier';
				$desc =
qq(Ensembl $type $osi is no longer in the database but it has been mapped to $deprecated_id_c deprecated $id.);
			}
			else {
				$other_count++;
				$desc =
qq(Ensembl $type $osi is no longer in the database and has not been mapped to any newer identifiers.);
			}
			push @$ids, {
				id                  => $osi,
				description         => $desc,
				current_mappings    => \@current_sis,
				deprecated_mappings => \@deprecated_sis };
		} ## end foreach my $osi ( keys %{ $mapping...})
	} ## end foreach my $type ( keys %$mapping)
	return $ids;
} ## end sub fetch_ids_for_dba

1;
