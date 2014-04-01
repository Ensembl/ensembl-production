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

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::IndexGenome;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Hive::Process/;

use Log::Log4perl qw(:easy);
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::EGPipeline::Common::Aligner;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

my $logger = get_logger();

sub param_defaults {
  my ($self) = @_;
  return {};
}

sub fetch_input {
  my ($self) = @_;
  my $aligner_module = $self->param('aligner');
  eval "require $aligner_module";
  $self->{'memory_mode'} = $self->param('memory_mode');
  $self->{'aligner'}     = $aligner_module->new(-memory_mode => $self->{'memory_mode'});
  return;
}

sub run {
  my ($self) = @_;

  my $ref = $self->param('genome_file');

  if ($self->{'memory_mode'} eq "default") {
      
      # Check the number of sequences
      
      my $nb_sequences = qx/cat $ref | grep -c ">"/;
      chomp($nb_sequences);
      
      if ($nb_sequences > 50000) {
	  # $self->warning("Too many sequences, $nb_sequences, will pass it on to high memory mode");
	  
	  $self->dataflow_output_id(undef, -1);
	  
	  # Tell the Job we're 'done', so there is no need to carry on
	  $self->input_job->incomplete(0);
	  die "Too many sequences, $nb_sequences, will pass it on to high memory mode";
      }
  }
  
  print STDERR "Indexing $ref\n";

  $self->{aligner}->index_file($ref);
  
  return;
} ## end sub run

sub write_output {
  my ($self) = @_;
  return;
}

1;
