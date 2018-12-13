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

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile;

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile;

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use File::Path qw(make_path);
use File::Spec::Functions qw(catdir);
use base('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub run {
    my ($self) = @_;

    # Create Compara adaptors
    my $compara = $self->param('compara');
    my $mlssa   = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet');
    my $ha      = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'Homology');
    my $gdba    = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", "GenomeDB");

    die "Can't connect to Compara database specified by $compara - check command-line and registry file settings" if (!$mlssa || !$ha ||!$gdba);

    #Getting source and target species
    my $from_species    = $self->param('source');
    my $homology_types = $self->param('homology_types');
    my $to_species = $self->param('species');

    # Build Compara GenomeDB objects
    my $method_link_type  = $self->param('method_link_type');
    my $from_GenomeDB    = $gdba->fetch_by_registry_name($from_species);
    my $to_GenomeDB      = $gdba->fetch_by_registry_name($to_species);

    # skip projection if the target
    # species is not in compara
    if (!defined $to_GenomeDB){
      $self->warning("Can't find GenomeDB for $to_species in the Compara database $compara\n");
      return;
    }

    my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$from_GenomeDB, $to_GenomeDB]);

    if (!defined $mlss){
      $self->warning("Can't find mlss with $method_link_type, for pair of species, $from_species, $to_species\n");
      return;
    }

    my $mlss_id       = $mlss->dbID();

    # Build the output directory & filename
    my $datestring  = localtime();
    my $output_dir  = $self->param('output_dir');
    my $division  = $self->param('output_dir');
    #my $output_file = $output_dir."/orthologs-$from_species-$to_species.tsv";

    if (!-e $output_dir) {
       $self->warning("Output directory '$output_dir' does not exist. I shall create it.");
       make_path($output_dir) or $self->throw("Failed to create output directory '$output_dir'");
    }
    my $output_file = "/orthologs-$from_species-$to_species.tsv";
    $output_file    = File::Spec->catdir($output_dir, $output_file);

    open FILE , ">$output_file" or die "couldn't open file " . $output_file . " $!";
    print FILE "## " . $datestring . "\n";
    print FILE "## orthologs from $from_species to $to_species\n";
    print FILE "## compara db " . $mlssa->dbc->dbname() . "\n";
    print FILE "## division " . $division . "\n"; 

    # Fetch homologies, returntype - hash of arrays
    my $from_species_alias = $from_GenomeDB->name();
    my $homologies    = $ha->fetch_all_by_MethodLinkSpeciesSet($mlss);
    my $homologies_ct = scalar(@$homologies);

    $self->warning("Retrieving $homologies_ct homologies of method link type $method_link_type for mlss_id $mlss_id\n");

    my $perc_id  = $self->param_required('perc_id');
    my $perc_cov = $self->param_required('perc_cov');

    foreach my $homology (@{$homologies}) {

       if($self->param('is_tree_compliant')){ next unless $homology->is_tree_compliant()==1; }


       # Filter for homology types
       next if (!homology_type_allowed($homology->description, $homology_types));

       # 'from' member
       my $from_member      = $homology->get_Member_by_GenomeDB($from_GenomeDB)->[0];
       # A temporary fix when get_Transcript() returned undef
       next if (!defined $from_member->get_Transcript());
       my $from_perc_id     = $from_member->perc_id();
       my $from_perc_cov    = $from_member->perc_cov();
       my $from_gene        = $from_member->get_Transcript->get_Gene();

       # "high-confidence" perc_id must be at least 80 for apes and mouse/rat, at least 50 between mammals or between birds or between some fish, at least 25 otherwise.
       # This new score replace perc_id and perc_cov for vertebrates.
       if (defined $homology->is_high_confidence()) {
         # Only carry on projections if "high-confidence" eq 1
         next if $homology->is_high_confidence == 0;
       }
       else {
       # Filter for perc_id & perc_cov on 'from' member
         next if ($from_perc_id  < $perc_id);
         next if ($from_perc_cov < $perc_cov);
       }
       ## Fully qualified identifiers with annotation source
       ## Havana genes are merged, so source is Ensembl
       my $from_mod_identifier = $from_gene->source();
       if ($from_mod_identifier =~ /havana/) { $from_mod_identifier = 'ensembl'; }
       if ($from_mod_identifier =~ /insdc/) { $from_mod_identifier = 'ensembl'; }

       my $from_stable_id   = $from_mod_identifier . ":" . $from_member->stable_id();
       my $from_translation = $from_member->get_Translation();

       if (!$from_translation) { next; }
       my $from_uniprot = get_uniprot($from_translation);

       $self->warning("Warning: can't find stable ID corresponding to 'from' species ($from_species_alias)\n") if (!$from_stable_id);

       # 'to' member
       my $to_members        = $homology->get_Member_by_GenomeDB($to_GenomeDB);

       foreach my $to_member (@$to_members) {
	  # A temporary fix when get_Transcript() returned undef
	  next if (!defined $to_member->get_Transcript());
          my $to_perc_id     = $to_member->perc_id();
          my $to_perc_cov    = $to_member->perc_cov();
          my $to_gene        = $to_member->get_Transcript->get_Gene();

          # Filter for perc_id & perc_cov on 'to' member
          next if ($to_perc_id  < $perc_id);
          next if ($to_perc_cov < $perc_cov);

          ## Fully qualified identifiers with annotation source
          ## Havana genes are merged, so source is Ensembl
          my $to_mod_identifier = $to_gene->source();
          if ($to_mod_identifier =~ /havana/) { $to_mod_identifier = 'ensembl'; }
          if ($to_mod_identifier =~ /insdc/) { $to_mod_identifier = 'ensembl'; }
          my $to_stable_id   = $to_mod_identifier . ":" . $to_member->stable_id();
          my $to_translation = $to_member->get_Translation();

          next if (!$to_translation);
          my $to_uniprot     = get_uniprot($to_translation);

          my $from_identifier = $from_mod_identifier . ":" . $from_gene->stable_id;
          my $to_identifier = $to_mod_identifier . ":" . $to_gene->stable_id;

          if (scalar(@$from_uniprot) == 0 && scalar(@$to_uniprot) == 0) {
             print FILE "$from_species\t" . $from_identifier . "\t$from_stable_id\tno_uniprot\t";
             print FILE "$to_species\t" . $to_identifier . "\t$to_stable_id\tno_uniprot\t" .$homology->description."\n";
          } elsif (scalar(@$from_uniprot) == 0) {
            foreach my $to_xref (@$to_uniprot) {
             print FILE "$from_species\t" . $from_identifier . "\t$from_stable_id\tno_uniprot\t";
             print FILE "$to_species\t" . $to_identifier . "\t$to_stable_id\t$to_xref\t" .$homology->description."\n";
            }
         } elsif (scalar(@$to_uniprot) == 0) {
            foreach my $from_xref (@$from_uniprot) {
               print FILE "$from_species\t" . $from_identifier . "\t$from_stable_id\t$from_xref\t";
               print FILE "$to_species\t" . $to_identifier . "\t$to_stable_id\tno_uniprot\t" .$homology->description."\n";
            }
         }
         else {
           foreach my $to_xref (@$to_uniprot) {
              foreach my $from_xref (@$from_uniprot) {
                 print FILE "$from_species\t" . $from_identifier . "\t$from_stable_id\t$from_xref\t";
                 print FILE "$to_species\t" . $to_identifier . "\t$to_stable_id\t$to_xref\t" .$homology->description."\n";
              }
           }
        } 

     }
   }
   close FILE;

   Bio::EnsEMBL::Registry->get_DBAdaptor( $self->param('species'), 'core' )->dbc->disconnect_if_idle();
   Bio::EnsEMBL::Registry->get_DBAdaptor( $self->param('source'), 'core' )->dbc->disconnect_if_idle();
   $self->hive_dbc->disconnect_if_idle();
   $mlssa->dbc->disconnect_if_idle();
   $ha->dbc->disconnect_if_idle();
   $gdba->dbc->disconnect_if_idle();

return;
}


############
# Subroutine
############

# Get the uniprot entries associated with the canonical translation
sub get_uniprot {
    my $translation = shift;
    my $uniprots = $translation->get_all_DBEntries('Uniprot%');

    my @uniprots;

    foreach my $uniprot (@$uniprots) {
       push @uniprots, $uniprot->primary_id();
    }

return \@uniprots;
}

sub homology_type_allowed {
    my $h              = shift;
    my $homology_types = shift;

    foreach my $allowed (@$homology_types) {
      return 1 if ($h eq $allowed);
    }

return undef;
}

1;
