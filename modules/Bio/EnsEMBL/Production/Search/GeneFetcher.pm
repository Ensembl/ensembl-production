
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

  Bio::EnsEMBL::Production::Search::GeneFetcher

=head1 SYNOPSIS


=head1 DESCRIPTION

  Module to fetch genes for a given DBA or named genome (if registry has been loaded)

=cut

package Bio::EnsEMBL::Production::Search::GeneFetcher;

use strict;
use warnings;

use Carp qw/croak/;
use Log::Log4perl qw/get_logger/;

use Bio::EnsEMBL::Production::DBSQL::BulkFetcher;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

my $logger = get_logger();

sub new {
	my ( $class, @args ) = @_;
	my $self = bless( {}, ref($class) || $class );

	$self->{fetcher} =
	  Bio::EnsEMBL::Production::DBSQL::BulkFetcher->new(
													-LEVEL => 'protein_feature',
													-LOAD_EXONS => 1,
													-LOAD_XREFS => 1 );
	return $self;
}

sub fetch_genes {
	my ( $self, $name, $compara_name, $type, $use_pan_compara ) = @_;
	$logger->debug("Fetching DBA for $name");
	$type ||= 'core';
	my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $name, $type );
	croak "Could not find database adaptor for $name" unless defined $dba;
	if ( $type eq 'core' ) {
		my $funcgen_dba; 
    my $compara_dba;
    my $pan_compara_dba;
    $funcgen_dba =
		  Bio::EnsEMBL::Registry->get_DBAdaptor( $name, 'funcgen' );
    $compara_dba = 
      Bio::EnsEMBL::Registry->get_DBAdaptor( $compara_name, 'compara' )
		  if defined $compara_name;
		$pan_compara_dba =
      Bio::EnsEMBL::Registry->get_DBAdaptor( 'pan_homology', 'compara' )
      if $use_pan_compara;
    return $self->fetch_genes_for_dba( $dba, $compara_dba, $funcgen_dba, $pan_compara_dba );
	}
	else {
		return $self->fetch_genes_for_dba($dba);
	}
}

sub fetch_genes_for_dba {
	my ( $self, $dba, $compara_dba, $funcgen_dba, $pan_compara_dba ) = @_;
	$logger->debug( "Retrieving genes for " . $dba->species() );
	$dba->dbc()->db_handle()->{mysql_use_result} = 1;
	my @genes =
	  grep { _include_gene($_) } @{ $self->{fetcher}->export_genes($dba) };
	$self->{fetcher}->add_funcgen( \@genes, $funcgen_dba )
	  if defined $funcgen_dba;
	$self->{fetcher}->add_compara( $dba->species(), \@genes, $compara_dba )
	  if defined $compara_dba;
  $self->{fetcher}->add_pan_compara( $dba->species(), \@genes, $pan_compara_dba )
    if defined $pan_compara_dba;
	return \@genes;
}

sub _include_gene {
	my $gene = shift;
	# exclude LRGs as they are not "proper" genes
	return lc $gene->{biotype} ne 'lrg';
}

1;
