=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::PostCompara::Base

=cut

=head1 DESCRIPTION

=head1 AUTHOR

ckong

=cut
package Bio::EnsEMBL::Production::Pipeline::PostCompara::Base;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyNodeAdaptor;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Attribute;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

=head2 fetch_homologies 

  Fetch the homologies from the Compara database. 
  Returns a hash of arrays:
  # Key = "from" stable ID, value = array of "to" stable IDs

=cut
sub fetch_homologies {
    my $self         = shift;
    my $ha           = shift;
    my $mlss         = shift;
    my $from_species = shift;
    my $data         = shift;
    my $gdba         = shift;
    my $homology_types_allowed = shift;
    my $is_tree_compliant     = shift;
    my $percent_id_filter      = shift;
    my $percent_cov_filter     = shift;

    print $data "\t\tFetching Compara homologies...";
    my $from_species_alias = $gdba->fetch_by_registry_name($from_species)->name();
    my %homology_cache;
    my $count              = 0;
    my $homologies         = $ha->fetch_all_by_MethodLinkSpeciesSet($mlss);

    foreach my $homology (@{$homologies}) {
       next if (!homology_type_allowed($homology->description, $homology_types_allowed));
       if ($is_tree_compliant == 1){
         next if $homology->is_tree_compliant() !=1;
       }
       my ($from_stable_id, @to_stable_ids, @perc_id, @perc_cov);
       my $members = $homology->get_all_GeneMembers();
       my $mems    = $homology->get_all_Members();

       # "high-confidence" perc_id must be at least 80 for apes and mouse/rat, at least 50 between mammals or between birds or between some fish, at least 25 otherwise.
       # This new score replace perc_id and perc_cov for vertebrates.
       if (defined $homology->is_high_confidence()) {
         # Only carry on projections if "high-confidence" eq 1
         next if $homology->is_high_confidence == 0;
       }
       else {
         foreach my $mem (@{$mems}){
           push @perc_id,$mem->perc_id();
         }
         next if (grep {$_ < $percent_id_filter} @perc_id) ;

         foreach my $mem (@{$mems}){
   	        push @perc_cov,$mem->perc_cov();
         }
         next if (grep {$_ < $percent_cov_filter} @perc_cov) ;
       }

       my $from_seen = 0;

       foreach my $member (@{$members}) {
         if ($member->genome_db()->name() eq $from_species_alias) {
            $from_stable_id = $member->stable_id();
            $from_seen++;
         }
         else {
            push(@to_stable_ids, $member->stable_id());
         }
       }
       next if $from_seen > 1;

       print STDERR "Warning: can't find stable ID corresponding to 'from' species ($from_species_alias)\n" if (!$from_stable_id);
       push @{$homology_cache{$from_stable_id}}, @to_stable_ids;
       $count++;
   }
   print $data "\tFetched " . $count . " homologies passing the filtering criteria\n";

return \%homology_cache;
}

=head2 homology_type_allowed

  
=cut
sub homology_type_allowed {
    my $h                      = shift;
    my $homology_types_allowed = shift;

    foreach my $allowed (@$homology_types_allowed) {
      return 1 if ($h eq $allowed);
    }

return undef;
}

=head2 get_taxon_ancestry

  
=cut
sub get_taxon_ancestry {
    my $self        = shift;
    my $to_taxon_id = shift;

    my $taxonomy_db            = Bio::EnsEMBL::Registry->get_DBAdaptor('multi','taxonomy');
    my $node_adaptor = $taxonomy_db->get_TaxonomyNodeAdaptor();

    my $node         = $node_adaptor->fetch_by_taxon_id($to_taxon_id);
    my @lineage      = @{$node_adaptor->fetch_ancestors($node)};
    my @ancestors;
    my @names;
    push @ancestors, $to_taxon_id;

    for my $node (@lineage) {
       push @ancestors, $node->taxon_id();
       push @names, $node->names()->{'scientific name'}->[0];
       #print STDERR  "\t\tNode ".$node->taxon_id()." is ".$node->rank()." ".$node->names()->{'scientific name'}->[0]."\n";
    }

return (\@ancestors,\@names);
}

=head2 check_directory

  
=cut
sub check_directory {
    my ($self, $dir) = @_;

    unless (-e $dir) {
        print STDERR "$dir doesn't exists. I will try to create it\n" if ($self->debug());
        print STDERR "mkdir $dir (0755)\n" if ($self->debug());
        die "Impossible create directory $dir\n" unless (mkdir $dir, 0755 );
    }

return;
}


=head2 print_GOstats

  
=cut
sub print_GOstats {
    my $self   = shift;
    my $to_ga  = shift;
    my $data   = shift;
 
    my $total_genes = count_rows($to_ga, "SELECT COUNT(*) FROM gene g");
    my $count;
    print $data "\tUnique GO terms total:";
    print $data &count_rows($to_ga, "SELECT COUNT(DISTINCT(x.dbprimary_acc)) FROM xref x, external_db e WHERE e.external_db_id=x.external_db_id AND e.db_name='GO'");
    print $data " Unique GO terms from projection:";
    print $data &count_rows($to_ga, "SELECT COUNT(DISTINCT(x.dbprimary_acc)) FROM xref x, external_db e WHERE e.external_db_id=x.external_db_id AND e.db_name='GO' AND x.info_type='PROJECTION'");
    print $data "\n\n";

return 0;
}

=head2 count_rows

  
=cut
sub count_rows {
    my ($adaptor, $sql) = @_;

    my $sth = $adaptor->dbc->prepare($sql);
    $sth->execute();

return ($sth->fetchrow_array())[0];
}

1;
