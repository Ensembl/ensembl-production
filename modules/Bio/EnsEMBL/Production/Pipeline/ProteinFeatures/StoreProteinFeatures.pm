=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::StoreProteinFeatures;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

use Bio::EnsEMBL::DBEntry;
use Bio::EnsEMBL::ProteinFeature;

use XML::Simple;

sub run {
  my ($self) = @_;
  my $outfile_xml     = $self->param_required('outfile_xml');
  my $pathway_sources = $self->param('pathway_sources') || [];
  my %pathway_sources = map { $_ => 1 } @$pathway_sources;
  
  my @features;
  my @pathways;
  
  my $results = XMLin
  (
    $outfile_xml,
    KeyAttr =>[],
    ForceArray => ['protein', 'xref', 'matches', 'pathway-xref']
  );
  
  foreach my $protein (@{$results->{protein}}) {
    foreach my $xref (@{$protein->{xref}}) {
      my $translation_id = $xref->{id};
      foreach my $matches (@{$protein->{matches}}) {
        foreach my $match_group (keys %{$matches}){
          if (ref $matches->{$match_group} ne 'ARRAY') {
            $self->parse_match($translation_id, $matches->{$match_group}, \%pathway_sources, \@features, \@pathways);
          } else {
            foreach my $match (@{$matches->{$match_group}}) {
              $self->parse_match($translation_id, $match, \%pathway_sources, \@features, \@pathways);
            }
          }
        }
      }
    }
  }
  
  $self->store_features(\@features);
  $self->store_pathways(\@pathways);
}

sub parse_match {
  my ($self, $translation_id, $match, $pathway_sources, $features, $pathways) = @_;
  
  my $signature = $match->{signature};
  
  my $feature_common =
  {
    'translation_id' => $translation_id,
    'analysis_type'  => $signature->{'signature-library-release'}->{library},
    'analysis_ac'    => $signature->{ac},
    'analysis_desc'  => $signature->{name} || $signature->{desc},
    'interpro_ac'    => $signature->{entry}->{ac},
    'interpro_name'  => $signature->{entry}->{name},
    'interpro_desc'  => $signature->{entry}->{desc},
    'score'          => $match->{score},
    'evalue'         => $match->{evalue},
  };
  
  my @locs;
  foreach my $location (keys %{$match->{locations}}) {
    if (ref $match->{locations}->{$location} eq 'ARRAY') {
      push @locs, @{$match->{locations}->{$location}};
    } else {
      push @locs, $match->{locations}->{$location};
    }
  }
  
  foreach my $loc (@locs) {
    my $feature =
    {
      %$feature_common,
      'start'  => $loc->{start},
      'end'    => $loc->{end},
      'hstart' => $loc->{'hmm-start'} || 0,
      'hend'   => $loc->{'hmm-end'} || 0,
    };
    
    push @$features, $feature;
  }
  
  foreach my $pathway (@{$signature->{entry}->{'pathway-xref'}}) {
    (my $db_name = $pathway->{db}) =~ s/^KEGG$/KEGG_Enzyme/;
    
    if (exists $$pathway_sources{$db_name}) {
      my $pathway =
      {
        'translation_id' => $translation_id,
        'interpro_ac'    => $signature->{entry}->{ac},
        'interpro_name'  => $signature->{entry}->{name},
        'interpro_desc'  => $signature->{entry}->{desc},
        'db_name'        => $db_name,
        'pathway_id'     => $pathway->{id},
        'pathway_desc'   => $pathway->{name},
      };
      
      push @$pathways, $pathway;
    }
  }
}

sub store_features {
  my ($self, $features) = @_;
  my $analyses = $self->param_required('analyses');
  
  my %logic_name;
  foreach my $analysis (@{$analyses}) {
    if (exists $$analysis{'ipscan_xml'}) {
      $logic_name{$$analysis{'ipscan_xml'}} = $$analysis{'logic_name'};
    }
  }
  
  my $interpro_sql = 'INSERT IGNORE INTO interpro (interpro_ac, id) VALUES (?, ?);';
  my $interpro_sth = $self->core_dbh->prepare($interpro_sql);
  
  my $aa   = $self->core_dba->get_adaptor('Analysis');
  my $dbea = $self->core_dba->get_adaptor('DBEntry');
  my $pfa  = $self->core_dba->get_adaptor('ProteinFeature');
  
  foreach my $feature (@$features) {
    my $logic_name  = $logic_name{$$feature{'analysis_type'}};
    my $analysis    = $aa->fetch_by_logic_name($logic_name);
    my $analysis_ac = $$feature{'analysis_ac'};
    my $interpro_ac = $$feature{'interpro_ac'};
    $analysis_ac =~ s/^G3DSA\://;
    
    # 1. Store the protein feature
    my %pf_args = (
      -analysis     => $analysis,
      -start        => $$feature{'start'},
      -end          => $$feature{'end'},
      -hseqname     => $analysis_ac,
      -hdescription => $$feature{'analysis_desc'},
      -hstart       => $$feature{'hstart'},
      -hend         => $$feature{'hend'},
      -score        => $$feature{'score'},
      -p_value      => $$feature{'evalue'},
    );
    
    my $protein_feature = Bio::EnsEMBL::ProteinFeature->new(%pf_args);
    $pfa->store($protein_feature, $$feature{'translation_id'});
    
    if (defined $interpro_ac && $interpro_ac ne '') {
      # 2. Store the link between the feature and interpro accession
      $interpro_sth->execute($interpro_ac, $analysis_ac);
      
      # 3. Store the interpro xref
      $self->store_xref(
        $dbea,
        'Interpro',
        $interpro_ac,
        $$feature{'interpro_name'},
        $$feature{'interpro_desc'},
        'DIRECT',
      );
    }
  }
}

sub store_pathways {
  my ($self, $pathways) = @_;
  
  my $aa   = $self->core_dba->get_adaptor('Analysis');
  my $dbea = $self->core_dba->get_adaptor('DBEntry');
  
  my $analysis = $aa->fetch_by_logic_name('interpro2pathway');
  
  foreach my $pathway (@$pathways) {
    my $translation_id = $$pathway{'translation_id'};
    
    # 1. Fetch or store the xref_id associated with the interpro xref
    my $interpro_xref_id = $self->store_xref(
      $dbea,
      'Interpro',
      $$pathway{'interpro_ac'},
      $$pathway{'interpro_name'},
      $$pathway{'interpro_desc'},
      'DIRECT',
    );
    
    # 2. Fetch or store the xref_id associated with the pathway xref
    my $pathway_xref_id = $self->store_xref(
      $dbea,
      $$pathway{'db_name'},
      $$pathway{'pathway_id'},
      $$pathway{'pathway_id'},
      $$pathway{'pathway_desc'},
      'DEPENDENT',
      $analysis,
      $translation_id,
    );
    
    # 3. Create dependency between interpro and pathway xrefs
    $self->store_dependent_xref($translation_id, $pathway_xref_id, $interpro_xref_id, $analysis->dbID);
  }
}

sub store_xref {
  my ($self, $dbea, $dbname, $primary_id, $display_id, $description, $info_type, $analysis, $translation_id) = @_;
  
  my %xref_args = (
    -dbname      => $dbname,
    -primary_id  => $primary_id,
    -display_id  => $display_id,
    -description => $description,
    -info_type   => $info_type,
    -analysis    => $analysis,
  );
  
  my $xref = Bio::EnsEMBL::DBEntry->new(%xref_args);
  if (defined $translation_id) {
    return $dbea->store($xref, $translation_id, 'Translation', 1);
  } else {
    return $dbea->store($xref);
  }
}

sub store_dependent_xref {
  my ($self, $translation_id, $pathway_xref_id, $interpro_xref_id, $analysis_id) = @_;
  
  my $select_ox_sql =
    'SELECT object_xref_id FROM object_xref '.
    'WHERE ensembl_id=? AND ensembl_object_type=? AND xref_id=? AND analysis_id=?';
  my $select_ox_sth = $self->core_dbh->prepare($select_ox_sql);
  
  my $insert_dx_sql =
    'INSERT IGNORE INTO dependent_xref '.
    '(object_xref_id, master_xref_id, dependent_xref_id) VALUES (?, ?, ?)';
  my $insert_dx_sth = $self->core_dbh->prepare($insert_dx_sql);
  
  $select_ox_sth->execute($translation_id, 'Translation', $pathway_xref_id, $analysis_id);
  my $ox = $select_ox_sth->fetchrow_arrayref;
  my $object_xref_id = $$ox[0];
  $insert_dx_sth->execute($object_xref_id, $interpro_xref_id, $pathway_xref_id);
}

1;
