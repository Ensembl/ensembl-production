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

package Bio::EnsEMBL::Production::Pipeline::LoadFamily::AddFamilyMembers;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GeneMember;
use Bio::EnsEMBL::Compara::SeqMember;
use Bio::EnsEMBL::Compara::GenomeDB;
use Data::Dumper;
use Carp qw/croak/;

use List::MoreUtils qw/natatime/;

use strict;

use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

my $rmConn;

sub fetch_input {
}

sub run {
  my $self = shift @_;

  my $division = $self->param('division');
  if(!defined $division || scalar (@$division)==0) {
    $division = 'multi';
  } else {
    if(scalar(@$division)!=1) {
      croak "Cannot process more than one division at a time";
    }
    $division = lc($division->[0]);
    $division =~ s/ensembl//;
  }
  print Dumper($division);

  my ($compara_dba) = grep {$_->species() eq $division} @{Bio::EnsEMBL::Registry->get_all_DBAdaptors( -GROUP => 'compara' )};
 
  die "Cannot get Compara DBA for $division" unless defined $compara_dba;
  my $dba   = $self->core_dba();
  my $logic_names =
    join( ',', map { "'$_'" } @{ $self->param('logic_names') } );
  my $genome_dba          = $compara_dba->get_GenomeDBAdaptor();
  my $gene_member_dba     = $compara_dba->get_GeneMemberAdaptor();
  my $seq_member_dba      = $compara_dba->get_SeqMemberAdaptor();

  # create hash of family to members
  print "Processing genes from ".$dba->species()."\n";
 # get a genomedb for this species
  my $genome_db = $genome_dba->fetch_by_registry_name($dba->species());

  # clear out tables for this genome first
  $compara_dba->dbc()->sql_helper()->execute_update(
                                                    -SQL=>'delete fm.* from gene_member gm left join seq_member sm using (gene_member_id) left join family_member fm using (seq_member_id) where gm.genome_db_id=?',
                                                    -PARAMS=>[$genome_db->dbID()]
                                                   );

  # create a hash first though, which can then be processed
  # gene_id as key, then sets of protein-family pairs
  my $gene_families = {};
  my $sql = qq/select t.gene_id, t.transcript_id, pf.hit_name
		from coord_system c
		join seq_region s using (coord_system_id)
		join transcript t using (seq_region_id)
		join translation tl using (transcript_id)
		join protein_feature pf using (translation_id)
		join analysis pfa ON (pf.analysis_id=pfa.analysis_id)
		where pfa.logic_name in ($logic_names)
		and c.species_id=?/;
  print "$sql\n";
  $dba->dbc()->sql_helper()->execute_no_return(
                                               -SQL => $sql,
                                               -CALLBACK => sub {
                                                 my @row = @{ shift @_ };
		push @{ $gene_families->{ $row[0] } }, [ $row[1], $row[2] ];
                                                 return;
                                               },
                                               -PARAMS => [ $dba->species_id() ] );

  print "Found ".scalar(keys(%$gene_families))." genes from ".$dba->species()."\n";
  # loop through genes
  my $gene_adaptor       = $dba->get_GeneAdaptor();
  my $transcript_adaptor = $dba->get_TranscriptAdaptor();
  my $family_members     = {};
  while ( my ( $gene_id, $hits ) = each %$gene_families ) {
    my $gene = $gene_adaptor->fetch_by_dbID($gene_id);
    # create and store gene member
    my $gene_member =
      Bio::EnsEMBL::Compara::GeneMember->new_from_Gene(
        -GENE          => $gene,
        -GENOME_DB     => $genome_db,
        -BIOTYPE_GROUP => $gene->get_Biotype->biotype_group()
      );
    # If there are duplicate stable IDs, trap fatal error from compara
    # method, so we can skip it and carry on with others.
    eval {
      $gene_member_dba->store($gene_member);
    };
    if ($@) {
      my ($msg) = $@ =~ /MSG:\s+([^\n]+)/m;
      $self->warning('Duplicate stable ID: '.$msg);
    } else {
      for my $hit (@$hits) {
        my $transcript =
          $transcript_adaptor->fetch_by_dbID( $hit->[0] );
          my $seq_member =
            Bio::EnsEMBL::Compara::SeqMember->new_from_Transcript(
              -TRANSCRIPT => $transcript,
              -TRANSLATE  => 'yes',
              -GENOME_DB  => $genome_db
            );
        # TODO store CDS too?
        $seq_member->gene_member_id( $gene_member->dbID );
        $seq_member_dba->store($seq_member);
        $seq_member_dba->_set_member_as_canonical($seq_member);
        push @{ $family_members->{ $hit->[1] } }, $seq_member->dbID();
      }
    }
  } ## end while ( my ( $gene_id, $hits...))
  print "Saving familes for ".$dba->species()."\n";
  my $helper = $compara_dba->dbc()->sql_helper();
  # iterate over families and store families
  while ( my ( $family, $members ) = each(%$family_members) ) {
    print		   "Storing $family with " . scalar(@$members) . " members\n" ;
    # get family ID for this
    my $family_id =
      $helper->execute_single_result(
        -SQL => 'select family_id from family where stable_id=?',
        -PARAMS => [$family] );
    # store in batches of 1000
    my $it = natatime 1000, @{$members};
    while ( my @vals = $it->() ) {
      my $sql =
        'insert ignore into family_member(family_id,seq_member_id) values ' .
          join( ',', map { '(' . $family_id . ',' . $_  . ')' }
                @vals );
      $helper->execute_update( -SQL => $sql );
    }
  }
  $dba->dbc()->disconnect_if_idle(1);  
}

sub write_output {
}

1;

