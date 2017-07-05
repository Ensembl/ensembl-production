
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

  Bio::EnsEMBL::Production::Search::GeneFetcher

=head1 SYNOPSIS


=head1 DESCRIPTION

  Module to fetch variants for a given DBA or named genome

=cut

package Bio::EnsEMBL::Production::Search::VariationFetcher;

use strict;
use warnings;

use Carp qw/croak/;
use Log::Log4perl qw/get_logger/;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

my $logger = get_logger();

sub new {
	my ( $class, @args ) = @_;
	my $self = bless( {}, ref($class) || $class );
	return $self;
}

sub fetch_variations {
	my ( $self, $name, $offset, $length ) = @_;
	$logger->debug("Fetching DBA for $name");
	my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $name, 'variation' );
	my $onto_dba = Bio::EnsEMBL::Registry->get_DBAdaptor( 'multi', 'ontology' );
	return $self->fetch_variations_for_dba( $dba, $onto_dba );
}

sub fetch_variations_for_dba {
	my ( $self, $dba, $onto_dba, $offset, $length ) = @_;
	my @variants = ();
	$self->fetch_variations_callback(
		$dba,
		$onto_dba,
		$offset, $length,
		sub {
			my ($variant) = @_;
			push @variants, $variant;
			return;
		} );
	return \@variants;
}

sub fetch_variations_callback {
	my ( $self, $dba, $onto_dba, $offset, $length, $callback ) = @_;
	$dba->dbc()->db_handle()->{mysql_use_result} = 1;    # streaming
	my $h = $dba->dbc()->sql_helper();

	# global data
	my $gwas    = $self->_fetch_all_gwas($h);
	my $sources = $self->_fetch_all_sources($h);
	my ($dbsnp) = grep { $_->{name} eq 'dbSNP' } values %{$sources};

	# slice data
	my ( $min, $max ) = $self->_calculate_min_max( $h, $offset, $length );
	my $features = $self->_fetch_features( $h, $min, $max );
	my $hgvs = $self->_fetch_hgvs( $h, $min, $max );
	my $subsnps = $self->_fetch_subsnps( $h, $min, $max );
	my $synonyms = $self->_fetch_synonyms( $h, $min, $max, $sources );
	my $genenames = $self->_fetch_genenames( $h, $min, $max );
	my $phenotypes =
	  $self->_fetch_phenotype_features( $h, $onto_dba, $min, $max );
	my $failures = $self->_fetch_failed_descriptions( $h, $min, $max );
	$h->execute_no_return(
		-SQL =>
q/SELECT v.variation_id as id, v.name as name, v.source_id as source_id, v.somatic as somatic
      FROM variation v WHERE variation_id BETWEEN ? and ?/,
		-PARAMS       => [ $min, $max ],
		-USE_HASHREFS => 1,
		-CALLBACK     => sub {
			my $var = shift;
			_add_key( $var, 'source',     $sources,    $var->{source_id} );
			_add_key( $var, 'gwas',       $gwas,       $var->{name} );
			_add_key( $var, 'phenotypes', $phenotypes, $var->{id} );
			_add_key( $var, 'hgvs',       $hgvs,       $var->{id} );
			_add_key( $var, 'locations',  $features,   $var->{id} );
			_add_key( $var, 'synonyms',   $synonyms,   $var->{id} );
			_add_key( $var, 'gene_names', $genenames,  $var->{id} );
			_add_key( $var, 'failures',   $failures,   $var->{id} );
			my $ssids = $subsnps->{ $var->{id} };

			if ( defined $ssids ) {
				for my $ssid (@$ssids) {
					push @{ $var->{synonyms} },
					  { name => $ssid, source => $dbsnp };
				}
			}
			$var->{somatic} = $var->{somatic} == 1 ? 'true' : 'false';
			delete $var->{source_id};
			$var->{id} = $var->{name};
			delete $var->{name};
			$callback->($var);
			return;
		} );
	return;
} ## end sub fetch_variations_callback

sub fetch_phenotypes {
	my ( $self, $name ) = @_;
		$logger->debug("Fetching DBA for $name");
	my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $name, 'variation' );
	my $onto_dba = Bio::EnsEMBL::Registry->get_DBAdaptor( 'multi', 'ontology' );
	return $self->fetch_phenotypes_for_dba( $dba, $onto_dba );
	}
	
sub fetch_phenotypes_for_dba {
	my ( $self, $dba, $onto_dba ) = @_;
	return [values %{$self->_fetch_all_phenotypes($dba->dbc()->sql_helper(), $onto_dba)}];
} ## end sub _fetch_all_phenotypes

sub _calculate_min_max {
	my ( $self, $h, $offset, $length ) = @_;
	if ( !defined $offset ) {
		$offset = $h->execute_single_result(
						   -SQL => q/select min(variation_id) from variation/ );
	}
	if ( !defined $length ) {
		$length = ( $h->execute_single_result(
							  -SQL => q/select max(variation_id) from variation/
					) ) - $offset + 1;
	}
	$logger->debug("Calculating $offset/$length");
	my $max = $offset + $length - 1;

	$logger->debug("Current ID range $offset -> $max");
	return ( $offset, $max );
}

sub _fetch_hgvs {
	my ( $self, $h, $min, $max ) = @_;
	$logger->debug("Fetching HGVS for $min/$max");
	return $h->execute_into_hash(
		-SQL =>
q/SELECT h.variation_id, h.hgvs_name                                                                                                                                                                                  
       FROM variation_hgvs h WHERE variation_id between ? and ?/,
		-PARAMS   => [ $min, $max ],
		-CALLBACK => sub {
			my ( $row, $value ) = @_;
			$value = [] if !defined $value;
			push( @{$value}, $row->[1] );
			return $value;
		} );
}

sub _fetch_subsnps {
	my ( $self, $h, $min, $max ) = @_;
	my $cnt = $h->execute_single_result(
		-SQL =>
"select count(*) from information_schema.tables where table_name=? and table_schema=?",
		-PARAMS => [ 'subsnp_map', $h->db_connection()->dbname() ] );
	if ( $cnt == 1 ) {
		$logger->debug("Fetching subsnps for $min/$max");
		return $h->execute_into_hash(
			-SQL =>
q/SELECT variation_id, concat('ss',subsnp_id)                                                                                                                                                                                  
       FROM subsnp_map WHERE variation_id between ? and ?/,
			-PARAMS   => [ $min, $max ],
			-CALLBACK => sub {
				my ( $row, $value ) = @_;
				$value = [] if !defined $value;
				push( @{$value}, $row->[1] );
				return $value;
			} );
	}
	else {
		return {};
	}
}

sub _fetch_synonyms {
	my ( $self, $h, $min, $max, $sources ) = @_;
	$logger->debug("Fetching synonyms for $min/$max");
	return $h->execute_into_hash(
		-SQL => q/SELECT 
		variation_id, source_id, name
     FROM variation_synonym
     WHERE variation_id between ? AND ?/,
		-PARAMS   => [ $min, $max ],
		-CALLBACK => sub {
			my ( $row, $value ) = @_;
			$value = [] if !defined $value;
			my $synonym = { name => $row->[2] };
			_add_key( $synonym, 'source', $sources, $row->[1] );
			push( @{$value}, $synonym );
			return $value;
		} );
}

sub _fetch_phenotype_features {
	my ( $self, $h, $onto_dba, $min, $max ) = @_;
	# only query if we have data to avoid nulls
	my $pfs = $h->execute_simple(
		-SQL => q/select pf.object_id 
from phenotype_feature pf
where pf.type = 'Variation' and pf.is_significant = 1
LIMIT 1/ );
	if ( scalar(@$pfs) == 0 ) {
		$logger->debug("No phenotype features found");
		return {};
	}
	$logger->debug("Fetching phenotypes for $min/$max");
	my $phenotypes = $self->_fetch_all_phenotypes( $h, $onto_dba );
	my $sources    = $self->_fetch_all_sources($h);
	my $studies    = $self->_fetch_all_studies($h);
	my $sql        = q/SELECT 
		v.variation_id, 
		pf.phenotype_id,
		pf.study_id,
		pf.source_id,
		group_concat( distinct ag.value SEPARATOR ';') AS gn,
        group_concat( distinct av.value SEPARATOR ';') AS vars
     FROM variation v
     JOIN phenotype_feature pf ON (v.name=pf.object_id)
     LEFT JOIN ( phenotype_feature_attrib AS ag 
                 join attrib_type AS at1 on (ag.attrib_type_id = at1.attrib_type_id and at1.code = 'associated_gene' ))
           USING (phenotype_feature_id)
     LEFT JOIN ( phenotype_feature_attrib AS av 
                 join attrib_type AS at2 on (av.attrib_type_id = at2.attrib_type_id and at2.code = 'variation_names' ))
           USING (phenotype_feature_id)          
     WHERE 
     v.variation_id is not null 
     AND v.variation_id between ? AND ?
     AND pf.type = 'Variation'
     AND pf.is_significant = 1/;
	return $h->execute_into_hash(
		-SQL      => $sql,
		-PARAMS   => [ $min, $max ],
		-CALLBACK => sub {
			my ( $row, $value ) = @_;
			$value = [] if !defined $value;			
			my $phenotype = $phenotypes->{$row->[1]} || {};
			my $pf = {%{$phenotype}};
			_add_key( $pf, 'study',     $studies,    $row->[2] );
			_add_key( $pf, 'source',    $sources,    $row->[3] );
			push @$value, $pf;
			return $value;
		} );
} ## end sub _fetch_phenotype_features

sub _fetch_features {
	my ( $self, $h, $min, $max ) = @_;
	$logger->debug(" Fetching consequences for $min/$max ");
	my $consequences = $h->execute_into_hash(
		-SQL => q/SELECT 
		tv.variation_feature_id, tv.feature_stable_id, tv.consequence_types, 
		tv.polyphen_prediction, tv.polyphen_score,
		tv.sift_prediction, tv.sift_score
     FROM 
     transcript_variation tv
     JOIN variation_feature vf USING (variation_feature_id)
     WHERE 
     vf.variation_id between ? AND ?/,
		-PARAMS   => [ $min, $max ],
		-CALLBACK => sub {
			my ( $row, $value ) = @_;
			$value = [] if !defined $value;
			my $con = { stable_id => $row->[1], consequence => $row->[2] };
			$con->{polyphen} = $row->[3]
			  if defined $row->[3] && $row->[3] ne '';
			$con->{polyphen_score} = $row->[4]
			  if defined $row->[4] && $row->[4] != 0;
			$con->{sift} = $row->[5] if defined $row->[5] && $row->[5] ne '';
			$con->{sift_score} = $row->[6]
			  if defined $row->[6] && $row->[6] != 0;
			push( @{$value}, $con );
			return $value;
		} );

	$logger->debug(" Fetching features for $min/$max ");
	return $h->execute_into_hash(
		-SQL => q/SELECT 
		vf.variation_id, sr.name, vf.seq_region_start, vf.seq_region_end, vf.seq_region_strand, vf.variation_feature_id
     FROM variation_feature vf
     JOIN seq_region sr USING (seq_region_id)
     WHERE vf.variation_id between ? AND ?/,
		-PARAMS   => [ $min, $max ],
		-CALLBACK => sub {
			my ( $row, $value ) = @_;
			$value = [] if !defined $value;
			my $var = { seq_region_name => $row->[1],
						start           => $row->[2],
						end             => $row->[3],
						strand          => $row->[4] };
			my $consequence = $consequences->{ $row->[5] };
			$var->{consequences} = $consequence if defined $consequence;
			push( @{$value}, $var );
			return $value;
		} );
} ## end sub _fetch_features

sub _fetch_genenames {
	my ( $self, $h, $min, $max ) = @_;
	$logger->debug(" Fetching gene names for $min/$max ");
	return $h->execute_into_hash(
		-SQL => q/SELECT variation_id, gene_name
       FROM variation_genename
     WHERE variation_id between ? AND ?/,
		-PARAMS   => [ $min, $max ],
		-CALLBACK => sub {
			my ( $row, $value ) = @_;
			$value = [] if !defined $value;
			push( @{$value}, $row->[1] );
			return $value;
		} );
}

sub _fetch_failed_descriptions {
	my ( $self, $h, $min, $max ) = @_;
	$logger->debug(" Fetching failed descriptions for $min/$max ");
	return $h->execute_into_hash(
		-SQL => q/SELECT fv.variation_id, fd.description
       FROM failed_variation fv
       JOIN failed_description fd USING (failed_description_id)
     WHERE fv.variation_id between ? AND ?/,
		-PARAMS   => [ $min, $max ],
		-CALLBACK => sub {
			my ( $row, $value ) = @_;
			$value = [] if !defined $value;
			push( @{$value}, $row->[1] );
			return $value;
		} );
}

sub _fetch_all_studies {
	my ( $self, $h ) = @_;
	if ( !defined $self->{studies} ) {
		my $studies = $h->execute_into_hash(
			-SQL =>
			  q/select study_id, name, description, study_type from study/,
			-CALLBACK => sub {
				my ( $row, $value ) = @_;
				$value = { name        => $row->[2],
						   description => $row->[3],
						   type        => $row->[4] };
				return $value;
			} );

		$h->execute_no_return(
			-SQL      => q/select study1_id, study2_id from associate_study/,
			-CALLBACK => sub {
				my ( $sid1, $sid2 ) = @{ shift @_ };
				my $s1 = $studies->{$sid1};
				my $s2 = $studies->{$sid2};
				if ( defined $s1 && defined $s2 ) {
					push @{ $s1->{associated_studies} }, $s2;
				}
				return;
			} );
		$self->{studies} = $studies;
	} ## end if ( !defined $self->{...})
	return $self->{studies};
} ## end sub _fetch_all_studies

sub _fetch_all_phenotypes {
	my ( $self, $h, $onto_dba ) = @_;
	if ( !defined $self->{phenotypes} ) {
		$self->{phenotypes} = $h->execute_into_hash(
			-SQL =>
q/SELECT phenotype_id, stable_id, name, description, poa.accession as accession
			FROM phenotype
	        LEFT JOIN phenotype_ontology_accession poa USING (phenotype_id)/,
			-CALLBACK => sub {
				my ( $row, $value ) = @_;
				my $doc = { stable_id   => $row->[1],
							name        => $row->[2],
							description => $row->[3], };
				if ( defined $row->[4] ) {
					$doc->{ontology_accession} = $row->[4];

					$onto_dba->dbc()->sql_helper()->execute_no_return(
						-SQL => q/select t.name, o.name, s.name
					  from term t
					join ontology o using (ontology_id)
					left join synonym s using (term_id)
					where t.accession=?/,
						-PARAMS   => [ $row->[4] ],
						-CALLBACK => sub {
							my ($t) = @_;
							$doc->{ontology_term} = $t->[0];
							$doc->{ontology_name} = $t->[1];
							push @{ $doc->{ontology_synonyms} }, $t->[2]
							  if defined $t->[2];
							return;
						} );
				}
				return $doc;
			} );
	}
	return $self->{phenotypes};
} ## end sub _fetch_all_phenotypes

sub _fetch_all_gwas {
	my ( $self, $h, $min, $max ) = @_;
	if ( !defined $self->{gwas} ) {
		$logger->debug("Fetching GWAS");
		$self->{gwas} = $h->execute_into_hash(
			-SQL => q/SELECT distinct pf.object_id as name, s.name as source
       FROM phenotype_feature pf
       JOIN source s USING (source_id)
      WHERE pf.is_significant = 1
        AND s.name like "%GWAS%"/,
			-CALLBACK => sub {
				my ( $row, $value ) = @_;
				$value = [] if !defined $value;
				push( @{$value}, $row->[1] );
				return $value;
			} );
	}
	return $self->{gwas};
}

sub _fetch_all_sources {
	my ( $self, $h ) = @_;
	if ( !defined $self->{sources} ) {
		$logger->debug("Fetching sources");
		$self->{sources} = $h->execute_into_hash(
			-SQL      => q/SELECT source_id, name, version from source/,
			-CALLBACK => sub {
				my ( $row, $value ) = @_;
				return { name => $row->[1], version => $row->[2] };
			} );
	}
	return $self->{sources};
}

sub _add_key {
	my ( $obj, $k, $h, $v ) = @_;
	if ( defined $v ) {
		my $o = $h->{$v};
		$obj->{$k} = $o if defined $o;
	}
	return;

}

1;
