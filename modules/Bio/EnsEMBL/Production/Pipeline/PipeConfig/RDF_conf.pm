=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::RDF::Pipeline::PipeConfig::RDF_conf

=head1 DESCRIPTION

Simple pipeline to dump RDF for all core species. Needs a LOD mapping file to function,
and at least 100 GB of scratch space.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::RDF_conf;
use strict;
use parent 'Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf';
use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
  my $self = shift;
  return {
    %{ $self->SUPER::default_options() },
    xref => 1,
    config_file => 'VersioningService/conf/xref_LOD_mapping.json',
    release => software_version(),
    pipeline_name => 'rdf_dump_'.$self->o('release'),
    species => [],
  }
}

sub pipeline_wide_parameters {
  my $self = shift;
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },
    base_path => $self->o('base_path')
  }
}

sub pipeline_analyses {
  my $self = shift;
  return [ {
    -logic_name => 'ScheduleSpecies',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::SpeciesFactory',
    -input_ids => [{}], # required for automatic seeding
    -parameters => {
      species => $self->o('species'),
    },
    -flow_into => {
      2 => ['DumpRDF']
    }
  },
  {
    -logic_name => 'DumpRDF',
    -module => 'Bio::EnsEMBL::Production::Pipeline::RDF::RDFDump',
    -parameters => {
      xref => $self->o('xref'),
      release => $self->o('ensembl_release'),
      config_file => $self->o('config_file'),
    },
    -analysis_capacity => 4,
    -rc_name => 'dump',
    # Validate both output files
    -flow_into => {
      2 => ['ValidateRDF'],
      3 => ['ValidateRDF']
    }
  },
  {
    -logic_name => 'ValidateRDF',
    -module => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
    -parameters => {
      cmd => '#validator# --validate #filename#',
      validator => 'turtle',
    },
    -rc_name => 'verify',

  }];
}

sub beekeeper_extra_cmdline_options {
    my $self = shift;
    return "-reg_conf ".$self->o("registry");
}

# Optionally enable auto-variable passing to Hive.
# sub hive_meta_table {
#   my ($self) = @_;
#   return {
#     %{$self->SUPER::hive_meta_table},
#     hive_use_param_stack  => 1,
#   };
# }
sub resource_classes {
my $self = shift;
  return {
    'dump'      => { LSF => '-q normal -M10000 -R"select[mem>10000] rusage[mem=10000]"' },
    'verify'    => { LSF => '-q small -M1000 -R"select[mem>1000] rusage[mem=1000]"' }
  }
}

1;
