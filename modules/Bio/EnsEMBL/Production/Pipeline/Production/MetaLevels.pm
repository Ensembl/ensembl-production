=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::Production::MetaLevels

=head1 DESCRIPTION

Populate meta table with "<type>build.level" data,
e.g. "genebuild.level" => "toplevel".
Functionality extracted from ensembl/misc-scripts/meta_levels.pl.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::Production::Pipeline::Production::MetaLevels;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Common::Base);

sub param_defaults {
  my ($self) = @_;
  
  return {
    'db_type' => 'core',
  };
}

sub run {
  my ($self) = @_;
  my $db_type = $self->param('db_type');
  
  my @feature_types = qw(
    gene
    transcript
    exon
    prediction_transcript
    prediction_exon
    dna_align_feature
    protein_align_feature
    repeat_feature
    simple_feature
  );

  my $dba = $self->get_DBAdaptor($db_type);
	my $ma = $dba->get_MetaContainer();
	my @not_inserted;

	foreach my $type (@feature_types) {
		$ma->delete_key($type.'build.level');

		if ($self->can_use_key($dba, $type)) {
      $ma->store_key_value($type.'build.level', 'toplevel');
		} else {
			push @not_inserted, $type;
		}
	}
  
	print "Did not insert keys for " . join( ", ", @not_inserted ) . ".\n" if @not_inserted;
}

sub can_use_key {
	my ($self, $dba, $type) = @_;
  # Compare total count of type with the number of toplevel type;
  # if they're the same, then we can use the key.

	my $sth = $dba->dbc->prepare("SELECT COUNT(*) FROM $type");
	$sth->execute();
	my $total = ( $sth->fetchrow_array() )[0];

	$sth = $dba->dbc->prepare(
      "SELECT COUNT(*) "
    . "FROM $type t, seq_region_attrib sra, attrib_type at "
    . "WHERE t.seq_region_id=sra.seq_region_id "
    . "AND sra.attrib_type_id=at.attrib_type_id "
    . "AND at.code='toplevel'" );
	$sth->execute();
	my $toplevel = ( $sth->fetchrow_array() )[0];

	if ( $toplevel > 0 ) {
		return $total == $toplevel;
	}
}

1;
