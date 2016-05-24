=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::Base;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::Base;

use strict;
use Carp;
use base('Bio::EnsEMBL::Production::Pipeline::Base');

sub write_output {
    my $self = shift;

    # If there were no jobs for the output channel 1, hive will invoke
    # autoflow by default. This will mess up the pipeline and must be
    # prevented here.
    #
    $self->input_job->autoflow(0);
    if ($self->can('write_output_jobs')) {
	$self->write_output_jobs();
    }
}

sub post_cleanup {
    my ($self)=@_;

    if(defined $self->param('species')){
      $self->get_logger()->info("Closing core database connection");
      $self->core_dbc()->disconnect_if_idle();
    }

return;
} 

sub core_dba {	
    my $self    = shift;
    my $species = $self->param('species')  || die "'species' is an obligatory parameter";	
    my $dba = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'ProteinFeature')->db();
    confess('Type error!') unless($dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'));
	
return $dba;
}

use Log::Log4perl;

sub get_logger {
    my ($self) = @_;
    $self->check_or_init_log();
return Log::Log4perl->get_logger(ref($self));
}

sub check_or_init_log {
    my ($self) = @_;
    if(! Log::Log4perl->initialized()) {
		my $config  = <<'LOG';
log4perl.logger=DEBUG, ScreenOut, ScreenErr

log4perl.filter.ErrorFilter = Log::Log4perl::Filter::LevelRange
log4perl.filter.ErrorFilter.LevelMin = WARN
log4perl.filter.ErrorFilter.LevelMax = FATAL
log4perl.filter.ErrorFilter.AcceptOnMatch = true

log4perl.filter.InfoFilter = Log::Log4perl::Filter::LevelRange
log4perl.filter.InfoFilter.LevelMin = TRACE
log4perl.filter.InfoFilter.LevelMax = INFO
log4perl.filter.InfoFilter.AcceptOnMatch = true

log4perl.appender.ScreenOut=Log::Log4perl::Appender::Screen
log4perl.appender.ScreenOut.stderr=0
log4perl.appender.ScreenOut.Threshold=DEBUG
log4perl.appender.ScreenOut.Filter=InfoFilter
log4perl.appender.ScreenOut.layout=Log::Log4perl::Layout::PatternLayout
log4perl.appender.ScreenOut.layout.ConversionPattern=%d %p> %M{2}::%L - %m%n

log4perl.appender.ScreenErr=Log::Log4perl::Appender::Screen
log4perl.appender.ScreenErr.stderr=1
log4perl.appender.ScreenErr.Threshold=DEBUG
log4perl.appender.ScreenErr.Filter=ErrorFilter
log4perl.appender.ScreenErr.layout=Log::Log4perl::Layout::PatternLayout
log4perl.appender.ScreenErr.layout.ConversionPattern=%d %p> %M{2}::%L - %m%n
LOG
		Log::Log4perl->init(\$config);
  }
return;
}

=head2 core_database_string_for_user
       Return the name and location of the database in a human readable way.
=cut
sub core_database_string_for_user {
    my $self = shift;

return $self->core_dbc->dbname . " on " . $self->core_dbc->host 
}

=head2 hive_database_string_for_user
       Return the name and location of the database in a human readable way.
=cut
sub hive_database_string_for_user {
    my $self = shift;
return $self->hive_dbc->dbname . " on " . $self->hive_dbc->host   
}

sub core_dbconn {
    my $self = shift;

    return 'mysql://' 
    . $self->core_dbc->username . ':'
    . $self->core_dbc->password . '@'
    . $self->core_dbc->host     . ':'
    . $self->core_dbc->port     . '/'
    . $self->core_dbc->dbname
}

=head2 mysql_command_line_connect_do_db
=cut
sub mysql_command_line_connect_do_db {
    my $self = shift;

    my $cmd = 
      "mysql"
      . " --host ". $self->core_dbc->host
      . " --port ". $self->core_dbc->port
      . " --user ". $self->core_dbc->username
      . " --pass=". $self->core_dbc->password
      . " ". $self->core_dbc->dbname
    ;

return $cmd;
}

1;

