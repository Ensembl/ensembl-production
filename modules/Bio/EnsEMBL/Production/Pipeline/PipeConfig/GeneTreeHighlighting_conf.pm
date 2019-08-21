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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneTreeHighlighting_conf;

=head1 DESCRIPTION

Populate compara table with GO and InterPro terms,
to enable highlighting in the genome browser.

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneTreeHighlighting_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::Version 2.4;

sub default_options {
  my ($self) = @_;

  return {
    %{$self->SUPER::default_options},

    species      => [],
    division     => [],
    run_all      => 0,
    antispecies  => [],
    meta_filters => {},

    ## Allow division of compara database to be explicitly specified
    compara_division => undef,

    # hive_capacity values for analysis
    highlighting_capacity => 20,

  }
}

sub pipeline_analyses {
    my ($self) = @_;

    return [

    { -logic_name  => 'job_factory',
       -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
       -input_ids  => [ {} ] ,
       -parameters => {
                        species      => $self->o('species'),
                        antispecies  => $self->o('antispecies'),
                        division     => $self->o('division'),
                        run_all      => $self->o('run_all'),
                        meta_filters => $self->o('meta_filters'),
                      },
      -rc_name 	       => 'default',
      -max_retry_count => 1,
      -flow_into      => {'2->A' => ['highlight_go'],
                          'A->2' => ['highlight_interpro'],
                         }
    },

    { -logic_name     => 'highlight_go',
      -module         => 'Bio::EnsEMBL::Production::Pipeline::GeneTreeHighlight::HighlightGO',
      -analysis_capacity => $self->o('highlighting_capacity'),
      -parameters      => {
                            compara_division => $self->o('compara_division'),
                          },
      -rc_name 	      => 'default',
    },

    { -logic_name     => 'highlight_interpro',
      -module         => 'Bio::EnsEMBL::Production::Pipeline::GeneTreeHighlight::HighlightInterPro',
      -analysis_capacity => $self->o('highlighting_capacity'),
      -parameters      => {
                            compara_division => $self->o('compara_division'),
                          },
      -rc_name 	      => 'default',
    },
  ];
}


1;
