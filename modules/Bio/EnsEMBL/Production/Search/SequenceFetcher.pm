
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

  Bio::EnsEMBL::Production::Search::GenomeFetcher 

=head1 SYNOPSIS

my $fetcher = Bio::EnsEMBL::Production::Search::GenomeFetcher->new();
my $genome = $fetcher->fetch_genome("homo_sapiens");

=head1 DESCRIPTION

Module for rendering a genomic metadata object as a hash

=cut

package Bio::EnsEMBL::Production::Search::SequenceFetcher;

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
	( $self->{name_order} ) = rearrange( ['NAME_ORDER'] );
	if ( !defined $self->{name_order} ) {
		$self->{name_order} = [ 'name',       'well_name',
								'clone_name', 'sanger_project',
								'synonym',    'embl_acc' ];
	}
	return $self;
}

sub fetch_sequences {
	my ( $self, $name ) = @_;
	$logger->debug("Fetching DBA for $name");
	my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $name, 'core' );
	croak "Could not find database adaptor for $name" unless defined $dba;
	return $self->fetch_sequences_for_dba($dba);
}

sub fetch_sequences_for_dba {

	my ( $self, $dba ) = @_;

	my $misc_features = $self->_fetch_misc_features($dba);

	my $main_seqs = $self->_fetch_seq_regions($dba);

	return [ @{$misc_features}, @{$main_seqs} ];

}

sub _fetch_seq_regions {
	my ( $self, $dba ) = @_;

	my $helper     = $dba->dbc()->sql_helper();
	my $species_id = $dba->species_id();

	my $current_cs_id = 0;

	#identify current default top level
	my $current_cs_ids = $helper->execute_simple(
		-SQL => qq/
       SELECT cs.coord_system_id
         FROM coord_system cs
         JOIN meta m USING (species_id)
        WHERE cs.version = m.meta_value
          AND cs.name = 'chromosome'
          AND m.meta_key = 'assembly.default'/ );

	if(scalar(@$current_cs_ids)>0) {
	  $current_cs_id = $current_cs_ids->[0];
	}

	my $patch_hap_dets = $self->_get_patch_hap_dets( $helper, $species_id );	

	#get all seq_regions
	my $seq_regions_by_name = {};
	$helper->execute_no_return(
		-SQL => qq/
       SELECT sr.name, sr.length, cs.name, cs.coord_system_id, srs.synonym
         FROM coord_system as cs, seq_region as sr
         LEFT JOIN seq_region_synonym as srs on sr.seq_region_id = srs.seq_region_id
        WHERE sr.coord_system_id = cs.coord_system_id and cs.species_id=?
        and cs.name<>'lrg'/,
		-PARAMS   => [$species_id],
		-CALLBACK => sub {
			my ( $name, $len, $cs_name, $cs_id, $synonym ) = @{ shift @_ };

			#don't index the supercontig with PATCH name
			return if $cs_name eq 'supercontig' && $patch_hap_dets->{$name};

			#don't index chromosomes from previous assemblies
			return
			  if ( $cs_name eq 'chromosome' ) && ( $cs_id != $current_cs_id );

			my $sr = $seq_regions_by_name->{$name};
			if ( !defined $sr ) {
				$sr = { id       => $name,
						start    => 1,
						end      => $len,
						length   => $len,
						type     => $cs_name,
						synonyms => [] };
				$seq_regions_by_name->{$name} = $sr;
			}

			if ( $patch_hap_dets->{$name} ) {
				$sr->{end}   = $patch_hap_dets->{$name}{end};
				$sr->{start} = $patch_hap_dets->{$name}{start};
				if ( $patch_hap_dets->{$name}{syn} ) {
					push @{ $sr->{synonyms} }, $patch_hap_dets->{$name}{syn}
					  unless $patch_hap_dets->{$name}{syn} eq $synonym;
				}
			}
			push @{ $sr->{synonyms} }, $synonym if defined $synonym;

			return;
		} );
	return [ values %$seq_regions_by_name ];
} ## end sub _fetch_seq_regions

sub _get_patch_hap_dets {
	my ( $self, $helper, $species_id ) = @_;
	my $patch_hap_dets = {};
# get seq_region_synonyms and start / stop positions for patches (ensembl)
#  - requires the supercontig (which has the seq_region_synonym) and the chromosome to have the same name
#  - positions come from assembly_exception table
	$helper->execute_no_return(
		-SQL => qq/
       SELECT sr2.name, srs.synonym, ae.seq_region_start, ae.seq_region_end
         FROM coord_system cs, seq_region sr2, assembly_exception ae, seq_region sr1
            LEFT JOIN seq_region_synonym srs ON sr1.seq_region_id = srs.seq_region_id
       WHERE sr1.name = sr2.name
         AND sr1.coord_system_id != sr2.coord_system_id
         AND sr1.coord_system_id = cs.coord_system_id
         AND sr2.seq_region_id = ae.seq_region_id
         AND cs.species_id=?/,
		-CALLBACK => sub {
			my ( $name, $grc_name, $start, $end ) = @{ shift @_ };
			$patch_hap_dets->{$name} = { 'name'  => $name,
										 'syn'   => $grc_name,
										 'start' => $start,
										 'end'   => $end, };
			return;
		},
		-PARAMS => [$species_id] );

	#haplotypes
	$helper->execute_no_return(
		-SQL => qq/
       SELECT sr.name, ae.seq_region_start, ae.seq_region_end
         FROM assembly_exception ae 
         JOIN seq_region sr USING (seq_region_id)
         JOIN coord_system cs USING (coord_system_id)
        WHERE ae.exc_type = 'HAP' and species_id=?/,
		-PARAMS   => [$species_id],
		-CALLBACK => sub {

			my ( $name, $start, $end ) = @{ shift @_ };
			$patch_hap_dets->{$name} =
			  { 'name' => $name, 'start' => $start, 'end' => $end, };
			return;
		} );
	return $patch_hap_dets;
} ## end sub _get_patch_hap_dets

sub _fetch_misc_features {

	my ( $self, $dba ) = @_;

	my $helper     = $dba->dbc()->sql_helper();
	my $species_id = $dba->species_id();

	my $features = {};

	#get all types of misc features - used for 'type' label
	my $feat_types = $helper->execute_into_hash(
		-SQL => qq/
                  SELECT distinct ms.misc_set_id, ma.value as type
                    FROM attrib_type at
                    JOIN misc_attrib ma USING (attrib_type_id)
                    JOIN misc_feature_misc_set mfms USING (misc_feature_id)
                    JOIN misc_set ms USING (misc_set_id)
                   WHERE at.code = 'type'/ );

	if (%$feat_types) {
		my $mapsets = join ',', keys %$feat_types;
		#get all misc_features#
		$helper->execute_no_return(
			-SQL => qq/
       SELECT mf.misc_feature_id, sr.name, cs.name, mf.seq_region_start, mf.seq_region_end,
              mf.seq_region_end-mf.seq_region_start+1 as len, ms.misc_set_id, at.code, ma.value
         FROM misc_feature_misc_set as ms
              JOIN misc_feature as mf USING (misc_feature_id)
              JOIN seq_region as sr USING (seq_region_id)
              JOIN coord_system as cs USING (coord_system_id)
              JOIN misc_attrib as ma USING (misc_feature_id)
              JOIN attrib_type as at USING (attrib_type_id)
        WHERE
          ms.misc_set_id in ($mapsets)
          AND cs.species_id=?
        ORDER by mf.misc_feature_id, at.code/,
			-PARAMS   => [$species_id],
			-CALLBACK => sub {
				my ( $id,  $sr,    $sr_type, $start, $end,
					 $len, $ms_id, $code,    $val ) = @{ shift @_ };
				my $feature = $features->{$id};
				if ( !defined $feature ) {
					$feature = { id          => $id,
								 start       => $start,
								 end         => $end,
								 length      => $len,
								 parent      => $sr,
								 parent_type => $sr_type,
								 synonyms    => [] };
					$features->{$id} = $feature;
				}

				push @{ $feature->{synonyms} }, [ $code, $val ];

## the type is mixed in with other attribs so look for the first type attrib we find
				if ( !defined $feature->{type} && $code eq 'type' ) {
					my $ftype = $feat_types->{$ms_id};
					#some hacks for the display of the type
					$ftype =~ s/_/ /;
					$ftype =~ s/arrayclone/clone/;
					$ftype = ucfirst($ftype);
					$feature->{type} = $ftype;
				}

				return;
			} );
	} ## end if (%$feat_types)
	 # now all features have been found, some jiggery pokery to set the best name
	return [ map { _set_feature_names( $self, $_ ) } values %$features ];
} ## end sub _fetch_misc_features

sub _set_feature_names {
	my ( $self, $feature ) = @_;
	my $name_to_use;
	# try to find the best name to use using an order of preference
	for my $name_type ( @{ $self->{name_order} } ) {
		unless ($name_to_use) {
			for my $name ( @{ $feature->{synonyms} } ) {
				if ( $name->[0] eq $name_type ) {
					$name_to_use = $name->[1];
				}
			}
		}
	}
	my @synonyms =
	  map { $_->[1] }
	  grep { $_->[1] ne $name_to_use } @{ $feature->{synonyms} };
	$feature->{synonyms} = \@synonyms;
	$feature->{name}     = $name_to_use;
	return $feature;
}

1;
