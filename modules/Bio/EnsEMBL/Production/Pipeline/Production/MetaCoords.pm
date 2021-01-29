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

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Production::MetaCoords

=head1 DESCRIPTION

Update the meta_coord table to represent the database contents.
Functionality extracted from ensembl/misc-scripts/meta_coord/meta_coord.pl.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::Production::Pipeline::Production::MetaCoords;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Common::Base);

use Bio::EnsEMBL::Utils::Exception qw(throw);

sub param_defaults {
  my ($self) = @_;
  
  return {
    'db_type' => 'core',
  };
}

sub run {
  my ($self) = @_;
  my $db_type    = $self->param('db_type');
  my $backup_dir = $self->param('meta_coord_dir');
  
  my @table_names = qw(
    assembly_exception
    density_feature
    ditag_feature
    dna_align_feature
    exon
    gene
    intron_supporting_evidence
    karyotype
    marker_feature
    misc_feature
    prediction_exon
    prediction_transcript
    protein_align_feature
    repeat_feature
    simple_feature
    transcript
  );

  my $dba = $self->get_DBAdaptor($db_type);
  my $dbc = $dba->dbc;
  my $species_id = $dba->species_id;
  
  if ($backup_dir) {
    throw "Backup directory '$backup_dir' does not exist." unless -e $backup_dir;
    $self->backup_table($dbc, $species_id, $backup_dir);
  }
  
	foreach my $table_name (@table_names) {
		$dbc->do(
      "DELETE mc.* ".
      "FROM meta_coord mc ".
      "INNER JOIN coord_system cs USING (coord_system_id) ".
      "WHERE mc.table_name = '$table_name' AND cs.species_id = $species_id"
    );

		$dbc->do(
			"INSERT INTO meta_coord ".
        "SELECT '$table_name', s.coord_system_id, ".
			  "MAX( CAST(t.seq_region_end AS SIGNED) - CAST(t.seq_region_start AS SIGNED) + 1 ) ".
			  "FROM $table_name t ".
        "INNER JOIN seq_region s USING (seq_region_id) ".
        "INNER JOIN coord_system c USING (coord_system_id) ".
        "WHERE c.species_id = $species_id ".
			  "GROUP BY s.coord_system_id"
    );
	}
}

sub backup_table {
  my ($self, $dbc, $species_id, $backup_dir) = @_;
  
	my $file = "$backup_dir/".$dbc->dbname."_$species_id.meta_coord.backup";
	my $sys_call = sprintf(
    "mysql ".
		"--host=%s ".
		"--port=%d ".
		"--user=%s ".
		"--pass='%s' ".
		"--database=%s ".
		"--skip-column-names ".
		"--execute='SELECT * FROM meta_coord'".
		" > $file",
    $dbc->host, $dbc->port, $dbc->username, $dbc->password, $dbc->dbname
  );
	unless (system($sys_call) == 0) {
    throw "Failed to back up meta_coord table to $file.";
	}
}

1;
