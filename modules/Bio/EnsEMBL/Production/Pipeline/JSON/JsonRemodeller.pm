
=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::JSON::JsonRemodeller;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use List::MoreUtils qw/natatime/;

my $skip_xrefs = { 'Interpro' => 1, 'GO' => 1, 'HAMAP' => 1 };

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  $self->{log} = get_logger();
  my ( $tax_dba, $onto_dba, $key_xrefs, $retain_xrefs, $variation_dba )
    = rearrange( [
      qw/taxonomy_dba ontology_dba key_xrefs retain_xrefs variation_dba/
    ],
    @args );
  $self->{tax_dba} = $tax_dba;
  if ( !defined $self->{tax_dba} ) {
    $self->log()->warn("No taxonomy DBA defined");
  }
  $self->{onto_dba} = $onto_dba;
  if ( !defined $self->{onto_dba} ) {
    $self->log()->warn("No ontology DBA defined");
  }
  $self->{variation_dba} = $variation_dba;
  $self->{retain_xrefs} = $retain_xrefs || 1;
  return $self;
}

sub log {
  my ($self) = @_;
  return $self->{log};
}

sub disconnect {
  my ($self) = @_;
  $self->{tax_dba}->dbc()->disconnect_if_idle();
  $self->{onto_dba}->dbc()->disconnect_if_idle();
  return;
}

sub remodel_genome {
  my ( $self, $genome ) = @_;
  $genome->{organism}->{lineage} =
    $self->expand_taxon( $genome->{organism}->{taxonomy_id} );
  my $new_genes  = [];
  my $genome_gos = {};
  for my $gene ( @{ $genome->{genes} } ) {
    my $new_gene = $self->remodel_gene($gene);
    $new_gene->{genome}         = $genome->{organism}{name};
    $new_gene->{genome_display} = $genome->{organism}{display_name};
    $new_gene->{taxon_id}       = $genome->{organism}{taxonomy_id};
    $new_gene->{lineage}        = $genome->{organism}{lineage};
    for my $go ( @{ $new_gene->{GO} } ) {
      for my $gop ( @{ $go->{parents} } ) {
        $genome_gos->{$gop} = 1;
      }
    }
    push @$new_genes, $new_gene;
  }
  $genome->{genes}     = $new_genes;
  $genome->{GO_genome} = [ keys %$genome_gos ];
  return;
}

sub remodel_gene {
  my ( $self, $gene ) = @_;
  # track lists of names to process in a particular way
  $self->{xrefs}            = {};
  $self->{annotations}      = {};
  $self->{protein_features} = {};
  my $new_gene = $self->copy_hash(
    $gene,
    qw/id name description biotype seq_region_name start end strand coord_system homologues/
  );
  $self->collate_xrefs( $gene, $new_gene );
  # process transcripts
  for my $transcript ( @{ $gene->{transcripts} } ) {
    my $new_transcript =
      $self->copy_hash(
        $transcript,
        qw/id name description biotype seq_region_name start end strand/
      );
    $self->collate_xrefs( $transcript, $new_transcript );
    # process translations
    for my $translation ( @{ $transcript->{translations} } ) {
      my $new_translation = $self->copy_hash( $translation,
                                       qw/id coding_start coding_end/ );
      $self->collate_xrefs( $translation, $new_translation );
      $self->collate_protein_features( $translation, $new_translation );
      $self->merge_xrefs( $new_transcript, $new_translation );
      $self->make_xrefs_unique($new_translation);
      push @{ $new_transcript->{translations} }, $new_translation;
    }
    # process exons
    for my $exon ( @{ $transcript->{exons} } ) {
      my $new_exon =
        $self->copy_hash(
        $exon,
        qw/id name description biotype seq_region_name start end strand/
        );
      push @{ $new_transcript->{exons} }, $new_exon;
    }
    push @{ $new_gene->{transcripts} }, $new_transcript;
    # copy xrefs from transcript to gene
    $self->merge_xrefs( $new_gene, $new_transcript );
    $self->make_xrefs_unique($new_transcript);
  } ## end for my $transcript ( @{...})
  $self->make_xrefs_unique($new_gene);

  if ( !defined $new_gene->{homologues} ) {
    $new_gene->{homologues} = [];
  }
  for my $homologue ( @{ $new_gene->{homologues} } ) {
    $homologue->{genome_display} =
      $self->find_genome_name( $homologue->{genome} );
  }
  return $new_gene;
} ## end sub remodel_gene

sub copy_hash {
  my $self = shift;
  my $src  = shift;
  return undef unless defined $src && ref($src) eq 'HASH';
  my @keys = @_;
  if ( scalar(@keys) == 0 ) {
    @keys = keys %$src;
  }
  my $tgt = {};
  for my $key (@keys) {
    my $val = $src->{$key};
    if ( defined $val ) {
      if ( ref( $val eq 'HASH' ) ) {
        $tgt->{$key} = $self->copy_hash($val);
      }
      elsif ( ref( $val eq 'ARRAY' ) ) {
        $tgt->{$key} = map { $_ } @$val;
      }
      else {
        $tgt->{$key} = $val;
      }
    }
  }
  return $tgt;
} ## end sub copy_hash

sub make_xrefs_unique {
  my ( $self, $obj ) = @_;
  for my $dbname ( keys %{ $self->{xrefs} } ) {
    if ( defined $obj->{$dbname} ) {
      $obj->{$dbname} = [ keys( %{ $obj->{$dbname} } ) ];
    }
  }
  for my $dbname ( keys %{ $self->{protein_features} } ) {
    if ( defined $obj->{$dbname} ) {
      $obj->{$dbname} = [ keys( %{ $obj->{$dbname} } ) ];
    }
  }
  return;
}

sub collate_protein_features {
  my ( $self, $obj, $newobj ) = @_;
  for my $pf ( @{ $obj->{protein_features} } ) {
    if ( defined $pf->{dbname} && $pf->{dbname} ne '' ) {
      $self->{protein_features}{ $pf->{dbname} } = 1;
      $newobj->{ $pf->{dbname} }->{ $pf->{name} }++;
    }
    if ( defined $pf->{interpro_ac} ) {
      $self->{protein_features}{Interpro} = 1;
      $newobj->{Interpro}->{ $pf->{interpro_ac} }++;
    }
  }
  if ( $self->{retain_xrefs} ) {
    $newobj->{protein_features} =
      [ map { $self->copy_hash($_) } @{ $obj->{protein_features} } ];
  }
  return;
}

sub collate_xrefs {
  my ( $self, $obj, $new_obj ) = @_;
  for my $xref ( @{ $obj->{xrefs} } ) {
    if ( defined $xref->{linkage_types} ||
         defined $xref->{associated_xrefs} )
    {

      my $expanded_terms = $self->expand_term( $xref->{primary_id} );

      $self->{annotations}{ $xref->{dbname} } = 1;
      my $anns = $new_obj->{ $xref->{dbname} };
      if ( !defined $anns ) {
        $anns = [];
        $new_obj->{ $xref->{dbname} } = $anns;
      }
      my $evidence = [];
      for my $lt ( @{ $xref->{linkage_types} } ) {
        push $evidence, $lt->{evidence};
      }
      # add associated xrefs
      if ( defined $xref->{associated_xrefs} &&
           scalar( @{ $xref->{associated_xrefs} } ) > 0 )
      {
        for my $ass ( @{ $xref->{associated_xrefs} } ) {
          my $ann = { term => $xref->{primary_id} };
          if ( defined $evidence && scalar(@$evidence) > 0 ) {
            $ann->{evidence} = [ map { $_ } @$evidence ];
          }
          if ( defined $expanded_terms && scalar(@$expanded_terms) > 0 )
          {
            $ann->{parents} = [ map { $_ } @$expanded_terms ];
          }
          while ( my ( $k, $v ) = each %$ass ) {
            $ann->{$k} = $v->{primary_id};
          }
          push @$anns, $ann;
        }
      }
      else {
        my $ann = { term => $xref->{primary_id} };
        if ( defined $evidence && scalar(@$evidence) > 0 ) {
          $ann->{evidence} = [ map { $_ } @$evidence ];
        }
        if ( defined $expanded_terms && scalar(@$expanded_terms) > 0 ) {
          $ann->{parents} = [ map { $_ } @$expanded_terms ];
        }
        push @$anns, $ann;
      }
    } ## end if ( defined $xref->{linkage_types...})
    else {
      if ( !defined $skip_xrefs->{ $xref->{dbname} } ) {
        $self->{xrefs}{ $xref->{dbname} } = 1;
        $new_obj->{ $xref->{dbname} }->{ $xref->{primary_id} }++;
      }
    }
  } ## end for my $xref ( @{ $obj->...})
  if ( $self->{retain_xrefs} ) {
    $new_obj->{xrefs} =
      [ map { $self->copy_hash($_) } @{ $obj->{xrefs} } ];
  }
  return;
} ## end sub collate_xrefs

sub merge_xrefs {
  my ( $self, $obj, $subobj ) = @_;
  # merge from subobj onto obj
  # merge xrefs
  for my $dbname ( keys %{ $self->{xrefs} } ) {
    if ( defined $subobj->{$dbname} ) {
      for my $key ( keys %{ $subobj->{$dbname} } ) {
        $obj->{$dbname}->{$key}++;
      }
    }
  }
  # merge protein features
  for my $dbname ( keys %{ $self->{protein_features} } ) {
    if ( defined $subobj->{$dbname} ) {
      for my $key ( keys %{ $subobj->{$dbname} } ) {
        $obj->{$dbname}->{$key}++;
      }
    }
  }
  # append annotations
  for my $dbname ( keys %{ $self->{annotations} } ) {
    if ( defined $subobj->{$dbname} ) {
      if ( !defined $obj->{$dbname} ) {
        $obj->{$dbname} = [];
      }
      for my $ann ( @{ $subobj->{$dbname} } ) {
        push $obj->{$dbname}, $self->copy_hash($ann);
      }
    }
  }
  return;
} ## end sub merge_xrefs

#sub key_for_annotation {
#  my ($annotation) = @_;
#  my $key;
#  return $key;
#}
#
#sub collate_protein_features {
#  my ( $self, $obj ) = @_;
#  return;
#}

sub expand_term {
  my ( $self, $term ) = @_;
  if ( !defined $self->{onto_dba} ) {
    return [$term];
  }
  my $terms = $self->{term_parents}->{$term};
  if ( !defined $terms ) {
    $terms = $self->{onto_dba}->dbc()->sql_helper()->execute_simple(
      -SQL => q/select distinct p.accession from term t
join closure c on (t.term_id=c.child_term_id)
join term p on (p.term_id=c.parent_term_id)
where t.ontology_id=p.ontology_id and t.accession=?/,
      -PARAMS => [$term] );
    push @{$terms}, $term;
    $self->{term_parents}->{$term} = $terms;
  }
  return $terms;
}

sub expand_taxon {
  my ( $self, $taxon ) = @_;
  my $taxons = [];
  if ( defined $self->{tax_dba} ) {
    $taxons = $self->{taxon_parents}->{$taxon};
    if ( !defined $taxons ) {
      $taxons = $self->{tax_dba}->dbc()->sql_helper()->execute_simple(
        -SQL => q/select n.taxon_id from ncbi_taxa_node n
  join ncbi_taxa_node child on (child.left_index between n.left_index and n.right_index)
  where child.taxon_id=?/,
        -PARAMS => [$taxon] );
      $self->{taxon_parents}->{$taxon} = $taxons;
    }
  }
  return $taxons;
}

sub process_key {
  my ($k) = @_;
  ( my $k2 = $k ) =~ s/[^A-Za-z0-9]+/_/g;
  return $k2;
}

sub add_variation {
  my ( $self, $gene_docs, $block ) = @_;

  $block ||= 25;

  my $transcript_docs     = {};
  my $genes_by_transcript = {};
  my $updated_genes       = {};
  my $genes_by_id         = {};
  for my $gene_doc ( @{$gene_docs} ) {
    $genes_by_id->{ $gene_doc->{id} }  = $gene_doc;
    $gene_doc->{consequence_types}     = {};
    $gene_doc->{clinical_significance} = {};
    $gene_doc->{phenotypes}            = [];
    for my $transcript ( @{ $gene_doc->{transcripts} } ) {
      $transcript->{variants}                     = [];
      $transcript_docs->{ $transcript->{id} }     = $transcript;
      $genes_by_transcript->{ $transcript->{id} } = $gene_doc;
      $transcript->{consequence_types}            = {};
      $transcript->{clinical_significance}        = {};
    }
  }
  my $variation_helper = $self->{variation_dba}->dbc()->sql_helper();
  $self->_process_transcripts( $variation_helper, $transcript_docs,
                               $block,            $updated_genes,
                               $genes_by_transcript );
  $self->_process_phenotypes( $variation_helper, $genes_by_id,
                              $updated_genes, 1000 );
  # iterate over blocks of names using natatime

  for my $gene ( values %$updated_genes ) {
    $gene->{consequence_types} =
      [ keys %{ $gene->{consequence_types} } ];
    $gene->{clinical_significance} =
      [ keys %{ $gene->{clinical_significance} } ];
    for my $transcript ( @{ $gene->{transcripts} } ) {
      $transcript->{consequence_types} =
        [ keys %{ $transcript->{consequence_types} } ];
      $transcript->{clinical_significance} =
        [ keys %{ $transcript->{clinical_significance} } ];
    }
  }
  return [ values %$updated_genes ];
} ## end sub add_variation

sub add_genome_xrefs {
  return;
}

my $variation_sql = q/select distinct tv.feature_stable_id as id, 
vf.clinical_significance, tv.consequence_types 
from transcript_variation tv 
join variation_feature vf using (variation_feature_id) 
where tv.feature_stable_id in /;

sub _process_transcripts {
  my ( $self, $variation_helper, $transcript_docs, $block,
       $updated_genes, $genes_by_transcript )
    = @_;
  # iterate over blocks of names using natatime
  my $it     = natatime( $block, keys %$transcript_docs );
  my $total  = 0;
  my $transT = 0;
  $self->log()
    ->info(
         "Found " . scalar( keys %$transcript_docs ) . " transcripts" );
  while ( my @ids = $it->() ) {
    # bulk query by ID
    $transT += scalar(@ids);
    $self->log()->info("Processing $transT transcripts");
    my $sql =
      $variation_sql . '(' . join( ',', map { "'$_'" } @ids ) . ')';
    my $n = 0;
    $variation_helper->execute_no_return(
      -SQL          => $sql,
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my $row        = shift @_;
        my $id         = $row->{id};
        my $gene       = $genes_by_transcript->{$id};
        my $transcript = $transcript_docs->{$id};
        $updated_genes->{ $gene->{id} } = $gene;
        if ( defined $row->{clinical_significance} ) {
          $row->{clinical_significance} =
            [ split ',', $row->{clinical_significance} ];
          for my $clinical_significance (
                                   @{ $row->{clinical_significances} } )
          {
            $gene->{clinical_significances}->{$clinical_significance} =
              1;
            $transcript->{clinical_significances}
              ->{$clinical_significance} = 1;
          }
        }
        if ( defined $row->{consequence_types} ) {
          $row->{consequence_types} =
            [ split ',', $row->{consequence_types} ];
          for my $consequence_type ( @{ $row->{consequence_types} } ) {
            $gene->{consequence_types}->{$consequence_type}       = 1;
            $transcript->{consequence_types}->{$consequence_type} = 1;
          }
        }
        return;
      } );
  } ## end while ( my @ids = $it->)
  return;
} ## end sub _process_transcripts

my $phenotype_sql =
q/select pf.object_id as id, p.name, p.description, s.name as source, pf.is_significant 
from phenotype_feature pf
join phenotype p using (phenotype_id)
join source s using (source_id)
where pf.object_id in
/;

sub _process_phenotypes {
  my ( $self, $variation_helper, $genes_by_id, $updated_genes, $block )
    = @_;
  my $it = natatime( $block, keys %$genes_by_id );
  # process phenotypes for genes
  my $total = 0;
  while ( my @ids = $it->() ) {
    # bulk query by ID
    my $sql =
      $phenotype_sql . '(' . join( ',', map { "'$_'" } @ids ) . ')';
    my $n = 0;
    $variation_helper->execute_no_return(
      -SQL          => $sql,
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my $row = shift @_;
        my $id  = $row->{id};
        delete $row->{id};
        my $gene = $genes_by_id->{$id};
        push @{ $gene->{phenotypes} }, $row;
        $updated_genes->{$id} = $gene;
        $total++;
        $n++;
        return;
      } );
    $self->log()->info("Processed $n phenotypes (total $total)");
  }
  return;
} ## end sub _process_phenotypes

sub find_genome_name {
  my ( $self, $genome ) = @_;
  my $name = $self->{genome_names}->{$genome};
  if ( !defined $name ) {
    my $meta = Bio::EnsEMBL::Registry->get_adaptor( $genome, 'core',
                                                    'MetaContainer' );
    if ( !defined $meta ) {
      throw "Cannot find genome $genome";
    }
    $name = $meta->get_display_name();
    $meta->db()->dbc()->disconnect_if_idle();
    $self->{genome_names}->{$genome} = $name;
  }
  return $name;
}
1;
