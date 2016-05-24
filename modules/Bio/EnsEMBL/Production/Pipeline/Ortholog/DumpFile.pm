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

Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile;

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::Ortholog::DumpFile;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use File::Path qw(make_path);
use File::Spec::Functions qw(catdir);
use base('Bio::EnsEMBL::Production::Pipeline::Base');

sub param_defaults {
    return {
          
	   };
}

sub fetch_input {
    my ($self) = @_;

    my $eg        = $self->param_required('eg');
    # job parameter 
    my $mlss_id   = $self->param_required('mlss_id');
    my $compara   = $self->param_required('compara');
    my $from_sp   = $self->param_required('from_sp');
    my $homo_types= $self->param_required('homology_types');
 
    # analysis parameter
    my $ml_type    = $self->param_required('method_link_type');
    my $output_dir = $self->param_required('output_dir');

    $self->param('eg', $eg);
    $self->param('mlss_id', $mlss_id);
    $self->param('compara', $compara);
    $self->param('from_sp', $from_sp);
    $self->param('homo_types', $homo_types);
    $self->param('ml_type', $ml_type);
    $self->param('output_dir', $output_dir);

return;
}

sub run {
    my ($self) = @_;

    # Create Compara adaptors
    my $compara = $self->param('compara');
    my $mlssa   = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet');
    my $ha      = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'Homology');
    my $gdba    = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", "GenomeDB");

    die "Can't connect to Compara database specified by $compara - check command-line and registry file settings" if (!$mlssa || !$ha ||!$gdba);

    # Get 'to_species' from mlss_id 
    my $mlss_id    = $self->param('mlss_id');
    my $mlss       = $mlssa->fetch_by_dbID($mlss_id);
    my $gdbs       = $mlss->species_set_obj->genome_dbs();
    my $from_sp    = $self->param('from_sp');
    my $homo_types = $self->param('homo_types');
    my $to_sp ; 

    foreach my $gdb (@$gdbs){ $to_sp = $gdb->name() if($gdb->name() !~/^$from_sp$/); }
   
    # Create Core adaptors
    my $from_meta      = Bio::EnsEMBL::Registry->get_adaptor($from_sp, 'core', 'MetaContainer');
    my ($from_prod_sp) = @{ $from_meta->list_value_by_key('species.production_name') };
    my $to_meta        = Bio::EnsEMBL::Registry->get_adaptor($to_sp,'core','MetaContainer');
    my ($to_prod_sp)   = @{ $to_meta->list_value_by_key('species.production_name')};

    die("Problem getting DBadaptor(s) - check database connection details\n") if (!$from_meta || !$to_meta);

    # Build Compara GenomeDB objects
    my $ml_type  = $self->param('ml_type');
    my $from_gdb = $gdba->fetch_by_registry_name($from_sp);
    my $to_gdb   = $gdba->fetch_by_registry_name($to_sp);
    my $output_dir  = $self->param('output_dir');
    my $output_file = $output_dir."/orthologs-$from_prod_sp-$to_prod_sp.tsv";
    my $datestring  = localtime();

    my $division = 'Ensembl';
    if ($from_meta->get_division()) {
      $division = $from_meta->get_division() ; 
    }
    
    open FILE , ">$output_file" or die "couldn't open file " . $output_file . " $!";
    print FILE "## " . $datestring . "\n";
    print FILE "## orthologs from $from_prod_sp to $to_prod_sp\n";
    print FILE "## compara db " . $mlssa->dbc->dbname() . "\n";
    print FILE "## division " . $division . "\n"; 

    # Fetch homologies, returntype - hash of arrays
    my $from_sp_alias = $gdba->fetch_by_registry_name($from_sp)->name();
    my $homologies    = $ha->fetch_all_by_MethodLinkSpeciesSet($mlss);
    my $homologies_ct = scalar(@$homologies);

    $self->warning("Retrieving $homologies_ct homologies of method link type $ml_type for mlss_id $mlss_id\n");

    my $perc_id  = $self->param_required('perc_id');
    my $perc_cov = $self->param_required('perc_cov');

    foreach my $homology (@{$homologies}) {
       if($self->param('eg')){ next unless $homology->is_tree_compliant()==1; }

       # Filter for homology types
       next if (!homology_type_allowed($homology->description, $homo_types));

       # 'from' member
       my $from_member      = $homology->get_Member_by_GenomeDB($from_gdb)->[0];
       my $from_perc_id     = $from_member->perc_id();
       my $from_perc_cov    = $from_member->perc_cov();
       my $from_gene        = $from_member->get_Transcript->get_Gene();

       # Filter for perc_id & perc_cov on 'from' member
       next if ($from_perc_id  < $perc_id);
       next if ($from_perc_cov < $perc_cov);

       ## Fully qualified identifiers with annotation source
       ## Havana genes are merged, so source is Ensembl
       my $from_mod_identifier = $from_gene->source();
       if ($from_mod_identifier =~ /havana/) { $from_mod_identifier = 'ensembl'; }

       my $from_stable_id   = $from_mod_identifier . ":" . $from_member->stable_id();
       my $from_translation = $from_member->get_Translation();

       if (!$from_translation) { next; }
       my $from_uniprot = get_uniprot($from_translation);

       $self->warning("Warning: can't find stable ID corresponding to 'from' species ($from_sp_alias)\n") if (!$from_stable_id);

       # 'to' member
       my $to_members        = $homology->get_Member_by_GenomeDB($to_gdb);

       foreach my $to_member (@$to_members) {
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
          my $to_stable_id   = $to_mod_identifier . ":" . $to_member->stable_id();
          my $to_translation = $to_member->get_Translation();

          next if (!$to_translation);
          my $to_uniprot     = get_uniprot($to_translation);

          my $from_identifier = $from_mod_identifier . ":" . $from_gene->stable_id;
          my $to_identifier = $to_mod_identifier . ":" . $to_gene->stable_id;

          if (scalar(@$from_uniprot) == 0 && scalar(@$to_uniprot) == 0) {
             print FILE "$from_prod_sp\t" . $from_identifier . "\t$from_stable_id\tno_uniprot\t";
             print FILE "$to_prod_sp\t" . $to_identifier . "\t$to_stable_id\tno_uniprot\t" .$homology->description."\n";
          } elsif (scalar(@$from_uniprot) == 0) {
            foreach my $to_xref (@$to_uniprot) {
             print FILE "$from_prod_sp\t" . $from_identifier . "\t$from_stable_id\tno_uniprot\t";
             print FILE "$to_prod_sp\t" . $to_identifier . "\t$to_stable_id\t$to_xref\t" .$homology->description."\n";
            }
         } elsif (scalar(@$to_uniprot) == 0) {
            foreach my $from_xref (@$from_uniprot) {
               print FILE "$from_prod_sp\t" . $from_identifier . "\t$from_stable_id\t$from_xref\t";
               print FILE "$to_prod_sp\t" . $to_identifier . "\t$to_stable_id\tno_uniprot\t" .$homology->description."\n";
            }
         }
         else {
           foreach my $to_xref (@$to_uniprot) {
              foreach my $from_xref (@$from_uniprot) {
                 print FILE "$from_prod_sp\t" . $from_identifier . "\t$from_stable_id\t$from_xref\t";
                 print FILE "$to_prod_sp\t" . $to_identifier . "\t$to_stable_id\t$to_xref\t" .$homology->description."\n";
              }
           }
        } 

     }
   }
   close FILE;

   $self->hive_dbc->disconnect_if_idle();
   $from_meta->dbc->disconnect_if_idle();
   $to_meta->dbc->disconnect_if_idle();
   $mlssa->dbc->disconnect_if_idle();
   $ha->dbc->disconnect_if_idle();
   $gdba->dbc->disconnect_if_idle();

return;
}

sub write_output {
    my ($self) = @_;


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
