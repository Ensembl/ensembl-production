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

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::StoreGoXrefs;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Bio::EnsEMBL::OntologyXref;

sub run {
  my ($self) = @_;

  $self->hive_dbc()->disconnect_if_idle();
  
  my $aa   = $self->core_dba->get_adaptor('Analysis');
  my $dbea = $self->core_dba->get_adaptor('DBEntry');
  
  my $analysis = $aa->fetch_by_logic_name('interpro2go');
  
  my $go = $self->parse_interpro2go();
  
  $self->delete_existing();
  
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

sub delete_existing {
  my ($self) = @_;

  my $species_id = $self->core_dba()->species_id();
  my $delete_ox_sql =
    qq/DELETE ox.*, ontx.* 
    FROM 
    coord_system c
    JOIN seq_region s USING (coord_system_id)
    JOIN transcript t USING (seq_region_id)
    JOIN object_xref ox ON (ox.ensembl_id=t.transcript_id)
    JOIN ontology_xref ontx USING (object_xref_id) 
    JOIN xref x1 ON (ox.xref_id = x1.xref_id) 
    JOIN external_db edb1 ON (x1.external_db_id = edb1.external_db_id) 
    JOIN xref x2 ON (ontx.source_xref_id = x2.xref_id) 
    JOIN external_db edb2 ON (x2.external_db_id = edb2.external_db_id) 
    WHERE 
    c.species_id=$species_id
    AND ox.ensembl_object_type='Transcript'
    AND edb1.db_name = "GO" 
    AND edb2.db_name = "Interpro"/;
  $self->core_dbh->do($delete_ox_sql);

  my $delete_go_sql =
    q/DELETE x.* FROM xref x 
    LEFT OUTER JOIN object_xref ox  ON x.xref_id = ox.xref_id 
    JOIN external_db edb ON x.external_db_id = edb.external_db_id 
    WHERE edb.db_name = "GO" AND ox.xref_id IS NULL/;
  $self->core_dbh->do($delete_go_sql);
}

sub store_go_xref {
  my ($self, $dbea, $analysis, $go) = @_;
  my $species_id = $self->core_dba()->species_id();
  my $sql =
    qq/
    SELECT DISTINCT interpro_ac, transcript_id 
    FROM 
    interpro 
    JOIN protein_feature ON id = hit_name 
    JOIN translation USING (translation_id)
    JOIN transcript t USING (transcript_id)
    JOIN seq_region s USING (seq_region_id)
    JOIN coord_system c USING (coord_system_id)
    WHERE c.species_id=$species_id/;
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
