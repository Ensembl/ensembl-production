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

Copy genome from one database to another

=head1 SYNOPSIS

copy_genome.pl [arguments]

  --srcuser=user                         username for the source core database

  --srcpass=pass                         password for source core database

  --srchost=host                         server where the source core databases are stored

  --srcport=port                         port for source core database

  --srcdbname=dbname                     single source core database to process
                                      
  --srcspecies_id=species_id			  ID of species to run over (by default all species in database are examined)

  --tgtuser=user                       username for the target core database

  --tgtpass=pass                       password for target core database

  --tgthost=host                       server where the target core database is stored

  --tgtport=port                       port for target core database
  
  --tgtdbname=dbname                   name/SID of target core database to process

  --tgtdriver=dbname                   driver to use for target core database
      
  --delete								delete target first

  --help                              print help (this message)


=head1 DESCRIPTION


=head1 EXAMPLES


=head1 MAINTAINER

Dan Staines <dstaines@ebi.ac.uk>, Ensembl

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
my $optsd = [@{$cli_helper->get_dba_opts('src')}, @{$cli_helper->get_dba_opts('tgt')}];
push(@{$optsd}, "verbose");
push(@{$optsd}, "delete");
my $opts = $cli_helper->process_args($optsd, \&pod2usage);

if (defined $opts->{verbose}) {
  Log::Log4perl->easy_init($DEBUG);
} else {
  Log::Log4perl->easy_init($INFO);
}
my $logger = get_logger();

my ($src_dba_details) = @{$cli_helper->get_dba_args_for_opts($opts, 0, 'src')};

my $src_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%{$src_dba_details});

my ($tgt_dba_details) = @{$cli_helper->get_dba_args_for_opts($opts, 0, 'tgt')};

my $tgt_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%{$tgt_dba_details});

my $copier = Bio::EnsEMBL::Production::Utils::GenomeCopier->new();

if(defined $opts->{delete}) {
	$copier->delete($tgt_dba);
}

$copier->copy($src_dba, $tgt_dba);
