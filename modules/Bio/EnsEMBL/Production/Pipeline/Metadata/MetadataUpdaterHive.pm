=head1 LICENSE

Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

  Bio::EnsEMBL::MetaData::Pipeline::MetadataUpdaterHive;

=head1 DESCRIPTION

=head1 MAINTAINER

 maurel@ebi.ac.uk 

=cut
package Bio::EnsEMBL::MetaData::Pipeline::MetadataUpdaterHive;

use base ('Bio::EnsEMBL::Hive::Process');
use strict;
use warnings;
use Bio::EnsEMBL::MetaData::MetadataUpdater
  qw/process_database/;
use Log::Log4perl qw/:easy/;
use JSON;
use Time::Duration;

sub run{
my ($self) = @_;
my $metadata_uri = $self->param_required('metadata_uri');
my $database_uri = $self->param_required('database_uri');
my $release_date = $self->param('release_date');
my $email = $self->param_required('email');
my $e_release = $self->param('e_release');
my $eg_release = $self->param('eg_release');
my $current_release = $self->param('current_release');
my $hive_dbc = $self->dbc;
my $start_time = time();
my $comment = $self->param_required('comment');
my $source = $self->param_required('source');

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
  Log::Log4perl->easy_init($INFO);
}

$hive_dbc->disconnect_if_idle() if defined $hive_dbc;

my $events = process_database($metadata_uri,$database_uri,$release_date,$e_release,$eg_release,$current_release,$email,$comment,$source);

my $runtime =  duration(time() - $start_time);
#Clean up if job already exist in result.
my $sql=q/DELETE FROM result WHERE job_id = ?/;
$hive_dbc->sql_helper()->execute_update(-SQL=>$sql,-PARAMS=>[$self->input_job()->dbID()]);
my $output = {
		  metadata_uri=>$metadata_uri,
		  database_uri=>$database_uri,
      email => $email,
		  runtime => $runtime,
      events => $events
		 };
$self->dataflow_output_id({
			       job_id=>$self->input_job()->dbID(),
			       output=>encode_json($output)
			      }, 2);

return;
}

1;
