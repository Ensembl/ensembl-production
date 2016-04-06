=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::InterProScan;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

use File::Path qw(make_path);

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    'run_interproscan' => 1,
    'seq_type'         => 'p',
  };
}

sub fetch_input {
  my ($self) = @_;
  
  my $input_file = $self->param_required('input_file');
  $self->throw("File '$input_file' does not exist") if (! -e $input_file);
}

sub run {
  my ($self) = @_;
  
  my $input_file       = $self->param_required('input_file');
  my $seq_type         = $self->param_required('seq_type');
  my $run_mode         = $self->param_required('run_mode');
  my $interproscan_exe = $self->param_required('interproscan_exe');
  my $applications     = $self->param_required('interproscan_applications');
  my $run_interproscan = $self->param_required('run_interproscan');
  
  my $outfile_base = "$input_file.$run_mode";
  my $outfile_xml  = "$outfile_base.xml";
  my $outfile_tsv  = "$outfile_base.tsv";
  
  if ($run_interproscan) {
    # Must use /tmp for short temporary file names; TMHMM can't cope with longer ones.
    my $tmp_dir = "/tmp/$ENV{USER}.$ENV{LSB_JOBID}";
    
    if (! -e $tmp_dir) {
      $self->warning("Output directory '$tmp_dir' does not exist. I shall create it.");
      make_path($tmp_dir) or $self->throw("Failed to create output directory '$tmp_dir'");
    }
    
    my $options = "--iprlookup --goterms --pathways ";
    $options .= "-f TSV, XML -t $seq_type --tempdir $tmp_dir ";
    $options .= '--applications '.join(',', @$applications).' ';
    my $input_option  = "-i $input_file ";
    my $output_option = "--output-file-base $outfile_base ";  
    
    if ($run_mode =~ /^(nolookup|local)$/) {
      $options .= "--disable-precalc ";
    }
    
    my $interpro_cmd = 'export JAVA_HOME="/nfs/panda/ensemblgenomes/external/jdk1.8";';
    $interpro_cmd .= 'export PATH="$JAVA_HOME/bin:$PATH";';
    $interpro_cmd .= qq($interproscan_exe $options $input_option $output_option);
    
    if (! -e $outfile_xml) {
      $self->dbc and $self->dbc->disconnect_when_inactive(1);
      system($interpro_cmd) == 0 or $self->throw("Failed to run ".$interpro_cmd);
      $self->dbc and $self->dbc->disconnect_when_inactive(0);
    }
  }
  
  if (! -e $outfile_xml) {
    $self->throw("Output file '$outfile_xml' was not created");
  } elsif (-s $outfile_xml == 0) {
    $self->throw("Output file '$outfile_xml' was zero size");
  }
  
  $self->param('outfile_xml', $outfile_xml);
  $self->param('outfile_tsv', $outfile_tsv);
}

sub write_output {
  my ($self) = @_;
  
  my $output_ids =
  {
    'outfile_xml' => $self->param('outfile_xml'),
    'outfile_tsv' => $self->param('outfile_tsv'),
  };
  $self->dataflow_output_id($output_ids, 1);
}

1;
