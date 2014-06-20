=pod 

=head1 NAME

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::ProjectionBase

=cut

=head1 DESCRIPTION

=head1 MAINTAINER

$Author: ckong $

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::ProjectionBase; 

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_homologies 

  Fetch the homologies from the Compara database. 
  Returns a hash of arrays:
  # Key = "from" stable ID, value = array of "to" stable IDs

=cut
sub fetch_homologies {
    my $self = shift;
#    my ($ha, $mlss, $from_species, $log_file, $gdba, $homology_types_allowed, $percent_id_filter) = shift;
    my $ha   = shift;
    my $mlss = shift;
    my $from_species = shift;
    my $data = shift;
    my $gdba = shift;
    my $homology_types_allowed = shift;
    my $percent_id_filter = shift;

    print $data "\t\tFetching Compara homologies...";
    my $from_species_alias = $gdba->fetch_by_registry_name($from_species)->name();
    my %homology_cache;
    my $count              = 0;
    my $homologies         = $ha->fetch_all_by_MethodLinkSpeciesSet($mlss);

    foreach my $homology (@{$homologies}) {
       next if (!homology_type_allowed($homology->description, $homology_types_allowed));

       my ($from_stable_id, @to_stable_ids, @perc_id);
       my $members = $homology->get_all_GeneMembers();
       my $mems    = $homology->get_all_Members();
   
       foreach my $mem (@{$mems}){
           push @perc_id,$mem->perc_id();
       }
       next if (grep {$_ < $percent_id_filter} @perc_id) ;

       foreach my $member (@{$members}) {
         if ($member->genome_db()->name() eq $from_species_alias) {
            $from_stable_id = $member->stable_id();
         }
         else {
            push(@to_stable_ids, $member->stable_id());
         }
       }

       print STDERR "Warning: can't find stable ID corresponding to 'from' species ($from_species_alias)\n" if (!$from_stable_id);
       push @{$homology_cache{$from_stable_id}}, @to_stable_ids;
       $count++;
   }
   print $data "\tFetched " . $count . " homologies\n";

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

    my $dba =  Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -user   => 'ensro',
        -dbname => 'ncbi_taxonomy',
        -host   => 'mysql-eg-mirror.ebi.ac.uk',
        -port   => '4205');

    my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($dba);
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

sub check_directory {
    my ($self, $dir) = @_;

    unless (-e $dir) {
        print STDERR "$dir doesn't exists. I will try to create it\n" if ($self->debug());
        print STDERR "mkdir $dir (0755)\n" if ($self->debug());
        die "Impossible create directory $dir\n" unless (mkdir $dir, 0755 );
    }

return;
}



1;
