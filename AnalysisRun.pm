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
    'db_type'          => 'core',
    'querylocation'    => undef,
    'queryfile'        => undef,
    'bindir'           => '/nfs/software/ensembl/RHEL7/linuxbrew/bin',
    'datadir'          => '/nfs/panda/ensemblgenomes/external/data',
    'libdir'           => '/nfs/software/ensembl/RHEL7/linuxbrew/lib',
    'workdir'          => '/tmp',
    'parameters_hash'  => {},
    'results_index'    => 'slice',
    'parse_filehandle' => 0,
    'output_not_set'   => 0,
    'save_object_type' => undef,
  };
}

sub fetch_input {
  my $self = shift @_;
  
  if (defined $self->param('escape_branch') and 
      $self->input_job->retry_count >= $self->input_job->analysis->max_retry_count) 
  {
    $self->dataflow_output_id($self->input_id, $self->param('escape_branch'));
    $self->input_job->autoflow(0);
    $self->complete_early("Failure probably due to memory limit, retrying with a higher limit.");
  }
  
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
  
  my $runnable = $self->fetch_runnable();
  
  if ($self->param_is_defined('queryfile')) {
    my $results_dir = $self->set_queryfile($runnable);
    $runnable->checkdir($results_dir);
  } elsif ($self->param_is_defined('query')) {
    $runnable->write_seq_file;
  } else {
    $self->throw("Something's gone wrong, have neither query or queryfile!");
  }
  
  if (!$self->param_is_defined('save_object_type')) {
    $self->throw("Type of object to save (e.g. 'gene', 'protein_feature') is not defined");
  }
  
  # Recommended Hive trick for potentially long-running analyses.
  $self->dbc && $self->dbc->disconnect_if_idle();
  $self->dbc->reconnect_when_lost(1);
  $runnable->run_analysis();
  
  $self->update_options($runnable);
  
  if ($self->param_is_defined('queryfile')) {
    my ($results_subdir, $results_files) = $self->split_results($runnable->resultsfile);
    
    foreach my $result_index (keys %$results_files) {
      $self->set_query($runnable, $result_index);
      $self->parse_filter_save($runnable, $$results_files{$result_index});
    }
    
    remove_tree($results_subdir) or $self->throw("Failed to remove directory '$results_subdir'");
    
  } else {
    $self->parse_filter_save($runnable, $runnable->resultsfile);
    
  }
}

sub fetch_runnable {
  my $self = shift @_;
  
  $self->throw("Inheriting modules must implement a 'fetch_runnable' method.");  
}

sub results_by_index {
  my ($self, $results) = @_;
  
  $self->throw("Inheriting modules must implement a 'results_by_index' method.");
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

sub post_processing {
  my ($self, $runnable) = @_;
  # Inheriting classes should implement this method if any post-processing
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

sub set_query {
  my ($self, $runnable, $result_index) = @_;
  
  # Some analyses can be run against a file with multiple sequences;
  # but to be stored in the database, everything needs a slice.
  my $dba = $self->get_DBAdaptor($self->param('db_type'));
  
  if ($self->param('results_index') eq 'translation') {
    my $translation_adaptor = $dba->get_adaptor('Translation');
    my $translation = $translation_adaptor->fetch_by_stable_id($result_index);
    if (!defined($translation)) {
      $translation = $translation_adaptor->fetch_by_dbID($result_index);
    }
    $runnable->{'query'} = $translation;
    
  } elsif ($self->param('results_index') eq 'transcript') {
    my $transcript_adaptor = $dba->get_adaptor('Transcript');
    my $transcript = $transcript_adaptor->fetch_by_stable_id($result_index);
    if (!defined($transcript)) {
      $transcript = $transcript_adaptor->fetch_by_dbID($result_index);
    }
    $runnable->query($transcript->feature_Slice) if defined $transcript;
    
  } else {
    my $slice_adaptor = $dba->get_adaptor('Slice');
    my ($name, $start, $end) = ($result_index, undef, undef);
    if ($result_index =~ /\:\d+\-\d+/) {
      ($name, $start, $end) = $result_index =~ /^(.+)\:(\d+)\-(\d+)/;
    }
    my $slice = $slice_adaptor->fetch_by_region('toplevel', $name, $start, $end);
    $runnable->query($slice);
    
  }
  
  return;
}

sub parse_filter_save {
  my ($self, $runnable, $results_file) = @_;
      
  # Output is cumulative, so need to manually delete any results that have
  # already been saved. (Note that calling the runnable's 'output' method
  # will NOT work.)
  $runnable->{'output'} = [];
  
  my $output;
  if ($self->param('parse_filehandle')) {
    open(my $fh, $results_file) or
      $self->throw("Failed to open $results_file: $!");
    $output = $runnable->parse_results($fh);
    close($fh);
  } else {
    $output = $runnable->parse_results($results_file);
  }
  
  # Runnables _should_ set the output value themselves, but sometimes don't.
  # So if it's not set, assume output is returned by the parsing method.
  if ($self->param('output_not_set')) {
    $runnable->output($output);
  }
  
  $self->filter_output($runnable);
  $self->post_processing($runnable);
  $self->save_to_db($runnable);
  
  return;
}

sub split_results {
  my ($self, $resultsfile) = @_;
  my %results_files;
  
  open RESULTS, $resultsfile or $self->throw("Failed to open $resultsfile: ".$!);
  my $results = do { local $/; <RESULTS> };
  close RESULTS;
  
  my $results_subdir = "$resultsfile\_split";
  if (!-e $results_subdir) {
    make_path($results_subdir) or $self->throw("Failed to create directory '$results_subdir'");
  }
  
  my %seqnames = $self->results_by_index($results);
    
  foreach my $seqname (keys %seqnames) {
    my $header = $seqnames{$seqname}{'header'};
    my $result = $seqnames{$seqname}{'result'};
    my $split_resultsfile = "$resultsfile\_split/$seqname";
    open SPLIT_RESULTS, ">$split_resultsfile" or $self->throw("Failed to open $split_resultsfile: ".$!);
    print SPLIT_RESULTS "$header$result";
    close SPLIT_RESULTS;
    $results_files{$seqname} = $split_resultsfile;
  }
  
  return ($results_subdir, \%results_files);
}

sub save_to_db {
  my ($self, $runnable) = @_;
  
  my $dba = $self->get_DBAdaptor($self->param('db_type'));
  my $adaptor = $dba->get_adaptor($self->param('save_object_type'));
  $adaptor->dbc->reconnect_when_lost(1);
  
  foreach my $feature (@{$runnable->output}) {
    $feature->analysis($self->param('analysis'));
    $feature->slice($runnable->query) if !defined $feature->slice;
    $runnable->feature_factory->validate($feature);
    
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
  
  $adaptor->dbc && $adaptor->dbc->disconnect_if_idle();
  
  return;
}

1;
