
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

package Bio::EnsEMBL::Production::Search::LRGFetcher;

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

sub fetch_lrgs {
	my ( $self, $name ) = @_;
	$logger->debug("Fetching DBA for $name");
	my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $name, 'core' );
	croak "Could not find database adaptor for $name" unless defined $dba;
	return $self->fetch_lrgs_for_dba($dba);
}

sub fetch_lrgs_for_dba {

	my ( $self, $dba ) = @_;

	my $lrgs = {};

	$dba->dbc()->sql_helper()->execute_no_return(
		-SQL => qq/
			SELECT g.stable_id, x.display_label, edb.db_name, t.stable_id, sr.length
             FROM gene g
             JOIN analysis a ON (g.analysis_id=a.analysis_id)
             JOIN object_xref ox ON (g.gene_id = ox.ensembl_id)
             JOIN xref x USING (xref_id)
             JOIN external_db edb USING (external_db_id)
             JOIN transcript t USING (gene_id)
             JOIN seq_region sr ON (sr.name=g.stable_id)
             JOIN coord_system cs USING (coord_system_id)
            WHERE 
            	ox.ensembl_object_type = 'Gene'
              AND edb.db_name = 'HGNC'
              AND a.logic_name = 'LRG_import'
              AND cs.species_id = ?/,
		-PARAMS   => [ $dba->species_id() ],
		-CALLBACK => sub {
			my ( $id, $gene, $gene_db, $transcript_id, $len ) = @{ shift @_ };
			my $lrg = $lrgs->{$id};
			if ( !defined $lrg ) {
				$lrg = { id              => $id,
						 length          => $len,
						 source_gene     => $gene,
						 source_database => $gene_db,
						 transcripts     => [] };
				$lrgs->{$id} = $lrg;
			}
			push @{ $lrg->{transcripts} }, $transcript_id;
			return;
		} );

	return [ values %$lrgs ];

} ## end sub fetch_lrgs_for_dba

1;
