#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


#-----------------------------------------------------------------------
# Demo program for the Ensembl ontology database and API.
#
# This program fetches a GO term and uses it to retrive genes.  The
# genes retrived will be ones that are cross-referenced with either the
# GO term itself or with any of its descendant terms (following the
# transitive relation types 'is_a' or 'part_of').
#-----------------------------------------------------------------------

use strict;
use warnings;

use Bio::EnsEMBL::Registry;

my $registry = 'Bio::EnsEMBL::Registry';

$registry->load_registry_from_db( '-host' => 'ensembldb.ensembl.org',
                                  '-user' => 'anonymous' );

my $accession = 'GO:0044430';    # cytoskeletal part

# Get an ontology term adaptor and a gene adaptor (for human).
my $go_adaptor =
  $registry->get_adaptor( 'Multi', 'Ontology', 'OntologyTerm' );

my $gene_adaptor = $registry->get_adaptor( 'Human', 'Core', 'Gene' );

# Fetch the GO term by its accession.
my $term = $go_adaptor->fetch_by_accession($accession);

# Use the GO term to get a bunch of genes cross-referenced to this GO
# term or to any of its descendant terms.
my @genes = @{ $gene_adaptor->fetch_all_by_GOTerm($term) };

printf( "Genes associated with the term '%s' (%s):\n",
        $term->accession(), $term->name() );

foreach my $gene (@genes) {
  printf( "stable ID = %s, external name = %s\n",
          $gene->stable_id(), $gene->external_name() );
}

# $Id$
