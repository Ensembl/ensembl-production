
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

package Bio::EnsEMBL::Production::Pipeline::LoadFamily::CreateFamilies;

use Bio::EnsEMBL::Registry;
use Data::Dumper;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Compara::Family;
use Carp qw/croak/;

use strict;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory/;

sub run {
  my ($self) = @_;
  # call run from super
  $self->SUPER::run;

  # get all unique databases
  my $dbcs = {};
  for my $core_dba (values %{$self->param('core_dbas')}) {
    my $dbname = $core_dba->dbc()->dbname();
    if(!defined $dbcs->{$dbname}) {
      $dbcs->{$dbname} = $core_dba->dbc();
    }
  }
  
  my @compara_dbas = values %{$self->param('compara_dbas')};
  if(scalar(@compara_dbas)!=1) {
    croak "Expecting one compara database only";  
  }
  my $compara_dba = $compara_dbas[0];
  $compara_dba->dbc()->sql_helper()->execute_update(-SQL=>'delete family.*,family_member.* from family left join family_member using (family_id)');
  # get compara
  my $genome_dba = $compara_dba->get_GenomeDBAdaptor();

  # hash of families
  my $families = {};
  
  my $logic_names =
      join( ',', map { "'$_'" } @{ $self->param('logic_names') } );
  
  my $sql = qq/
select distinct pf.hit_name,pf.hit_description 
FROM protein_feature pf
JOIN analysis pfa ON (pf.analysis_id=pfa.analysis_id)
WHERE pfa.logic_name in ($logic_names)/;

  my $dbnames = {};
  my $genome_dbs = [];
  my $output_ids = [];

  for my $dbc ( values %$dbcs ) {
    print "Processing ".$dbc->dbname()."\n";
    
      $dbc->sql_helper()->execute_no_return(                                                                                                                                                                                              
                                            -SQL => q/
select m1.meta_value, m2.meta_value, m3.meta_value, m4.meta_value
from meta m1
join meta m2 using (species_id)
join meta m3 using (species_id)
join meta m4 using (species_id)
where m1.meta_key='species.production_name'
and m2.meta_key='assembly.default'
and m3.meta_key='species.taxonomy_id'
and m4.meta_key='genebuild.version'
/,                                                                                                                                                                                                                      
	   -CALLBACK => sub {      
	       my ($species, $assembly_id, $taxonomy_id, $genebuild) = @{ shift @_ }; 
                   my $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new();
                   print "Creating genome_db for $species\n";
	           $genome_db->name($species);
	           $genome_db->assembly($assembly_id);
	           $genome_db->taxon_id($taxonomy_id);
	           $genome_db->genebuild($genebuild);
	           $genome_db->has_karyotype(0);
	           $genome_db->is_high_coverage(0);
	           $genome_dba->store($genome_db);
	           push @$genome_dbs, $genome_db;
                   push @$output_ids, {name=>$species};
                   $dbnames->{$dbc->dbname()} = 1;
	       return;
          }
          );

      if($dbnames->{$dbc->dbname()}) {
        print "Adding families for ".$dbc->dbname()."\n";
        $dbc->sql_helper()->execute_no_return(
                                              -SQL => $sql,
                                              -CALLBACK => sub {
                                                my @row = @{ shift @_ };
                                                if ( !exists $families->{ $row[0] } ) {
                                                  $families->{ $row[0] } = $row[1];
                                                }
                                                return;
                                              } );
      }
    
    $dbc->disconnect_if_idle(1);
  }
  
  print "Found ".scalar(keys(%{$families}))." familes\n";

  # create and store MLSS
  my $sso = Bio::EnsEMBL::Compara::SpeciesSet->new(-GENOME_DBS=>$genome_dbs);
  $sso->add_tag('name',"collection-all_division");
  $compara_dba->get_SpeciesSetAdaptor()->store($sso);

  my $mlss =
    Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
	  -method =>
	  Bio::EnsEMBL::Compara::Method->new(
                                             -type  => 'FAMILY',
                                             -class => 'Family.family'
                                            ),
                                                     -species_set_obj => $sso );
  
  $compara_dba->get_MethodLinkSpeciesSetAdaptor()->store($mlss);
  my $family_dba = $compara_dba->get_FamilyAdaptor();
  while ( my ( $id, $name ) = each %$families ) {
    print "Storing family $id $name\n";
    # create and store families
    my $family =
      Bio::EnsEMBL::Compara::Family->new(
                                         -STABLE_ID   => $id,
                                         -DESCRIPTION => $name,
                                         -VERSION     => 1,
                                         -METHOD_LINK_SPECIES_SET_ID => $mlss->dbID() );
    $family_dba->store($family);
  }
  print "Completed storing families\n";
  
}

1;

