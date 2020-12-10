
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

  Bio::EnsEMBL::Production::Search::GenomeFetcher 

=head1 SYNOPSIS

my $fetcher = Bio::EnsEMBL::Production::Search::GenomeFetcher->new();
my $genome = $fetcher->fetch_genome("homo_sapiens");

=head1 DESCRIPTION

Module for rendering a genomic metadata object as a hash

=cut

package Bio::EnsEMBL::Production::Search::GenomeFetcher;

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
	my ( $metadata_dba, $eg, $taxonomy_dba, $ens_version, $eg_version) =
	  rearrange( [ 'METADATA_DBA', 'EG', 'TAXONOMY_DBA', 'ENS_VERSION', 'EG_VERSION' ], @args );
	if ( !defined $metadata_dba ) {
		eval {
			$metadata_dba =
			  Bio::EnsEMBL::Registry->get_DBAdaptor( "multi", "metadata" );
		};
		if ($@) {
			$logger->warn("Cannot find metadata database");
		}
	}
	if ( !defined $metadata_dba ) {
		eval {
			$metadata_dba =
			  Bio::EnsEMBL::Registry->get_DBAdaptor( "multi", "metadata" );
		};
		if ($@) {
			$logger->warn("Cannot find metadata database");
		}
	}
	if ( !defined $taxonomy_dba ) {
		eval {
			$taxonomy_dba =
			  Bio::EnsEMBL::Registry->get_DBAdaptor( "multi", "taxonomy" );
		};
		if ($@) {
			$logger->warn("Cannot find taxonomy database");
		}
	}
	if ( defined $taxonomy_dba ) {
		$self->{node_adaptor} = $taxonomy_dba->get_TaxonomyNodeAdaptor();
	}
	if ( defined $metadata_dba ) {
		$self->{info_adaptor} = $metadata_dba->get_GenomeInfoAdaptor();
                if( defined $ens_version){
                  $self->{info_adaptor}->set_ensembl_release($ens_version);
                }
		if ( defined $eg ) {
			# switch adaptor to use Ensembl Genomes if -EG supplied
			$logger->debug("Using EG release");
                        if(defined $eg_version){
			  $self->{info_adaptor}->set_ensembl_genomes_release($eg_version);
                        }else{
			  $self->{info_adaptor}->set_ensembl_genomes_release();
                        }
		}

             
	}
	return $self;
} ## end sub new

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
	my $orgs = $self->{info_adaptor}->fetch_by_name($name);
	my $meta = Bio::EnsEMBL::Registry->get_adaptor( $name, 'core', 'MetaContainer' );
	if ( !defined $meta ) {
		croak "Cannot find genome $name";
	}
	my $division = $meta->get_division();
  my $org;
  foreach my $genome (@{$orgs}){
    $org = $genome if ($genome->division() eq $division);
  }
	return $org;
}

sub metadata_to_hash {
	my ( $self, $md ) = @_;
	croak "No metadata supplied" unless defined $md;
	my $genome = {
		   id              => $md->name(),
		   dbname          => $md->dbname(),
		   species_id      => $md->species_id(),
		   division        => $md->division(),
		   genebuild       => $md->genebuild(),
		   reference    => $md->reference(),
		   has_pan_compara => $md->has_pan_compara() == 1 ? "true" : "false",
		   has_peptide_compara => $md->has_peptide_compara() == 1 ? "true" :
			 "false",
		   has_synteny => $md->has_synteny() == 1 ? "true" : "false",
		   has_genome_alignments => $md->has_genome_alignments() == 1 ? "true" :
			 "false",
		   has_other_alignments => $md->has_other_alignments() == 1 ? "true" :
			 "false",
		   has_variations => $md->has_variations() == 1 ? "true" : "false",
		   organism => { name                => $md->name(),
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
						 default   => $md->assembly_default(),
						 ucsc      => $md->assembly_ucsc(),
						 level     => $md->assembly_level() } };
	if ( defined $self->{node_adaptor} ) {
		$genome->{organism}->{lineage} = [
			grep {$_ ne 'root'} map {
				$_->names()->{'scientific name'}->[0]
				} @{ $self->{node_adaptor}->fetch_ancestors( $md->taxonomy_id() )
				} ];
	}
	return $genome;
} ## end sub metadata_to_hash

1;
