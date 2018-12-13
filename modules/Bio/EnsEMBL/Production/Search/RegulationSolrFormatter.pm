
=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Search::RegulationSolrFormatter;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use List::MoreUtils qw/natatime/;

use Bio::EnsEMBL::Production::Search::JSONReformatter;
use Bio::EnsEMBL::Production::Search::SolrFormatter;

use JSON;
use Carp;
use File::Slurp;

use base qw/Bio::EnsEMBL::Production::Search::SolrFormatter/;
sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  return $self;
}

sub reformat_regulatory_features {
		my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'funcgen';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($f)  = @_;
			return undef if defined $f->{set_name} && $f->{set_name} =~ m/FANTOM/;				
			my $desc;
			my $url;
			if($f->{type} eq 'TarBase miRNA') {
				$desc = sprintf("%s is a %s from %s which hits the genome in %d locations", $f->{name},$f->{class}, $f->{set_name}, scalar(@{$f->{locations}}) );
				$url = sprintf("%s/Location/Genome?ftype=RegulatoryFactor;id=%s;fset=TarBase miRNA",$genome->{organism}->{url_name},
					  $f->{id}, $f->{set_name});
			} else {				
				$desc = sprintf("%s regulatory feature",$f->{feature_name});
				$url = sprintf(
					  "%s/Regulation/Summary?rf=%s",
					  $genome->{organism}->{url_name},
					  $f->{id} );
			}
			return {
				  %{ _base( $genome, $type, 'RegulatoryFeature' ) },
				  id          => $f->{id},
				  description => $desc,
				  domain_url =>
					$url };
		}
		);
	return;
}

sub reformat_probes {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'funcgen';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($probe) = @_;
			my $desc = sprintf( "%s probe %s (%s array)",
								$probe->{array_vendor},
								$probe->{name}, $probe->{array_chip} );
			if ( !_array_nonempty( $probe->{locations} ) ) {
				$desc .= " does not hit the genome";
			}
			else {
				$desc .= " hits the genome in " .
				  scalar( @{ $probe->{locations} } ) . " location(s).";
				if ( _array_nonempty( $probe->{transcripts} ) ) {
					my $gene;
					my @transcripts = map {
						$gene = $_->{gene_name} || $_->{gene_id}
						  unless defined $gene;
						$_->{id}
					} @{ $probe->{transcripts} };
					$desc .=
					  " It hits transcripts in the following gene: $gene (" .
					  join( ", ", @transcripts ) . ")";
				}
			}
			return {
				  %{ _base( $genome, $type, 'OligoProbe' ) },
				  id          => $probe->{id},
				  description => $desc,
				  domain_url =>
					sprintf(
					  "%s/Location/Genome?fdb=funcgen;ftype=ProbeFeature;id=%s",
					  $genome->{organism}->{url_name},
					  $probe->{id} ) };
		} );

	return;
} ## end sub reformat_probes

sub reformat_probesets {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'funcgen';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($probeset)  = @_;
			my $transcripts = {};
			my $locations   = [];
			for my $probe ( @{ $probeset->{probes} } ) {
				$locations = [ @$locations, @{ $probe->{locations} } ];
				if ( defined $probe->{transcripts} ) {
					for my $transcript ( @{ $probe->{transcripts} } ) {
						$transcripts->{ $transcript->{id} } = $transcript;
					}
				}
			}
			my $desc = sprintf( "%s probeset %s (%s array)",
								$probeset->{array_vendor},
								$probeset->{name}, $probeset->{array_chip} );
			if ( !_array_nonempty($locations) ) {
				$desc .= " has no probes that hit the genome";
			}
			else {
				$desc .= " hits the genome in " .
				  scalar( @{$locations} ) . " location(s).";
				if ( scalar( keys %$transcripts )>0 ) {
					my $gene;
					my @transcript_names = map {
						$gene = $_->{gene_name} || $_->{gene_id}
						  unless defined $gene;
						$_->{id}
					} values %{$transcripts};
					$desc .=
					  " They hit transcripts in the following gene: $gene (" .
					  join( ", ", sort @transcript_names ) . ")";
				}
			}
			return {
				%{ _base( $genome, $type, 'OligoProbe' ) },
				id          => $probeset->{id},
				description => $desc,
				domain_url =>
				  sprintf(
"%s/Location/Genome?fdb=funcgen;ftype=ProbeFeature;id=%s;ptype=pset",
					$genome->{organism}->{url_name},
					$probeset->{id} ) };
		} );

	return;
} ## end sub reformat_probesets

1;
