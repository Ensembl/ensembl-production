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

Bio::EnsEMBL::Production::Pipeline::Ortholog::SpeciesNoOrthologs;

=head1 DESCRIPTION

This module get a list of all the available species for a given division, then get the list of all the species that we project to
by parsing all the ortholog files. The module then compare both list to get all the species without orthology-based projection. 
These species get stored in a file called "genome_no_orthologs.txt" with the date, release number, division and species taxon id.

=head1 AUTHOR

maurel@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::Ortholog::SpeciesNoOrthologs;

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use File::Path qw(make_path);
use File::Spec::Functions qw(catdir);
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub run {
    my ($self) = @_;
    #Getting the list of all species, output dir and release
    my $all_species = $self->param('all_species');
    my @all_projected_species = ();
    my $datestring = localtime();
    my $output_dir = $self->param('output_dir');
    my $release = $self->param('release');

    opendir(DIR, $output_dir) or die $!;
    # Get list of species that we project to by parsing all the otholog files
    while (my $file = readdir(DIR)) {
        next unless ($file =~ m/^orthologs-.*tsv$/);
        my $species = $1 if ($file =~ /orthologs-.*\-(.+)\.tsv/);
        push @all_projected_species, $species;
    }

    if (!-e $output_dir) {
        $self->warning("Output directory '$output_dir' does not exist. I shall create it.");
        make_path($output_dir) or $self->throw("Failed to create output directory '$output_dir'");
    }
    my $output_file = "/genome_no_orthologs.txt";
    $output_file = File::Spec->catdir($output_dir, $output_file);
    #Store header with date, release and division output directory
    open FILE, ">$output_file" or die "couldn't open file " . $output_file . " $!";
    print FILE "## " . $datestring . "\n";
    print FILE "## release " . $release . "\n";
    print FILE "## division " . $output_dir . "\n";

    # Figure out species that were not projected
    my %all_projected_species = map {$_ => 1} @all_projected_species;
    my @species_without_orthologs = grep {not $all_projected_species{$_}} @{$all_species};

    #Get species taxon id and store species without orthologs in the file.
    for my $species (@species_without_orthologs) {
        my $meta_container = Bio::EnsEMBL::Registry->get_adaptor($species, 'Core', 'MetaContainer');
        my $taxon_id = $meta_container->get_taxonomy_id();
        print FILE $species . "\t" . $taxon_id . "\n";
        $meta_container->dbc->disconnect_if_idle()
    }
    close FILE;
    my $count_line = `wc -l < $output_file`;
    if ($count_line <= 3 and scalar @species_without_orthologs != 0) {
        $self->throw("$output_file is empty");
    }
    $self->dataflow_output_id({ 'output_dir' => $output_dir }, 1);
    return;
}

1;
