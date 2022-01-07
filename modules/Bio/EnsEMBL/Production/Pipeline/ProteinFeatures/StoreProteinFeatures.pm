=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::StoreProteinFeatures;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Bio::EnsEMBL::DBEntry;
use Bio::EnsEMBL::ProteinFeature;

use XML::Simple;

sub run {
  my ($self) = @_;
  my $outfile_xml = $self->param_required('outfile_xml');
  
  my @features;
  
  my $results = XMLin
  (
    $outfile_xml,
    KeyAttr =>[],
    ForceArray => ['protein', 'xref', 'matches']
  );
  
  foreach my $protein (@{$results->{protein}}) {
    foreach my $xref (@{$protein->{xref}}) {
      my $translation_id = $xref->{id};
      foreach my $matches (@{$protein->{matches}}) {
        foreach my $match_group (keys %{$matches}){
          if (ref $matches->{$match_group} ne 'ARRAY') {
            $self->parse_match($translation_id, $matches->{$match_group}, \@features);
          } else {
            foreach my $match (@{$matches->{$match_group}}) {
              $self->parse_match($translation_id, $match, \@features);
            }
          }
        }
      }
    }
  }
  
  $self->store_features(\@features);
  $self->core_dbc()->disconnect_if_idle();
}

sub parse_match {
  my ($self, $translation_id, $match, $features) = @_;
  
  my $signature = $match->{signature};
  
  # These values are bound to Perl DBI SQL_DOUBLE constants by the store
  # function in the ProteinFeatureAdaptor, which means that numbers in
  # scientific E-notation will only be recognised if the 'E' is lowercased.
  my $score = $match->{score};
  $score =~ s/E/e/ if defined $score;
  
  my $evalue = $match->{evalue};
  $evalue =~ s/E/e/ if defined $evalue;
  
  my $feature_common =
  {
    'translation_id' => $translation_id,
    'analysis_type'  => $signature->{'signature-library-release'}->{library},
    'analysis_ac'    => $signature->{ac},
    'analysis_desc'  => $signature->{name} || $signature->{desc},
    'interpro_ac'    => $signature->{entry}->{ac},
    'interpro_name'  => $signature->{entry}->{name},
    'interpro_desc'  => $signature->{entry}->{desc},
    'score'          => $score,
    'evalue'         => $evalue,
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
    $protein_feature->{'align_type'} = undef;
    $protein_feature->{'cigar_string'} = undef;
    $protein_feature->{'external_data'} = undef;
    
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

1;
