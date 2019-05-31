=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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
  my ($class, @args) = @_;
  my $self = bless({}, ref($class) || $class);
  return $self;
}

sub fetch_variations {
  my ($self, $name, $offset, $length) = @_;
  $logger->debug("Fetching DBA for $name");
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($name, 'variation');
  my $onto_dba = Bio::EnsEMBL::Registry->get_DBAdaptor('multi', 'ontology');
  return $self->fetch_variations_for_dba($dba, $onto_dba);
}

sub fetch_variations_for_dba {
  my ($self, $dba, $onto_dba, $offset, $length) = @_;
  my @variants = ();
  $self->fetch_variations_callback(
      $dba,
      $onto_dba,
      $offset, $length,
      sub {
        my ($variant) = @_;
        push @variants, $variant;
        return;
      });
  return \@variants;
}

sub fetch_variations_callback {
  my ($self, $dba, $onto_dba, $offset, $length, $callback) = @_;
  $dba->dbc()->db_handle()->{mysql_use_result} = 1; # streaming
  my $h = $dba->dbc()->sql_helper();

  # global data
  my $gwas = $self->_fetch_all_gwas($h);
  my $sources = $self->_fetch_all_sources($h);
  my ($dbsnp) = grep {$_->{name} eq 'dbSNP'} values %{$sources};

  # slice data
  my ($min, $max) = $self->_calculate_min_max($h, $offset, $length);
  my $features = $self->_fetch_features($h, $onto_dba, $min, $max);
  my $hgvs = $self->_fetch_hgvs($h, $min, $max);
  my $sets = $self->_fetch_sets($h, $min, $max);
  my $citations = $self->_fetch_citations($h, $min, $max);
  my $synonyms = $self->_fetch_synonyms($h, $min, $max, $sources);
  my $genenames = $self->_fetch_genenames($h, $min, $max);
  my $phenotypes =
      $self->_fetch_phenotype_features($h, $onto_dba, $min, $max);
  my $failures = $self->_fetch_failed_descriptions($h, $min, $max);

  my $evidence_attribs = $h->execute_into_hash(
      -SQL => q/select attrib_id, value
  from attrib 
  join attrib_type using (attrib_type_id) 
  where code='evidence'/);

  my $class_attribs = $h->execute_into_hash(
      -SQL => q/select attrib_id, value
  from attrib 
  join attrib_type using (attrib_type_id) 
  where code='SO_term'/);

  $h->execute_no_return(
      -SQL          => q/
        SELECT  v.variation_id as id,
                v.name as name,
                v.class_attrib_id as class,
                v.source_id as source_id,
                v.somatic as somatic,
                v.minor_allele_freq as minor_allele_freq,
                v.minor_allele as minor_allele,
                v.minor_allele_count as minor_allele_count,
                vf.ancestral_allele as ancestral_allele,
                v.evidence_attribs as evidence_attribs,
                v.clinical_significance as clinical_significance
        FROM variation v
         LEFT JOIN variation_feature vf using (variation_id)
        WHERE variation_id BETWEEN ? and ?/,
      -PARAMS       => [ $min, $max ],
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my $var = shift;
        _add_key($var, 'source', $sources, $var->{source_id});
        _add_key($var, 'gwas', $gwas, $var->{name});
        _add_key($var, 'phenotypes', $phenotypes, $var->{id});
        _add_key($var, 'hgvs', $hgvs, $var->{id});
        _add_key($var, 'sets', $sets, $var->{id});
        _add_key($var, 'citations', $citations, $var->{id});
        _add_key($var, 'locations', $features, $var->{id});
        _add_key($var, 'synonyms', $synonyms, $var->{id});
        _add_key($var, 'gene_names', $genenames, $var->{id});
        _add_key($var, 'failures', $failures, $var->{id});

        if (defined $var->{evidence_attribs}) {
          for my $e (split(',', $var->{evidence_attribs})) {
            push @{$var->{evidence}}, $evidence_attribs->{$e};
          }
          delete $var->{evidence_attribs};
        }
        $var->{somatic} = $var->{somatic} == 1 ? 'true' : 'false';
        $var->{class} = $class_attribs->{$var->{class}};
        if (defined $var->{clinical_significance}) {
          $var->{clinical_significance} = [ split ',', $var->{clinical_significance} ];
        }
        else {
          delete $var->{clinical_significance};
        }
        delete $var->{source_id};
        _clean_keys($var);
        $var->{id} = $var->{name};
        delete $var->{name};
        _clean_keys($var);
        $callback->($var);
        return;
      });
  return;
} ## end sub fetch_variations_callback

sub fetch_phenotypes {
  my ($self, $name) = @_;
  $logger->debug("Fetching DBA for $name");
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($name, 'variation');
  my $onto_dba = Bio::EnsEMBL::Registry->get_DBAdaptor('multi', 'ontology');
  return $self->fetch_phenotypes_for_dba($dba, $onto_dba);
}

sub fetch_phenotypes_for_dba {
  my ($self, $dba, $onto_dba) = @_;
  return [
      values
          %{$self->_fetch_all_phenotypes($dba->dbc()->sql_helper(), $onto_dba)}
  ];
}

sub fetch_structural_variations {
  my ($self, $name, $offset, $length) = @_;
  $logger->debug("Fetching DBA for $name");
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($name, 'variation');
  my $onto_dba = Bio::EnsEMBL::Registry->get_DBAdaptor('multi', 'ontology');
  return $self->fetch_structural_variations_for_dba($dba);
}

sub fetch_structural_variations_for_dba {
  my ($self, $dba, $offset, $length) = @_;
  my @variants = ();
  $self->fetch_structural_variations_callback(
      $dba, $offset, $length,
      sub {
        my ($variant) = @_;
        push @variants, $variant;
        return;
      });
  return \@variants;
}

sub fetch_structural_variations_callback {
  my ($self, $dba, $offset, $length, $callback) = @_;
  # slice data
  $dba->dbc()->db_handle()->{mysql_use_result} = 1; # streaming
  my $h = $dba->dbc()->sql_helper();
  my ($min, $max) =
      $self->_calculate_min_max($h, $offset, $length, 'structural_variation',
          'structural_variation_id');
  $h->execute_no_return(
      -SQL          => q/SELECT
           v.variation_name as id,
           s.name as source,
           s.description as source_description,
           st.name as study,
           r.name as seq_region_name,
           vf.seq_region_start as start,
           vf.seq_region_end as end,
           group_concat(ssv.variation_name) as ssv
      FROM structural_variation as v 
        LEFT JOIN study as st ON (st.study_id=v.study_id)
        LEFT JOIN structural_variation_association as sva ON (v.structural_variation_id=sva.structural_variation_id)
        LEFT JOIN structural_variation as ssv ON (ssv.structural_variation_id = sva.supporting_structural_variation_id)
        JOIN source s ON (v.source_id = s.source_id)
        JOIN structural_variation_feature vf ON (v.structural_variation_id = vf.structural_variation_id)
        JOIN seq_region r ON (r.seq_region_id = vf.seq_region_id)
     WHERE 
       v.is_evidence = 0
       AND v.structural_variation_id between ? AND ?
       GROUP BY v.structural_variation_id/,
      -PARAMS       => [ $min, $max ],
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my $var = shift;
        if (defined $var->{ssv}) {
          for my $av (sort split ',', $var->{ssv}) {
            push @{$var->{supporting_evidence}}, $av;
          }
        }
        delete $var->{study} unless defined $var->{study};
        delete $var->{ssv};
        $callback->($var);

        return;
      });
  return;
} ## end sub fetch_structural_variations_callback

sub _calculate_min_max {
  my ($self, $h, $offset, $length, $table, $key) = @_;
  $table ||= 'variation';
  $key ||= 'variation_id';
  if (!defined $offset) {
    $offset =
        $h->execute_single_result(-SQL => qq/select min($key) from $table/);
  }
  if (!defined $length) {
    $length =
        ($h->execute_single_result(-SQL => qq/select max($key) from $table/))
            - $offset + 1;
  }
  $logger->debug("Calculating $offset/$length");
  my $max = $offset + $length - 1;

  $logger->debug("Current ID range $offset -> $max");
  return($offset, $max);
}

sub _fetch_hgvs {
  my ($self, $h, $min, $max) = @_;
  $logger->debug("Fetching HGVS for $min/$max");
  return $h->execute_into_hash(
      -SQL      =>
          q/SELECT h.variation_id, h.hgvs_name
       FROM variation_hgvs h WHERE variation_id between ? and ?/,
      -PARAMS   => [ $min, $max ],
      -CALLBACK => sub {
        my ($row, $value) = @_;
        $value = [] if !defined $value;
        push(@{$value}, $row->[1]);
        return $value;
      });
}

sub _fetch_sets {
  my ($self, $h, $min, $max) = @_;
  $logger->debug("Fetching sets for $min/$max");
  return $h->execute_into_hash(
      -SQL      =>
          q/SELECT vsv.variation_id, vs.name
       FROM variation_set_variation vsv
       JOIN variation_set vs USING (variation_set_id) 
       WHERE vsv.variation_id between ? and ?/,
      -PARAMS   => [ $min, $max ],
      -CALLBACK => sub {
        my ($row, $value) = @_;
        $value = [] if !defined $value;
        push(@{$value}, $row->[1]);
        return $value;
      });
}

sub _fetch_citations {
  my ($self, $h, $min, $max) = @_;
  $logger->debug("Fetching citations for $min/$max");
  return $h->execute_into_hash(
      -SQL      =>
          q/SELECT vc.variation_id, p.pmid, p.title
       FROM variation_citation vc
       JOIN publication p USING (publication_id) 
       WHERE vc.variation_id between ? and ?/,
      -PARAMS   => [ $min, $max ],
      -CALLBACK => sub {
        my ($row, $value) = @_;
        $value = [] if !defined $value;
        my $h = {};
        $h->{pubmed_id} = $row->[1] if defined $row->[1];
        $h->{title} = $row->[2] if defined $row->[2];
        push(@{$value}, $h);
        return $value;
      });
}

sub _fetch_synonyms {
  my ($self, $h, $min, $max, $sources) = @_;
  $logger->debug("Fetching synonyms for $min/$max");
  return $h->execute_into_hash(
      -SQL      => q/SELECT
		variation_id, source_id, name
     FROM variation_synonym
     WHERE variation_id between ? AND ?
     AND source_id NOT IN 
     (select source_id from source WHERE name='dbSNP')/,
      -PARAMS   => [ $min, $max ],
      -CALLBACK => sub {
        my ($row, $value) = @_;
        $value = [] if !defined $value;
        my $synonym = { name => $row->[2] };
        _add_key($synonym, 'source', $sources, $row->[1]);
        push(@{$value}, $synonym);
        return $value;
      });
}

sub _fetch_phenotype_features {
  my ($self, $h, $onto_dba, $min, $max) = @_;
  # only query if we have data to avoid nulls
  my $pfs = $h->execute_simple(
      -SQL => q/select pf.object_id
from phenotype_feature pf
where pf.type = 'Variation' and pf.is_significant = 1
LIMIT 1/);
  if (scalar(@$pfs) == 0) {
    $logger->debug("No phenotype features found");
    return {};
  }
  $logger->debug("Fetching phenotypes for $min/$max");
  my $phenotypes = $self->_fetch_all_phenotypes($h, $onto_dba);
  $logger->debug("Fetching all sources");
  my $sources = $self->_fetch_all_sources($h);
  $logger->debug("Fetching all studies");
  my $studies = $self->_fetch_all_studies($h);
  $logger->debug("Fetching phenotypes for $min/$max");
  my $sql = q/SELECT 
		v.variation_id, 
		pf.phenotype_id,
		pf.study_id,
		pf.source_id,
		ag.value AS gn,
    av.value AS vars
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
        my ($row, $value) = @_;
        $value = [] if !defined $value;
        my $phenotype = $phenotypes->{ $row->[1] } || {};
        my $pf = { %{$phenotype} }; # make a copy
        _add_key($pf, 'study', $studies, $row->[2]);
        _add_key($pf, 'source', $sources, $row->[3]);
        push @$value, $pf;
        return $value;
      });
} ## end sub _fetch_phenotype_features

sub _fetch_features {
  my ($self, $h, $onto_dba, $min, $max) = @_;

  my $so_terms = {};

  $logger->debug(" Fetching consequences for $min/$max ");
  my $annotations = $h->execute_into_hash(
      -SQL      => q/SELECT
		tv.variation_feature_id, tv.feature_stable_id, tv.consequence_types, 
		tv.polyphen_prediction, tv.polyphen_score,
		tv.sift_prediction, tv.sift_score,
		tv.hgvs_genomic, tv.hgvs_transcript, tv.hgvs_protein
     FROM 
     transcript_variation tv
     JOIN variation_feature vf USING (variation_feature_id)
     WHERE 
     vf.variation_id between ? AND ?/,
      -PARAMS   => [ $min, $max ],
      -CALLBACK => sub {
        my ($row, $value) = @_;
        $value = [] if !defined $value;
        my $con = { stable_id => $row->[1] };

        $con->{hgvs_genomic} = $row->[7] if defined $row->[7];
        $con->{hgvs_transcript} = $row->[8] if defined $row->[8];
        $con->{hgvs_protein} = $row->[9] if defined $row->[9];

        for my $consequence (split(',', $row->[2])) {
          push @{$con->{consequences}}, { name => $consequence };
        }

        $con->{polyphen} = $row->[3] if defined $row->[3] && $row->[3] ne '';
        $con->{polyphen_score} = $row->[4] if defined $row->[4] && $row->[4] != 0;
        $con->{sift} = $row->[5] if defined $row->[5] && $row->[5] ne '';
        $con->{sift_score} = $row->[6] if defined $row->[6] && $row->[6] != 0;
        push(@{$value}, $con);
        return $value;
      });

  $logger->debug("Mapping SO terms");

  for my $annos (values %$annotations) {
    for my $anno (@{$annos}) {
      if (defined $anno->{consequences}) {
        for my $con (@{$anno->{consequences}}) {
          $con->{so_accession} =
              _fetch_so_term($onto_dba, $so_terms, $con->{name});
        }
      }
    }
  }

  $logger->debug("Fetching regulatory features for $min/$max ");
  my $reg_features = $h->execute_into_hash(
      -SQL      => q/SELECT
     r.variation_feature_id, r.feature_stable_id, r.consequence_types
     FROM 
     regulatory_feature_variation r
     JOIN variation_feature vf USING (variation_feature_id)
     WHERE 
     vf.variation_id between ? AND ?/,
      -PARAMS   => [ $min, $max ],
      -CALLBACK => sub {
        my ($row, $value) = @_;
        $value = [] if !defined $value;
        my $reg = { stable_id => $row->[1] };
        for my $consequence (split(',', $row->[2])) {

          push @{$reg->{consequences}}, {
              name         => $consequence,
              so_accession => _fetch_so_term($onto_dba, $so_terms, $consequence)
          };
        }

        push(@{$value}, $reg);

        return $value;
      });

  $logger->debug(" Fetching features for $min/$max ");
  return $h->execute_into_hash(
      -SQL      => q/SELECT
		vf.variation_id, sr.name, vf.seq_region_start, vf.seq_region_end, vf.seq_region_strand, vf.variation_feature_id,
		vf.allele_string
     FROM variation_feature vf
     JOIN seq_region sr USING (seq_region_id)
     WHERE vf.variation_id between ? AND ?/,
      -PARAMS   => [ $min, $max ],
      -CALLBACK => sub {
        my ($row, $value) = @_;
        $value = [] if !defined $value;
        my $var = { seq_region_name => $row->[1],
            start                   => $row->[2],
            end                     => $row->[3],
            strand                  => $row->[4],
            allele_string           => $row->[6] };

        my $annotation = $annotations->{ $row->[5] };
        $var->{annotations} = $annotation
            if defined $annotation && scalar($annotation) > 0;
        my $reg_feat = $reg_features->{ $row->[5] };
        $var->{regulatory_features} = $reg_feat
            if defined $reg_feat && scalar(@$reg_feat) > 0;

        push(@{$value}, $var);
        return $value;
      });
} ## end sub _fetch_features

sub _fetch_so_term {
  my ($onto_dba, $so_terms, $str) = @_;
  my $so_term = $so_terms->{$str};
  if (!defined $so_term) {
    $so_term = $onto_dba->dbc()->sql_helper()->execute_single_result(
        -SQL    => q/select t.accession
          from term t 
          join ontology o using (ontology_id) 
          where o.name='SO' and t.name=?/,
        -PARAMS => [ $str ]);
    $so_terms->{$str} = $so_term;
  }
  return $so_term;
}

sub _fetch_genenames {
  my ($self, $h, $min, $max) = @_;
  $logger->debug(" Fetching gene names for $min/$max ");
  return $h->execute_into_hash(
      -SQL      => q/SELECT variation_id, gene_name
       FROM variation_genename
     WHERE variation_id between ? AND ?/,
      -PARAMS   => [ $min, $max ],
      -CALLBACK => sub {
        my ($row, $value) = @_;
        $value = [] if !defined $value;
        push(@{$value}, $row->[1]);
        return $value;
      });
}

sub _fetch_failed_descriptions {
  my ($self, $h, $min, $max) = @_;
  $logger->debug(" Fetching failed descriptions for $min/$max ");
  return $h->execute_into_hash(
      -SQL      => q/SELECT fv.variation_id, fd.description
       FROM failed_variation fv
       JOIN failed_description fd USING (failed_description_id)
     WHERE fv.variation_id between ? AND ?/,
      -PARAMS   => [ $min, $max ],
      -CALLBACK => sub {
        my ($row, $value) = @_;
        $value = [] if !defined $value;
        push(@{$value}, $row->[1]);
        return $value;
      });
}

sub _fetch_all_studies {
  my ($self, $h) = @_;
  if (!defined $self->{studies}) {
    my $studies = $h->execute_into_hash(
        -SQL      => q/select study_id, name, description, study_type from study/,
        -CALLBACK => sub {
          my ($row, $value) = @_;
          $value->{name} = $row->[2] if defined $row->[2];
          $value->{description} = $row->[3] if defined $row->[3];
          $value->{type} = $row->[4] if defined $row->[4];
          return $value;
        });

    $h->execute_no_return(
        -SQL      => q/select study1_id, study2_id from associate_study/,
        -CALLBACK => sub {
          my ($sid1, $sid2) = @{shift @_};
          my $s1 = $studies->{$sid1};
          my $s2 = $studies->{$sid2};
          if (defined $s1 && defined $s2) {
            push @{$s1->{associated_studies}}, $s2;
          }
          return;
        });
    $self->{studies} = $studies;
  }
  return $self->{studies};
} ## end sub _fetch_all_studies

sub _fetch_all_phenotypes {
  my ($self, $h, $onto_dba) = @_;
  if (!defined $self->{phenotypes}) {
    $logger->debug("Fetching all phenotypes");
    $self->{phenotypes} = $h->execute_into_hash(
        -SQL      => q/
          SELECT phenotype_id,
                 stable_id,
                 name,
                 description,
                 poa.accession AS accession
		  FROM phenotype
	      LEFT JOIN phenotype_ontology_accession poa USING (phenotype_id)
        /,
        -CALLBACK => sub {
          my ($row, $value) = @_;
          my $doc = { id => $row->[0] };
          $doc->{stable_id} = $row->[1] if defined $row->[1];
          $doc->{name} = $row->[2] if defined $row->[2];
          $doc->{description} = $row->[3] if defined $row->[3];
          $doc->{accession} = $row->[4] if defined $row->[4];
          return $doc;
        });

    $logger->debug("Adding ontology detail");
    # fix ontology details
    for my $doc (values %{$self->{phenotypes}}) {

      if (defined $doc->{accession}) {
        $logger->debug("Adding Term with accession ".$doc->{accession} );
        $onto_dba->dbc()->sql_helper()->execute_no_return(
            -SQL      => q/
            SELECT t.name,
                   o.name,
                   s.name
            FROM  term t
            JOIN  ontology o USING (ontology_id)
            LEFT JOIN synonym s USING (term_id)
            WHERE t.accession=?/,
            -PARAMS   => [ $doc->{accession} ],
            -CALLBACK => sub {
              my ($t) = @_;
              $doc->{ontology_term} = $t->[0];
              $doc->{ontology_name} = $t->[1];
              push @{$doc->{ontology_synonyms}}, $t->[2] if defined $t->[2];
              return;
            });
      }
    }
  } ## end if ( !defined $self->{...})

  return $self->{phenotypes};
} ## end sub _fetch_all_phenotypes

sub _fetch_all_gwas {
  my ($self, $h, $min, $max) = @_;
  if (!defined $self->{gwas}) {
    $logger->debug("Fetching GWAS");
    $self->{gwas} = $h->execute_into_hash(
        -SQL      => q/SELECT distinct pf.object_id as name, s.name as source
       FROM phenotype_feature pf
       JOIN source s USING (source_id)
      WHERE pf.is_significant = 1
        AND s.name like "%GWAS%"/,
        -CALLBACK => sub {
          my ($row, $value) = @_;
          $value = [] if !defined $value;
          push(@{$value}, $row->[1]);
          return $value;
        });
  }
  return $self->{gwas};
}

sub _fetch_all_sources {
  my ($self, $h) = @_;
  if (!defined $self->{sources}) {
    $logger->debug("Fetching sources");
    $self->{sources} = $h->execute_into_hash(
        -SQL      => q/SELECT source_id, name, version from source/,
        -CALLBACK => sub {
          my ($row, $value) = @_;
          my $h = {};
          $h->{name} = $row->[1] if defined $row->[1];
          $h->{version} = $row->[2] if defined $row->[2];
          return $h;
        });
  }
  return $self->{sources};
}

sub _add_key {
  my ($obj, $k, $h, $v) = @_;
  if (defined $v) {
    my $o = $h->{$v};
    $obj->{$k} = $o if defined $o;
  }
  return;

}

sub _clean_keys {
  my ($o) = @_;
  while (my ($k, $v) = each %$o) {
    if (!defined $v || (ref($v) eq 'ARRAY' && scalar(@$v) == 0)) {
      delete $o->{$k};
    }
  }
  return;
}

1;
