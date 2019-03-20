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

=cut

package Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeEBeye;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use Bio::EnsEMBL::Production::Search::EBeyeFormatter;

use JSON;
use File::Slurp qw/read_file/;
use Carp qw(croak);

use Log::Log4perl qw/:easy/;
use Data::Dumper;

sub run {
  my ($self) = @_;
  if ($self->debug()) {
    Log::Log4perl->easy_init($DEBUG);
  }
  else {
    Log::Log4perl->easy_init($INFO);
  }
  $self->{logger} = get_logger();

  my $genome_file = $self->param_required('genome_file');
  my $type = $self->param_required('type');
  my $genome = decode_json(read_file($genome_file));

  my $species = $self->param_required('species');
  my $sub_dir = $self->get_data_path('ebeye');

  my $reformatter = Bio::EnsEMBL::Production::Search::EBeyeFormatter->new();
  my $output = { species => $species };

  if ($type eq 'core') {
    my $genome_file_out = $sub_dir . '/' . $species . '_genome.xml';
    $self->{logger}->info("Reformatting $genome_file into $genome_file_out");
    $reformatter->reformat_genome($genome_file, $genome_file_out);
    $output->{genome_xml_file} = $genome_file_out;
  }
  my $dba = $self->get_DBAdaptor($type);

  my $genes_file = $self->param('genes_file');
  if (defined $genes_file) {
    my $genes_file_out = $sub_dir . '/' . $species . '_genes' .
        ($type ne 'core' ? "_${type}" : '') . '.xml';
    $self->{logger}->info("Reformatting $genes_file into $genes_file_out");
    $reformatter->reformat_genes($genome_file, $dba->dbc()->dbname(),
        $genes_file, $genes_file_out);
    $output->{genes_xml_file} = $genes_file_out;
  }

  my $sequences_file = $self->param('sequences_file');
  if (defined $sequences_file) {
    my $sequences_file_out = $sub_dir . '/' . $species . '_sequences' .
        ($type ne 'core' ? "_${type}" : '') . '.xml';
    $self->{logger}->info("Reformatting $sequences_file into $sequences_file_out");
    $reformatter->reformat_sequences($genome_file, $dba->dbc()->dbname(),
        $sequences_file, $sequences_file_out
    );
    $output->{sequences_xml_file} = $sequences_file_out;
  }

  $self->dataflow_output_id( $output, 1 );
  return;
} ## end sub run

1;
