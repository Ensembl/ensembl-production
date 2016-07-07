#!/usr/bin/env perl

=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

  update_controlled_tables.pl

=head1 SYNOPSIS


=head1 DESCRIPTION

  Script for updating databases from the Ensembl production database

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Production::Utils::ProductionDbUpdater;
use Bio::EnsEMBL::Utils::CliHelper;
use Bio::EnsEMBL::DBSQL::DBConnection;
use Data::Dumper;

use Log::Log4perl qw/:easy/;

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
my $optsd = [ @{ $cli_helper->get_dba_opts() },
              @{ $cli_helper->get_dba_opts('m') },
              'verbose',
              'no_backup',
              'no_insert',
              'no_update',
              'no_delete',
              'tables:s@' ];
my $opts = $cli_helper->process_args( $optsd, \&pod2usage );
$opts->{tables} ||= [];
$opts->{mdbname} ||= 'ensembl_production';

if ( $opts->{verbose} ) {
  Log::Log4perl->easy_init($DEBUG);
}
else {
  Log::Log4perl->easy_init($INFO);
}

my $logger = get_logger();

$logger->info("Connecting to production database");
my ($prod_dba) = @{ $cli_helper->get_dbas_for_opts( $opts, 1, 'm' ) };

my $updater = Bio::EnsEMBL::Production::Utils::ProductionDbUpdater->new(
                      -PRODUCTION_DBA => $prod_dba,
                      -BACKUP         => $opts->{no_backup} ? 0 : 1,
                      -DELETE         => $opts->{no_delete} ? 0 : 1,
                      -INSERT         => $opts->{no_insert} ? 0 : 1,
                      -UPDATE         => $opts->{no_update} ? 0 : 1 );

my $processed_dbnames = {};
for my $dba_args ( @{ $cli_helper->get_dba_args_for_opts($opts) } ) {
  my $dbname = $dba_args->{-DBNAME};
  if ( !defined $processed_dbnames->{$dbname} ) {
    $logger->info( "Processing " . $dbname );
    my $dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(%{$dba_args});
    if ( scalar( @{ $opts->{tables}} > 0 ) ) {
      for my $table ( @{ $opts->{tables} } ) {
        $updater->update_controlled_table( $dbc, $table );
      }
    }
    else {
      $updater->update_controlled_tables($dbc);
    }
    $dbc->disconnect_if_idle();
    $processed_dbnames->{$dbname} = 1;
  }
}
