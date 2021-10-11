=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::RNAGeneXref::AnalysisConfiguration;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Path::Tiny;
use POSIX qw(strftime);

sub run {
  my ($self) = @_;
  my $analyses = $self->param_required('analyses');

  my $aa = $self->core_dba->get_adaptor('Analysis');

  my @filtered_analyses = ();

  foreach my $analysis_config (@{$analyses}) {
    if (-e $$analysis_config{'local_file'}) {
      my $timestamp = path($$analysis_config{'local_file'})->stat->mtime;
      my $datestamp = strftime "%Y-%m-%d", localtime($timestamp);
      $$analysis_config{'db_version'} = $datestamp;

      my $logic_name = $$analysis_config{'logic_name'};
      my $analysis = $aa->fetch_by_logic_name($logic_name);

      if (defined($analysis)) {
        if ($$analysis_config{'db_version'} ne $analysis->db_version) {
          push @filtered_analyses, $analysis_config;
        }
      } else {
        push @filtered_analyses, $analysis_config;
      }
    }
  }

  $self->param('filtered_analyses', \@filtered_analyses);
}

sub write_output {
  my ($self) = @_;

  my $analyses = $self->param('filtered_analyses');

  if ( scalar(@$analyses) ) {
    $self->dataflow_output_id( $analyses, 2 );

    $self->dataflow_output_id( {}, 3 );
  }
}

1;
