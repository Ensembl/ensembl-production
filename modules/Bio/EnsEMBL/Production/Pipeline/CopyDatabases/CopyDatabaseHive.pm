=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

  Bio::EnsEMBL::Production::Pipeline::CopyDatabases::CopyDatabaseHive;

=head1 DESCRIPTION

=head1 MAINTAINER

 maurel@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::CopyDatabases::CopyDatabaseHive; 

use base ('Bio::EnsEMBL::Hive::Process');
use strict;
use warnings;
use Bio::EnsEMBL::Production::Utils::CopyDatabase
  qw/copy_database/;
use JSON;
use Time::Duration;
use Log::Log4perl qw/:easy/;

sub run{


my $self = shift @_;

my $source_db_uri = $self->param_required('source_db_uri');
my $target_db_uri = $self->param_required('target_db_uri');
my $only_tables = $self->param('only_tables');
my $skip_tables = $self->param('skip_tables');
my $update = $self->param('update');
my $drop = $self->param('drop');
my $start_time = time();
my $hive_dbc = $self->dbc;

my $config = q{
	log4perl.category = INFO, DB
    log4perl.appender.DB                 = Log::Log4perl::Appender::DBI
    log4perl.appender.DB.datasource=DBI:mysql:database=}.$hive_dbc->dbname().q{;host=}.$hive_dbc->host().q{;port=}.$hive_dbc->port().q{
    log4perl.appender.DB.username        = }.$hive_dbc->user().q{
    log4perl.appender.DB.password        = }.$hive_dbc->password().q{
    log4perl.appender.DB.sql             = \
        insert into job_progress                   \
        (job_id, message) values (?,?)

    log4perl.appender.DB.params.1        = }.$self->input_job->dbID().q{
    log4perl.appender.DB.usePreparedStmt = 1

    log4perl.appender.DB.layout          = Log::Log4perl::Layout::NoopLayout
    log4perl.appender.DB.warp_message    = 0
 };

Log::Log4perl::init( \$config);

my $logger = get_logger();
if(!Log::Log4perl->initialized()) {
  Log::Log4perl->easy_init($DEBUG);
}

$hive_dbc->disconnect_if_idle() if defined $hive_dbc;

copy_database($source_db_uri, $target_db_uri, $only_tables, $skip_tables, $update, $drop);

my $runtime =  duration(time() - $start_time);

my $output = {
		  source_db_uri=>$source_db_uri,
		  target_db_uri=>$target_db_uri,
		  runtime => $runtime
		 };
$self->dataflow_output_id({
			       job_id=>$self->input_job()->dbID(),
			       output=>encode_json($output)
			      }, 2);

return;
}

1;
