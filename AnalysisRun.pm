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

Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisRun

=head1 DESCRIPTION

Base for a wrapper around a Bio::EnsEMBL::Analysis::Runnable module.
Not doing anything clever, just setting sensible defaults and checking
and passing parameters.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisRun;

use strict;
use warnings;

use File::Basename qw(dirname fileparse);
use File::Path qw(make_path remove_tree);
use File::Spec::Functions qw(catdir);

use base qw(Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base);

sub param_defaults {
  return {
    'db_type'         => 'core',
    'querylocation'   => undef,
    'queryfile'       => undef,
    'bindir'          => '/nfs/panda/ensemblgenomes/external/bin',
    'datadir'         => '/nfs/panda/ensemblgenomes/external/data',
    'libdir'          => '/nfs/panda/ensemblgenomes/external/lib',
    'workdir'         => '/tmp',
    'parameters_hash' => {},
    'split_on'        => '>',
    'results_match'   => '\S',
  };
}

sub fetch_input {
  my $self = shift @_;
  
  my $species = $self->param_required('species');
  my $logic_name = $self->param_required('logic_name');
  
  my $db_type = $self->param('db_type');
  my $dba = $self->get_DBAdaptor($db_type);
  my $aa = $dba->get_adaptor('Analysis');
  my $analysis = $aa->fetch_by_logic_name($logic_name);
  
  if (defined $analysis) {
    $self->param('analysis_adaptor', $aa);
    $self->param('analysis', $analysis);
    $self->param('program', $analysis->program_file);
  } else {
    $self->throw("Analysis '$logic_name' does not exist in $species $db_type database");
  }
  
  if ($self->param_is_defined('parameters_hash') &&
      !%{$self->param('parameters_hash')} &&
      $analysis->parameters
  ) {
    my $parameters_hash = {'-options' => $analysis->parameters};
    $self->param('parameters_hash', $parameters_hash);
  }
  
  my $querylocation = $self->param('querylocation');
  my $queryfile = $self->param('queryfile');
  if (defined $queryfile) {
    if (!-e $queryfile) {
      $self->throw("Query file '$queryfile' does not exist");
    }
    if (defined $querylocation) {
      $self->throw("Cannot explicitly define both querylocation and queryfile parameters");
    }
  } else {
    if (defined $querylocation) {
      my $dba = $self->get_DBAdaptor($self->param('db_type'));
      my $slice_adaptor = $dba->get_adaptor('Slice');
      my ($name, $start, $end) = $querylocation =~ /^(.+)\:(\d+)\-(\d+)/;
      my $slice = $slice_adaptor->fetch_by_region('toplevel', $name, $start, $end);
      $self->param('query', $slice);
    } else {
      $self->throw("Query location is not defined");
    }
  }
  
}

sub run {
  my $self = shift @_;
  
  my ($runnable, $feature_type) = $self->fetch_runnable();
  
  if ($self->param_is_defined('queryfile')) {
    my $results_dir = $self->set_queryfile($runnable);
    $runnable->checkdir($results_dir);
  } elsif ($self->param_is_defined('query')) {
    $runnable->write_seq_file;
  } else {
    $self->throw("Something's gone wrong, have neither query or queryfile!");
  }
  
  # Recommended Hive trick for potentially long-running analyses:
  # Wrap db disconnects around the code that does the work.
  $self->dbc and $self->dbc->disconnect_when_inactive(1);
  $runnable->run_analysis();
  $self->dbc and $self->dbc->disconnect_when_inactive(0);
  $self->dbc->reconnect_when_lost(1);
  
  $self->update_options($runnable);
  
  if ($self->param_is_defined('queryfile')) {
    # Some analyses can be run against a file with multiple sequences; but to
    # be stored in the database, everything needs a slice. So, partition the
    # results by sequence name, then generate a slice to attach the results to.
    my $dba = $self->get_DBAdaptor($self->param('db_type'));
    my $slice_adaptor = $dba->get_adaptor('Slice');
    my ($results_subdir, $results_files) =
      $self->split_results($runnable->resultsfile, $self->param('split_on'), $self->param('results_match'));
    
    foreach my $seq_name (keys %$results_files) {
      my ($name, $start, $end) = ($seq_name, undef, undef);
      if ($seq_name =~ /\:\d+\-\d+/) {
        ($name, $start, $end) = $seq_name =~ /^(.+)\:(\d+)\-(\d+)/;
      }
      my $slice = $slice_adaptor->fetch_by_region('toplevel', $name, $start, $end);
      $runnable->query($slice);
      $runnable->parse_results($$results_files{$seq_name});
      $self->filter_output($runnable);
      $self->save_to_db($runnable, $feature_type);
      # Output is cumulative, so need to manually erase the results we've just
      # saved. (Note that calling the runnable's 'output' method will NOT work.
      $runnable->{'output'} = [];
    }
    
    remove_tree($results_subdir) or $self->throw("Failed to remove directory '$results_subdir'");
    
  } else {
    # The assumption here is that the runnable has a slice associated with it.
    $runnable->parse_results();
    $self->filter_output($runnable);
    $self->save_to_db($runnable, $feature_type);
    
  }
}

sub fetch_runnable {
  my $self = shift @_;
  
  $self->throw("Inheriting modules must implement a 'fetch_runnable' method.");  
}

sub update_options {
  my ($self, $runnable) = @_;
  # Inheriting classes should implement this method if the
  # analysis.parameters need to be updated based on whatever the
  # runnable's run_analysis method has done.
  
  return;
}

sub filter_output {
  my ($self, $runnable) = @_;
  # Inheriting classes should implement this method if any filtering
  # is required after parsing, but before saving. The method must update
  # $runnable->output (an arrayref of features).
  
  return;
}

sub set_queryfile {
  my ($self, $runnable) = @_;
  
  # Result files are typically generated alongside the input files, and
  # it is often not possible to redirect output elsewhere without editing
  # the Runnable file. And because the default name is "$queryfile.out",
  # results might get overwritten when running multiple analyses. So it's
  # easiest to create a directory per analysis, with a symlink to the seq file.
  my $queryfile = $self->param_required('queryfile');
  my ($filename, $dir, undef) = fileparse($queryfile);
  my $results_dir = catdir($dir, $self->param('logic_name'));
  my $query_symlink = catdir($results_dir, $filename);
  
  if (!-e $results_dir) {
    make_path($results_dir) or $self->throw("Failed to create directory '$results_dir'");
  }
  if (!-e $query_symlink) {
    symlink($queryfile, $query_symlink) or $self->throw("Failed to create symlink '$query_symlink'");
  }
  
  $runnable->queryfile($query_symlink);
  
  return $results_dir;
}

sub split_results {
  my ($self, $resultsfile, $split_on, $results_match) = @_;
  my %results_files;
  
  open RESULTS, $resultsfile or $self->throw("Failed to open $resultsfile: ".$!);
  my $results = do { local $/; <RESULTS> };
  close RESULTS;
  
  my $results_subdir = "$resultsfile\_split";
  if (!-e $results_subdir) {
    make_path($results_subdir) or $self->throw("Failed to create directory '$results_subdir'");
  }
  
  my @results = split(/$split_on/, $results);
  my $header = shift @results;
  foreach my $result (@results) {
    next unless $result =~ /^$results_match/gm;
    
    my ($seqname) = $result =~ /^\s*(\S+)/;
    my $split_resultsfile = "$resultsfile\_split/$seqname";
    open SPLIT_RESULTS, ">$split_resultsfile" or $self->throw("Failed to open $split_resultsfile: ".$!);
    print SPLIT_RESULTS "$header$split_on$result";
    close SPLIT_RESULTS;
    $results_files{$seqname} = $split_resultsfile;
  }
  
  return ($results_subdir, \%results_files);
}

sub save_to_db {
  my ($self, $runnable, $feature_type) = @_;
  
  my $dba = $self->get_DBAdaptor($self->param('db_type'));
  my $adaptor = $dba->get_adaptor($feature_type);
  
  foreach my $feature (@{$runnable->output}) {
    $feature->analysis($self->param('analysis'));
    $feature->slice($runnable->query) if !defined $feature->slice;
    $runnable->feature_factory->validate($feature);
    $self->warning(sprintf("Inserting feature: %s", $feature)) if $runnable->query->name eq 'supercontig:GCA_000188075.1:Si_gnG.scaffold41199:1:1134:1';
    
    eval { $adaptor->store($feature); };
    if ($@) {
      $self->throw(
        sprintf(
          "AnalysisRun::save_to_db() failed to store '%s' into database '%s': %s",
          $feature, $adaptor->dbc()->dbname(), $@
        )
      );
    }
  }
  
  return;
}

1;
