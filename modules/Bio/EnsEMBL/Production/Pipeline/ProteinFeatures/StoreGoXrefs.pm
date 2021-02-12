=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::StoreGoXrefs;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Bio::EnsEMBL::OntologyXref;

sub run {
  my ($self) = @_;

  my $logic_name = $self->param_required('logic_name');

  $self->hive_dbc()->disconnect_if_idle();
  
  my $aa   = $self->core_dba->get_adaptor('Analysis');
  my $dbea = $self->core_dba->get_adaptor('DBEntry');
  
  my $analysis = $aa->fetch_by_logic_name($logic_name);
  
  my $go = $self->parse_interpro2go();
  
  $self->store_go_xref($dbea, $analysis, $go);
  $self->core_dbc()->disconnect_if_idle();
}

sub parse_interpro2go {
  my ($self) = @_;
  
  my $interpro2go_file = $self->param_required('interpro2go_file');
  
  my $interpro_sql = 'SELECT DISTINCT interpro_ac FROM interpro;';
  my $accessions = $self->core_dbh->selectcol_arrayref($interpro_sql);
  my %accessions = map { $_ => 1} @$accessions;
  
  open (my $fh, '<', $interpro2go_file) or die "Failed to open $interpro2go_file: $!\n";
  
  my %go;
  while (my $line = <$fh>) {
    next if ($line !~ /^InterPro/);
    
    my ($interpro_ac, $go_desc, $go_term) = $line
      =~ /^InterPro:(\S+).+\s+\>\s+GO:(.+)\s+;\s+(GO:\d+)/;
    
    if (exists $accessions{$interpro_ac}) {
      push @{$go{$interpro_ac}}, [$go_term, $go_desc];
    }
  }
  
  close $fh;
  
  return \%go;
}

sub store_go_xref {
  my ($self, $dbea, $analysis, $go) = @_;

  my $sql = qq/
    SELECT DISTINCT interpro_ac, transcript_id FROM
      interpro INNER JOIN
      protein_feature ON id = hit_name INNER JOIN
      translation USING (translation_id)
  /;
  my $sth = $self->core_dbh->prepare($sql);
  $sth->execute();
  
  while (my $row = $sth->fetchrow_arrayref()) {
    my ($interpro_ac, $transcript_id) = @$row;
    
    if (exists $$go{$interpro_ac}) {

      my $interpro_xref = $self->get_interpro_xref($dbea, $interpro_ac);

      foreach my $go (@{$$go{$interpro_ac}}) {
        
        my %go_xref_args = (
          -dbname      => 'GO',
          -primary_id  => $$go[0],
          -display_id  => $$go[0],
          -description => $$go[1],
          -info_type   => 'DEPENDENT',
          -analysis    => $analysis,
        );
    
        my $go_xref = Bio::EnsEMBL::OntologyXref->new(%go_xref_args);
        $go_xref->add_linkage_type('IEA', $interpro_xref);
        $go_xref->{version} = undef;
        $dbea->store($go_xref, $transcript_id, 'Transcript', 1);
      }
    }
  }
}

sub get_interpro_xref {
  my ($self, $dbea, $interpro_ac) = @_;
  my $interpro_xref = $self->{interpro}->{$interpro_ac};
  if(!defined $interpro_xref) {
    $interpro_xref = $dbea->fetch_by_db_accession('Interpro', $interpro_ac);
    $self->{interpro}->{$interpro_ac} = $interpro_xref;
  }
  return $interpro_xref;
}

1;
