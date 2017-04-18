
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

	my ( $self->{name_order} ) = rearrange( ['NAME_ORDER'] );

	if ( !defined $self->{name_order} ) {
		$self->name_order = [ 'name',       'well_name',
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

	return [@{$misc_features},@{$main_seqs}];
	
}

sub _fetch_seq_regions {
	my ( $self, $dba ) = @_;

	my $helper     = $dba->dbc()->sql_helper();
	my $species_id = $dba->dbc()->species_id();

	#identify current default top level
	my $current_cs_id = $helper->execute_single_result(
		-SQL => qq/
       SELECT cs.coord_system_id
         FROM coord_system cs
         JOIN meta m USING (species_id)
        WHERE cs.version = m.meta_value
          AND cs.name = 'chromosome'
          AND m.meta_key = 'assembly.default'/ );

	my $patch_hap_dets = $self->_get_patch_hap_dets( $helper, $species_id );

	#get all seq_regions
	my $seq_regions_by_name = {};
	$helper->execute_no_return(
		-SQL => qq/
       SELECT sr.name, sr.length, cs.name, cs.coord_system_id, srs.synonym
         FROM coord_system as cs, seq_region as sr
         LEFT JOIN seq_region_synonym as srs on sr.seq_region_id = srs.seq_region_id
        WHERE sr.coord_system_id = cs.coord_system_id and cs.species_id=?
        and cs.name<>'lrg'/
		  -PARAMS => [$species_id],
		-CALLBACK => sub {
			my ( $name, $len, $cs_name, $cs_id, $synonym ) = @{ shift @_ };

			#don't index the supercontig with PATCH name
			return if $type eq 'supercontig' && $patch_hap_dets->{$name};

			#don't index chromosomes from previous assemblies
			return if ( $type eq 'chromosome' ) && ( $cs_id != $current_cs_id );

			my $sr = $seq_regions_by_name->{$name};
			if ( defined $sr ) {
				push @{ $sr->{synonyms} }, $synonym;
			}
			else {

				$sr = { id       => $name,
						start    => $1,
						end      => $len,
						length   => $len,
						type     => $type,
						synonyms => [$synonym] };

				if ( $patch_hap_dets->{$name} ) {
					$seq_region->{end}   = $patch_hap_dets{$name}{end};
					$seq_region->{start} = $patch_hap_dets{$name}{start};
					if ( $patch_hap_dets->{$name}{syn} ) {
						push @{ $sr->{synonyms} }, $patch_hap_dets->{$name}{syn}
						  unless $patch_hap_dets->{$old_name}{syn} eq $synonym
					);
				}
			}

			$seq_regions_by_name->{$name} = $sr;
		}
		return;
		};
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

sub _fetch_lrgs {
	my ( $self, $dba ) = @_;
	 my $conf = shift;
  return $conf->{'dbh'}->selectall_arrayref(
        qq(SELECT g.stable_id, g.seq_region_start,g.seq_region_end, x.display_label, edb.db_name, t.stable_id, sr.length
             FROM gene g, analysis a, object_xref ox, xref x, external_db edb, transcript t, seq_region sr
            WHERE g.analysis_id = a.analysis_id
              AND g.gene_id = ox.ensembl_id
              AND ox.xref_id = x.xref_id
              AND x.external_db_id = edb.external_db_id
              AND g.gene_id = t.gene_id
              AND g.stable_id = sr.name
              AND ox.ensembl_object_type = 'Gene'
              AND edb.db_name = 'HGNC'
              AND a.logic_name = 'LRG_import'
            ORDER by g.stable_id, t.stable_id)
      );
}

sub sort_lrgs {
  my ($dbspecies,$type,$fh,$lrgs) = @_;
  my ($prev_gsi,$prev_disp_label,$prev_db_name,$prev_length);
  my $query_terms = [];
  foreach my $rec (@$lrgs) {
    my $gsi = $rec->[0];
    if ($gsi eq $prev_gsi) {
      push @$query_terms, $rec->[3];
    }
    else {
      if ($prev_gsi) {
        &p(LRGLine($dbspecies,$type,$prev_gsi,$prev_disp_label,$prev_db_name,$query_terms,$prev_length),
           $fh);
      }
      $prev_gsi        = $gsi;
      $prev_disp_label = $rec->[1];
      $prev_db_name    = $rec->[2];
      $query_terms     = [ $rec->[3] ];
      $prev_length     = $rec->[4];
    }
  }
}

sub LRGLine {
  my ($species,$type,$gsi,$dbkey,$dbname,$tsids,$length) = @_;
  my $url = sprintf(qq(%s/LRG/Summary?lrg=%s),
                    $species,
                    $gsi);
  $species =~ s/_/ /;
  my $description = "$gsi is a fixed reference sequence of length $length with a fixed transcript(s) for reporting purposes. It was created for $dbname gene $dbkey";
  my $xml = qq(
<doc>
  <field name="id">$gsi</field>
  <field name="description">$description</field>);
  $xml .= qq(
  <field name="xrefs">$dbkey</field>);
  foreach my $tsi (@$tsids) {
    $xml .= qq(
  <field name="transcript">$tsi</field>);
  }
  $xml .= &common_fields($species,$type,'core');
  $xml .= qq(
  <field name="domain_url">$url</field>
</doc>);
  return $xml
}

my $lrg = {
	id=>$id,
	type=>'lrg',
	start=>$start,
	end=>$end,
length=>$len,
parent=>$gene	
};

	return [];
}

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
		#get all misc_features
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
					 $len, $ms_id, $code,    $val )
				  = @( shift @_ );
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

			push $feature->synonyms( [ $code, $val ] );

# the type is mixed in with other attribs so look for the first type attrib we find
			  if ( !defined $feature->{type} && $code eq 'type' ) {
				my $ftype = $feat_types->{$ms_id}{'type'};
				#some hacks for the display of the type
				$ftype =~ s/_/ /;
				$ftype =~ s/arrayclone/clone/;
				$ftype = ucfirst($ftype);
				$feature->{type} = $ftype;
			}

			return;
			} );
	}
	 # now all features have been found, some jiggery pokery to set the best name
	return [ map { _set_feature_names($_) } values %$features ];
} ## end sub _fetch_misc_features

sub _set_feature_names {
	  my ($feature) = @_;
	  my $name_to_use;
	  # try to find the best name to use using an order of preference
	  for my $name_type ( @{ $self->{name_order} } ) {
		  unless ($name_to_use) {
			  foreach my $name (
				  @{ $feature->{synonyms} )
				  {
					  if ( $name->[0] eq $name_type ) {
						  $name_to_use = $name->[1];
					  }
				  }
				  };
		  }
	  }
	  my @synonyms =
		map { $_->[1] } grep { $_->[1] ne $name_to_use } $feature->{synonyms};
	  $feature->{synonyms} = \@synonyms;
	  $feature->{name}     = $name_to_use;
	  return $feature;
}

1;
