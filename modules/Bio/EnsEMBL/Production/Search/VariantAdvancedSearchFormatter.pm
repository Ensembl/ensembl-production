
=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Search::VariantAdvancedSearchFormatter;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use List::MoreUtils qw/natatime/;

use Bio::EnsEMBL::Production::Search::JSONReformatter;
use JSON;
use Carp;
use File::Slurp;

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  $self->{log} = get_logger();
  my ( $tax_dba, $onto_dba ) =
    rearrange( [qw/taxonomy_dba ontology_dba/], @args );
  $self->{tax_dba} = $tax_dba;
  if ( !defined $self->{tax_dba} ) {
    $self->log()->warn("No taxonomy DBA defined");
  }
  $self->{onto_dba} = $onto_dba;
  if ( !defined $self->{onto_dba} ) {
    $self->log()->warn("No ontology DBA defined");
  }
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

sub remodel_variants {
  my ( $self, $variants_file, $genomes_file, $variants_out ) = @_;
  my $genome  = decode_json( read_file($genomes_file) );
  my $lineage = $genome->{organism}->{lineage} =
    $self->expand_taxon( $genome->{organism}->{taxonomy_id} );
  my $name = $genome->{name};

  open my $out, ">",
    $variants_out || croak "Could not open $variants_out for writing: $@";
  print $out "[";

  my $n = 0;
  process_json_file(
    $variants_file,
    sub {
      my $variant = shift;
      $variant->{genome}         = $genome->{organism}{name};
      $variant->{genome_display} = $genome->{organism}{display_name};
      $variant->{taxon_id}       = $genome->{organism}{taxonomy_id};
      $variant->{lineage}        = $lineage;
      # update parents of ontology terms
      for my $phenotype ( @{ $variant->{phenotypes} } ) {
        $phenotype->{parents} =
          $self->expand_term( $phenotype->{ontology_accession} )
          ;
      }
      for my $loc ( @{ $variant->{locations} } ) {
        for my $annotation ( @{ $loc->{annotations} } ) {
          for my $con ( @{ $annotation->{consequences} } ) {
            $con->{parents} = $self->expand_term( $con->{so_accession} );
          }
        }
      }
      if ( $n++ > 0 ) {
        print $out ",";
      }
      print $out encode_json($variant);
    } );

  print $out "]";
  close $out;
  return;
} ## end sub remodel_variants

sub expand_term {
  my ( $self, $term ) = @_;
  return undef unless defined $term;
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

1;
