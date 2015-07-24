=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod

=head1 NAME

Bio::EnsEMBL::EGPipeline::Common::DatabaseDumper

=head1 DESCRIPTION

This is a simple wrapper around the Hive module; all it's really doing
is creating an appropriate dbconn for that module.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper;

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Path qw(make_path);

use base (
  'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
  'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base'
);

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    'db_type'   => 'core',
    'overwrite' => 0,
  };
  
}

sub fetch_input {
  my $self = shift @_;
  
  my $output_file = $self->param('output_file');
  if (defined $output_file) {
    if (-e $output_file) {
      if ($self->param('overwrite')) {
        $self->warning("Output file '$output_file' already exists, and will be overwritten.");
      } else {
        $self->warning("Output file '$output_file' already exists, and won't be overwritten.");
        $self->param('skip_dump', 1);
      }
    } else {
      my $output_dir = dirname($output_file);
      if (!-e $output_dir) {
        $self->warning("Output directory '$output_dir' does not exist. I shall create it.");
        make_path($output_dir) or $self->throw("Failed to create output directory '$output_dir'");
      }
    }
  }
  
  my $db_type = $self->param('db_type');
  if ($db_type eq 'hive') {
    $self->param('src_db_conn', $self->dbc);
  } else {
    $self->param('exclude_ehive', 1);
    $self->param('src_db_conn', $self->get_DBAdaptor($db_type)->dbc);
  }
  
  $self->SUPER::fetch_input();
  
}

sub run {
  my $self = shift @_;

  my $src_dbc = $self->param('src_dbc');
  my $tables = $self->param('tables');
  my $ignores = $self->param('ignores');

  # We have to exclude everything
  return if ($self->param('exclude_ehive') and $self->param('exclude_list') and scalar(@$ignores) == $self->param('nb_ehive_tables'));

  # mysqldump command
  my $output = "";
  if ($self->param('output_file')) {
    if (lc $self->param('output_file') =~ /\.gz$/) {
      $output = sprintf(' | gzip > %s', $self->param('output_file'));
    } else {
      $output = sprintf('> %s', $self->param('output_file'));
    }
  } else {
    $output = join(' ', '|', @{ $self->param('real_output_db')->to_cmd(undef, undef, undef, undef, 1) } );
  };

  # Must be joined because of the redirection / the pipe
  my $cmd = join(' ', 
    @{ $self->mysqldump($src_dbc, 1) },
    '--skip-lock-tables',
    @$tables,
    (map {sprintf('--ignore-table=%s.%s', $src_dbc->dbname, $_)} @$ignores),
    $output
  );
  print "$cmd\n" if $self->debug;

  # Check whether the current database has been restored from a snapshot.
  # If it is the case, we shouldn't re-dump and overwrite the file.
  # We also check here the value of the "skip_dump" parameter
  my $completion_signature = sprintf('dump_%d_restored', $self->input_job->dbID < 0 ? 0 : $self->input_job->dbID);
  return if $self->param('skip_dump') or $self->param($completion_signature);

  # OK, we can dump
  if(my $return_value = system($cmd)) {
      die "system( $cmd ) failed: $return_value";
  }

  # We add the signature to the dump, so that the job won't rerun on a
  # restored database
  my $extra_sql = qq{echo "INSERT INTO pipeline_wide_parameters VALUES ('$completion_signature', 1);\n" $output};
  # We're very lucky that gzipped streams can be concatenated and the
  # output is still valid !
  $extra_sql =~ s/>/>>/;
  if(my $return_value = system($extra_sql)) {
      die "system( $extra_sql ) failed: $return_value";
  }
}

our $pass_internal_counter = 0;
sub mysqldump {
  my ($self, $dbc, $hide_password_in_env) = @_;

  my $hidden_password;
    if ($dbc->password) {
      if ($hide_password_in_env) {
        my $pass_variable = "EHIVE_TMP_PASSWORD_${pass_internal_counter}";
        $pass_internal_counter++;
        $ENV{$pass_variable} = $dbc->password;
        $hidden_password = '$'.$pass_variable;
      } else {
        $hidden_password = $dbc->password;
      }
  }

  my @cmd;
  push @cmd, 'mysqldump';
  push @cmd, '-h'.$dbc->host       if $dbc->host;
  push @cmd, '-P'.$dbc->port       if $dbc->port;
  push @cmd, '-u'.$dbc->username   if $dbc->username;
  push @cmd, '-p'.$hidden_password if $dbc->password;
  push @cmd, $dbc->dbname          if $dbc->dbname;

  return \@cmd;
}

1;
