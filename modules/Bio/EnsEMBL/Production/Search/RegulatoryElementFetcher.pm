
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

  Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher 

=head1 SYNOPSIS

my $fetcher = Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher->new();
my $genome = $fetcher->fetch_regulatory_elements($dba);

=head1 DESCRIPTION

Module for fetching probes and rendering as hashes

=cut

package Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher;

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

sub fetch_regulatory_elements {
	my ( $self, $name ) = @_;
	my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $name, 'funcgen' );
	croak "Could not find database adaptor for $name" unless defined $dba;
	return $self->fetch_regulatory_elements_for_dba($dba);
}

sub fetch_regulatory_elements_for_dba {
	my ( $self, $dba ) = @_;
	my $elems = [];

	my $h = $dba->dbc()->sql_helper();

	$h->execute_no_return(
		-SQL => 
          q/select 
      rf.stable_id as id, 
      sr.name as seq_region_name, 
      (rf.seq_region_start - rf.bound_start_length) as start, 
      (rf.seq_region_end + rf.bound_end_length) as end, 
      ft.name as feature_name,
      'RegulatoryFeature' as type
    from 
      regulatory_feature rf
      join seq_region sr using (seq_region_id)
      join feature_type ft using (feature_type_id)
     JOIN coord_system cs ON (cs.coord_system_id=sr.coord_system_id  AND sr.schema_build=cs.schema_build)
    where
      cs.is_current=1
      /,-USE_HASHREFS => 1,
		-CALLBACK => sub {
			my $feature = shift @_;
			push @$elems, $feature;
			return;
		} );
	

	$h->execute_no_return(
		-SQL => q/ 
     select 
      concat('external_feature_',ef.external_feature_id) as id, 
      sr.name as seq_region_name, 
      ef.seq_region_start as start, 
      ef.seq_region_end as end, 
      ef.display_label as feature_name, 
      ft.name as feature_type,
      ft.description as description, 
      ft.class as class, 
      fs.name as set_name,
      'RegulatoryFactor'  as type
    from  
      external_feature ef
      join feature_type ft using (feature_type_id)
      join feature_set fs using (feature_set_id)
      join seq_region sr using (seq_region_id)
     JOIN coord_system cs ON (cs.coord_system_id=sr.coord_system_id AND sr.schema_build=cs.schema_build)
    where
      cs.is_current = 1
      /,
      -USE_HASHREFS => 1,
		-CALLBACK => sub {
			my $f = shift @_;
			return if ( $f->{feature_name} =~ /FANTOM/ );

			for my $id ( split ',', $f->{set_name} ) {
				push @{ $f->{synonyms} }, $id
				  unless $id eq 'display_label';
			}

			push @$elems, $f;
			return;
		} );
	
	$h->execute_no_return(
		-SQL => q/
		select concat('mirna_target_feature_',mrf.mirna_target_feature_id) as id,
  mrf.display_label as name, 
  mrf.accession as accession, 
  mrf.method as method,
  mrf.evidence as evidence,
  mrf.supporting_information as supporting_information,
  sr.name as seq_region_name,
   mrf.seq_region_start as start, 
      mrf.seq_region_end as end, 
      mrf.display_label as feature_name, 
  ft.name as feature_name, 
          ft.description as description, 
          ft.class as class, 
          fs.name as set_name,
          'TarBase miRNA' as type
     from mirna_target_feature mrf
     JOIN feature_type ft USING (feature_type_id)
     JOIN feature_set fs USING (feature_set_id)
     JOIN seq_region sr USING (seq_region_id)
     JOIN coord_system cs ON (cs.coord_system_id=sr.coord_system_id AND sr.schema_build=cs.schema_build)
    WHERE cs.is_current = 1
      /,
      -USE_HASHREFS => 1,
		-CALLBACK => sub {
			my $f = shift @_;
			return if ( $f->{feature_name} =~ /FANTOM/ );
			push @$elems, $f;
			return;
		} );

	return $elems;
} ## end sub fetch_regulatory_elements_for_dba

1;
