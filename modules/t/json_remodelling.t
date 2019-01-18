# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

use strict;
use warnings;

use Data::Dumper;
use Test::More;
use Bio::EnsEMBL::Production::Pipeline::JSON::JsonRemodeller;
use JSON;

use Log::Log4perl qw/:easy/;

Log::Log4perl->easy_init($DEBUG);

my $gene = {
  xrefs => [ { display_id => "CP001791.1:CDS:869894..871087",
               primary_id => "CP001791.1:CDS:869894..871087",
               dbname     => "ENA_FEATURE_GENE", }, {
               dbname     => "BioCyc",
               primary_id => "BSEL439292:GHLG-834-MONOMER",
               display_id => "BSEL439292:GHLG-834-MONOMER" }, {
               dbname     => "BioCyc",
               primary_id => "BSEL439292:GHLG-834-MONOMER2",
               display_id => "BSEL439292:GHLG-834-MONOMER2" }, {
               display_id       => "PHI:12345",
               primary_id       => "PHI:12345",
               dbname           => "PHI",
               associated_xrefs => [ { phenotype => { primary_id => "yucky" },
                                       host      => { primary_id => "most" } } ]
             } ],
  transcripts => [ {
      xrefs => [ {
              display_id    => "GO:54321",
              primary_id    => "GO:54321",
              dbname        => "GO",
              linkage_types => [ { evidence => 'IEA' } ] },
            { dbname => "TEST", primary_id => "TEST:2", display_id => "TEST:2" }
      ],
      translations => [ {
          protein_features => [ { description    => "G3DSA:1.10.357.10",
                                  name           => "G3DSA:1.10.357.10",
                                  interpro_ac    => "IPR015893",
                                  translation_id => "KNM85488",
                                  end            => "190",
                                  dbname         => "Gene3D",
                                  start          => "7" } ],
          xrefs => [ {
              display_id => "Q12345",
              primary_id => "Q12345",
              dbname     => "UniProtKB" }, {
              primary_id       => "GO:0003677",
              associated_xrefs => [

              ],
              dbname        => "GO",
              display_id    => "GO:0003677",
              linkage_types => [ {
                           source => {
                             dbname      => "Interpro",
                             primary_id  => "IPR001647",
                             description => "DNA-binding HTH domain, TetR-type",
                             display_id  => "HTH_TetR" },
                           evidence => "IEA" } ] }

          ] } ] }, {
      xrefs => [ { display_id    => "GO:12345",
                   primary_id    => "GO:12345",
                   dbname        => "GO",
                   linkage_types => [ { evidence => 'IEA' } ] }, {
                   dbname     => "TEST",
                   primary_id => "TEST:1",
                   display_id => "TEST:1" } ],
      translations => [ {
          protein_features => [ {
              description    => "G3DSA:1.10.357.10",
              name           => "G3DSA:1.10.357.10",
              interpro_ac    => "IPR015893",
              translation_id => "KNM85488",
              end            => "190",
              dbname         => "Gene3D",
              start          => "7" } ],
          xrefs => [ { display_id => "P12345",
                       primary_id => "P12345",
                       dbname     => "UniProtKB" } ] } ] } ] };

my $remodeller =
  Bio::EnsEMBL::Production::Pipeline::JSON::JsonRemodeller->new();

#diag( Dumper($gene) );

my $new_gene = $remodeller->remodel_gene($gene);
diag( Dumper($new_gene) );

ok( $new_gene, "Gene defined" );
is( scalar( @{ $new_gene->{BioCyc} } ),           2, "2 BioCyc" );
is( scalar( @{ $new_gene->{ENA_FEATURE_GENE} } ), 1, "1 ENA_FEATURE_GENE" );
is( scalar( @{ $new_gene->{transcripts} } ),      2, "2 transcripts defined" );
my $transcript1 = $new_gene->{transcripts}->[0];
ok( $transcript1, "Transcript 1 defined" );
my $translation1 = $transcript1->{translations}->[0];
ok( $translation1, "Translation 1 defined" );
my $transcript2 = $new_gene->{transcripts}->[1];
ok( $transcript2, "Transcript 2 defined" );
my $translation2 = $transcript2->{translations}->[0];
ok( $translation2, "Translation 2 defined" );

#xrefs
is( scalar( @{ $translation1->{UniProtKB} } ), 1, "translation 1 UniProt" );
is( scalar( @{ $translation2->{UniProtKB} } ), 1, "translation 2 UniProt" );
is( scalar( @{ $transcript1->{UniProtKB} } ),  1, "transcript 1 UniProt" );
is( scalar( @{ $transcript2->{UniProtKB} } ),  1, "transcript 2 UniProt" );
is( scalar( @{ $new_gene->{UniProtKB} } ),     2, "gene UniProt" );

#protein features
is( scalar( @{ $translation1->{Interpro} } ), 1, "translation 1 Interpro" );
is( scalar( @{ $translation2->{Interpro} } ), 1, "translation 2 Interpro" );
is( scalar( @{ $transcript1->{Interpro} } ),  1, "transcript 1 Interpro" );
is( scalar( @{ $transcript2->{Interpro} } ),  1, "transcript 2 Interpro" );
is( scalar( @{ $new_gene->{Interpro} } ),     1, "gene Interpro" );

#annotations
is( scalar( @{ $translation1->{GO} } ), 1, "translation 1 GO" );
isnt( $translation2->{GO}, "translation 2 GO" );
is( scalar( @{ $transcript1->{GO} } ),  2, "transcript 1 GO" );
is( scalar( @{ $transcript2->{GO} } ),  1, "transcript 2 GO" );
is( scalar( @{ $new_gene->{GO} } ),     3, "gene GO" );

done_testing();
