#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
# limitations under the License


=head1 NAME

Delete specified genome from database

=head1 SYNOPSIS

copy_genome.pl [arguments]

  --user=user                         username for the source core database

  --pass=pass                         password for source core database

  --host=host                         server where the source core databases are stored

  --port=port                         port for source core database

  --dbname=dbname                     single source core database to process
                                      
  --species_id=species_id      ID of species to run over (by default all species in database are examined)

  --help                              print help (this message)


=head1 DESCRIPTION


=head1 EXAMPLES


=head1 MAINTAINER

Dan Staines <dstaines@ebi.ac.uk>, Ensembl Genomes

=head1 AUTHOR

$Author$

=head1 VERSION

$Revision$

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 


=cut

use warnings;
use strict;
use Carp;
use Pod::Usage;
use Log::Log4perl qw(:easy);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::CliHelper;
use Bio::EnsEMBL::Production::Utils::GenomeCopier;

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = [@{$cli_helper->get_dba_opts()}];
push(@{$optsd}, "verbose");
my $opts = $cli_helper->process_args($optsd, \&pod2usage);

if (defined $opts->{verbose}) {
  Log::Log4perl->easy_init($DEBUG);
} else {
  Log::Log4perl->easy_init($INFO);
}
my $logger = get_logger();

my ($dba_details) = @{$cli_helper->get_dba_args_for_opts($opts)};

my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%{$dba_details});

my $copier = Bio::EnsEMBL::Production::Utils::GenomeCopier->new();

$copier->delete($dba);
