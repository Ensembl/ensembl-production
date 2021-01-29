#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
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

use warnings;
use strict;

use Getopt::Long;
use Carp;
use Data::Dumper;
use Bio::EnsEMBL::Production::Utils::CopyDatabase
  qw/copy_database/;
use Log::Log4perl qw/:easy/;

my $opts = {};
GetOptions( $opts,                 'source_db_uri=s',
            'target_db_uri=s',     'only_tables=s',
            'skip_tables=s',       'update|u',
            'drop|d', 'convert_innodb|c', 'skip_optimize|k', 'verbose' );

if ( $opts->{verbose} ) {
  Log::Log4perl->easy_init($DEBUG);
}
else {
  Log::Log4perl->easy_init($INFO);
}

my $logger = get_logger;

if ( !defined $opts->{source_db_uri} || !defined $opts->{target_db_uri} ) {
  croak "Usage: copy_database.pl -source_db_uri <mysql://user:password\@host:port/db_name> -target_db_uri <mysql://user:password\@host:port/db_name> [-only_tables=table1,table2] [-skip_tables=table1,table2] [-update] [-drop] [-convert_innodb] [-skip_optimize] [-verbose]";
}

$logger->debug("Copying $opts->{source_db_uri} to $opts->{target_db_uri}");

copy_database($opts->{source_db_uri}, $opts->{target_db_uri}, $opts->{only_tables}, $opts->{skip_tables}, $opts->{update}, $opts->{drop}, $opts->{convert_innodb}, $opts->{skip_optimize}, $opts->{verbose});
