
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

package Bio::EnsEMBL::Production::Search::GenomeFetcher;

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
	my ( $metadata_dba, $eg, $compara, $funcgen ) = rearrange( [ 'METADATA_DBA', 'EG'], @args );
	if ( !defined $metadata_dba ) {
		eval {
		$metadata_dba =
		  Bio::EnsEMBL::Registry->get_DBAdaptor( "multi", "metadata" );
		};
		if($@) {
			$logger->warn("Cannot find metadata database");
		}
	}
	if ( defined $metadata_dba ) {
		$self->{info_adaptor} = $metadata_dba->get_GenomeInfoAdaptor();
		if ( defined $eg ) {
			# switch adaptor to use Ensembl Genomes if -EG supplied
			$logger->debug("Using EG release");
			$self->{info_adaptor}->set_ensembl_genomes_release();
		}
	}
	return $self;
}

sub fetch_genome {
	my ( $self, $name ) = @_;
	my $md = $self->fetch_metadata($name);
	croak "Could not find genome $name" unless defined $md;
	return $self->metadata_to_hash($md);
}

sub fetch_metadata {
	my ( $self, $name ) = @_;
	$logger->debug("Fetching metadata for genome $name");
	croak "No metadata DB adaptor found" unless defined $self->{info_adaptor};
	return $self->{info_adaptor}->fetch_by_name($name);
}

sub metadata_to_hash {
	my ( $self, $md ) = @_;
	croak "No metadata supplied" unless defined $md;
	return { id           => $md->name(),
			 dbname       => $md->dbname(),
			 species_id   => $md->species_id(),
			 division     => $md->division(),
			 genebuild    => $md->genebuild(),
			 is_reference => $md->is_reference() == 1 ? "true" : "false",
			 organism     => {
						   name                => $md->name(),
						   display_name        => $md->display_name(),
						   scientific_name     => $md->scientific_name(),
						   url_name            => $md->url_name(),
						   strain              => $md->strain(),
						   serotype            => $md->serotype(),
						   taxonomy_id         => $md->taxonomy_id(),
						   species_taxonomy_id => $md->species_taxonomy_id(),
						   aliases             => $md->aliases() },
			 assembly => { name      => $md->assembly_name(),
						   accession => $md->assembly_accession(),
						   level     => $md->assembly_level() } };
}

1;
