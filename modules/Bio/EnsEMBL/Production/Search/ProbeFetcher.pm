
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

Module for fetching probes and rendering as hashes

=cut

package Bio::EnsEMBL::Production::Search::ProbeFetcher;

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

sub fetch_probes {
	my ( $self, $name ) = @_;
	my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $name, 'funcgen' );
	croak "Could not find database adaptor for $name" unless defined $dba;
	my $core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $name, 'core' );
	return $self->fetch_probes_for_dba( $dba, $core_dba );
}

sub fetch_probes_for_dba {
	my ( $self, $dba, $core_dba ) = @_;

	my $all_probes = {};

	#	my $probe_set_transcripts = {};
	#	$dba->dbc()->sql_helper()->execute_no_return(
	#		-SQL => q/select probe_set_id, stable_id from probe_set_transcript/,
	#		-CALLBACK => sub {
	#			my $row = shift @_;
	#			$probe_set_transcripts->{ $row->[0] } = $transcripts->{ $row->[1] };
	#			return;
	#		} );

#		  my $species = $dba->species();
#		  # probe sets
#		  $dba->dbc()->sql_helper()->execute_no_return(
#			-SQL => q/SELECT
#      ps.probe_set_id as id,
#	  ps.name as probe_set_name,
#      p.probe_name as probe_name,
#      array_chip.name as array_chip,
#      array.name as array,
#      array.vendor as array_vendor,
#      sr.name as seq_region_name,
#      pf.seq_region_start as start,
#      pf.seq_region_end as end,
#      pf.seq_region_strand as strand
#    FROM
#      probe_set ps
#      join probe p using (probe_set_id)
#      join probe_feature pf using (probe_id)
#      join seq_region sr using (seq_region_id)
#      JOIN coord_system cs ON (cs.coord_system_id=sr.coord_system_id  AND sr.schema_build=cs.schema_build)
#      join array_chip on (probe.array_chip_id=array_chip.array_chip_id)
#      join array using (array_id)
#	WHERE
#		cs.is_current=1/,
#			-USE_HASHREFS => 1,
#			-CALLBACK     => sub {
#				my $row = shift @_;
#				my $id  = $species . '_probeset_' . $row->{id};
#				my $p   = $probes->{$id};
#				if ( !defined $p ) {
#					$p = {%$row};
#					delete $p->{seq_region_name};
#					delete $p->{start};
#					delete $p->{end};
#					delete $p->{strand};
#					$probes->{$id} = $p;
#				}
#				push @{ $p->{locations} }, {
#					seq_region_name => $row->{seq_region_name},
#					start           => $row->{start},
#					end             => $row->{end},
#					strand          => { $row->{strand} } };
#				return;
#			} );
#		  # probes

	my $species = $dba->species();

	my $transcripts = {};
	$core_dba->dbc()->sql_helper()->execute_no_return(
		-SQL => q/select t.stable_id, g.stable_id, x.display_label 
	from transcript t
	join gene g using (gene_id)
	join xref x on (g.display_xref_id=x.xref_id)/,
		-CALLBACK => sub {
			my $row = shift @_;
			my $t = { id => $row->[0], gene_id => $row->[1] };
			$t->{gene_name} = $row->[2] if defined $row->[2];
			$transcripts->{ $row->[0] } = $t;
			return;
		} );

	my $probe_transcripts = {};
	$dba->dbc()->sql_helper()->execute_no_return(
		-SQL =>
		  q/select probe_id, stable_id, description from probe_transcript/,
		-CALLBACK => sub {
			my $row = shift @_;
			$probe_transcripts->{ $row->[0] } =
			  { %{ $transcripts->{ $row->[1] } } };
			$probe_transcripts->{ $row->[0] }->{description} = $row->[2];
			return;
		} );

	# load probes
	my $probes        = {};
	my $probes_by_set = {};
	$dba->dbc()->sql_helper()->execute_no_return(
		-SQL => q/SELECT
      p.probe_id as id,
      p.name as name,
      p.probe_set_id as probe_set_id,
      array_chip.name as array_chip,
      array.name as array,
      array.vendor as array_vendor,
      sr.name as seq_region_name,
      pf.seq_region_start as start,
      pf.seq_region_end as end,
      pf.seq_region_strand as strand
    FROM
      probe p
      join probe_feature pf using (probe_id)
      join seq_region sr using (seq_region_id)
      JOIN coord_system cs ON (cs.coord_system_id=sr.coord_system_id  AND sr.schema_build=cs.schema_build)
      join array_chip on (p.array_chip_id=array_chip.array_chip_id)
      join array using (array_id)
	WHERE
		cs.is_current=1/,
		-USE_HASHREFS => 1,
		-CALLBACK     => sub {
			my $row = shift @_;
			my $id  = $species . '_probe_' . $row->{id};
			my $p   = $probes->{$id};
			if ( !defined $p ) {
				$p = {%$row};
				delete $p->{seq_region_name};
				delete $p->{start};
				delete $p->{end};
				delete $p->{strand};
				delete $p->{probe_set_id};
				$probes->{$id} = $p;
				$probes->{transcripts} = $probe_transcripts->{ $row->{id} };
				push @{ $probes_by_set->{ $row->{probe_set_id} } }, $p;
			}
			push @{ $p->{locations} }, {
						 seq_region_name => $row->{seq_region_name},
						 start           => $row->{start},
						 end             => $row->{end},
						 strand          => { $row->{strand} } };
			return;
		} );
	# probe sets

	return { probes => [ values %{$probes} ] };
} ## end sub fetch_probes_for_dba

1;
