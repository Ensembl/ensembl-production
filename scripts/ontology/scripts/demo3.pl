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
# This program fetches a set of ontology terms by name and displays them
# on the console.
#-----------------------------------------------------------------------

use strict;
use warnings;

use Bio::EnsEMBL::Registry;

my $registry = 'Bio::EnsEMBL::Registry';

$registry->load_registry_from_db( '-host' => 'ensembldb.ensembl.org',
                                  '-user' => 'anonymous' );

my $pattern = '%splice_site%';

# Get an ontology term adaptor and a gene adaptor (for human).
my $adaptor =
  $registry->get_adaptor( 'Multi', 'Ontology', 'OntologyTerm' );

# Fetch the terms by its accession.
my @terms = @{ $adaptor->fetch_all_by_name($pattern) };

foreach my $term (@terms) {
  printf( "Accession = %s\n\tName\t= '%s'\n",
          $term->accession(), $term->name() );
  foreach my $synonym ( @{ $term->synonyms() } ) {
    printf( "\tSynonym\t= '%s'\n", $synonym );
  }
  print("\n");
}

# $Id$
