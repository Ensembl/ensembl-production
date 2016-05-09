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

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::GeneTreeHighlight::HighlightInterPro;

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::GeneTreeHighlight::HighlightInterPro;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor;
use base('Bio::EnsEMBL::Production::Pipeline::Base');

sub param_defaults {
    return {
           };
}

sub fetch_input {
    my ($self) = @_;

    my $division = $self->division();
    my $gdba     = Bio::EnsEMBL::Registry->get_adaptor($division, 'compara', 'GenomeDB');

    Bio::EnsEMBL::Registry->load_registry_from_db(
            -host       => 'mysql-eg-mirror.ebi.ac.uk',
            -port       => 4157,
            -user       => 'ensrw',
            -pass       => 'writ3r',
            -db_version => '84',
   );

   my $odba     = Bio::EnsEMBL::Registry->get_adaptor('Multi','Ontology','OntologyTerm');

   die "Can't get GenomeDB Adaptor for $division - check that database exist in the server specified" if (!$gdba);
   die "Can't get OntologyTerm Adaptor - check that database exist in the server specified" if (!$odba);
   confess('Not a OntologyTermAdaptor object, type error!') unless($odba->isa('Bio::EnsEMBL::DBSQL::OntologyTermAdaptor'));

   my $db_name = 'Interpro';

   my $interpro_sql  = q/select distinct g.stable_id,i.interpro_ac
	from interpro i
	join protein_feature pf on (pf.hit_name=i.id)
	join translation t using (translation_id)
	join transcript tc using (transcript_id)
	join gene g using (gene_id) 
	join seq_region s on (g.seq_region_id=s.seq_region_id) 
	join coord_system c using (coord_system_id)  
	where c.species_id=?/; 

   $self->param('db_name', $db_name);
   $self->param('gdba', $gdba);
   $self->param('odba', $odba);
   $self->param('interpro_sql', $interpro_sql);

return 0;
}

sub run {
    my ($self)  = @_;
    my $species       = $self->param_required('species'); 
    my $db_name       = $self->param_required('db_name');
    my $gdba          = $self->param_required('gdba');
    my $odba          = $self->param_required('odba');
    my $interpro_sql  = $self->param_required('interpro_sql');
    my $dbc           = $gdba->db()->dbc();

    my $xref_adaptor = Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor->new($dbc);
    my @genome_dbs   = grep { $_->name() ne 'ancestral_sequences' } @{$gdba->fetch_all()};
    @genome_dbs      = grep { $_->name() eq $species } @genome_dbs if(defined $species);
    
    for my $genome_db (@genome_dbs) {
      my $core_dba = $genome_db->db_adaptor();
      $self->info("Processing " . $core_dba->species() . "\n");
      $self->info("Cleaning up member_xref for " . $core_dba->species() . "\n");

      $dbc->sql_helper()->execute_update(
      	-SQL=>q/delete mx.* from member_xref mx 
      	join external_db e using (external_db_id) 
   	join gene_member m using (gene_member_id) 
	join genome_db g using (genome_db_id) where e.db_name=? and g.name=?/,
	-PARAMS=>[$db_name, $core_dba->species()]);

      $self->info("Updating member_xref for " . $core_dba->species() . "\n");

      $xref_adaptor->store_member_associations($core_dba, $db_name,
	sub {
	  my ($dbc, $core_dba, $db_name) = @_;
	  my $member_acc_hash = {};

	  $core_dba->dbc()->sql_helper()->execute_no_return(
		-SQL      => $interpro_sql,
		-CALLBACK => sub {
		  my @row = @{shift @_};
 		  push @{$member_acc_hash->{$row[0]}}, $row[1];
		  return;
		 },
                -PARAMS => [$core_dba->species_id()]);
	  return $member_acc_hash;
	});

   $self->info("Completed processing " . $core_dba->species() . "\n");
   $core_dba->dbc->disconnect_if_idle();
   }

   $self->hive_dbc->disconnect_if_idle();
   $gdba->dbc->disconnect_if_idle();
   $odba->dbc->disconnect_if_idle();

return 0;
}

sub write_output {
    my ($self)  = @_;

return 0;
}

1;
