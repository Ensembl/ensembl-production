=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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
    division => [],
    antispecies =>[],
    run_all => 0, #always run every species
    ## Set to '1' for eg! run
    #   default => OFF (0)
    'eg'  => 0,
  }
}

sub pipeline_wide_parameters {
  my $self = shift;
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },
    base_path => $self->o('base_path'),
    # 'eg' flag,
    'eg'      => $self->o('eg'),
    # eg_version & sub_dir parameter in Production/Pipeline/GTF/DumpFile.pm
    # needs to be change , maybe removing the need to eg flag
    'eg_version'    => $self->o('release'),
    'sub_dir'       => $self->o('base_path'),
  }
}

sub pipeline_analyses {
  my $self = shift;
  return [ {
    -logic_name => 'ScheduleSpecies',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::BaseSpeciesFactory',
    -input_ids => [{}], # required for automatic seeding
    -parameters => {
       species     => $self->o('species'),
       antispecies => $self->o('antispecies'),
       division    => $self->o('division'),
       run_all     => $self->o('run_all'),
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
      3 => ['ChecksumGenerator'],
    }
  },
  {
    -logic_name => 'ChecksumGenerator',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::ChecksumGenerator',
    -wait_for   => [ qw/DumpRDF/ ],
    -analysis_capacity => 10,
  },
  {
    -logic_name => 'ValidateRDF',
    -module => 'Bio::EnsEMBL::Production::Pipeline::RDF::ValidateRDF',
    -rc_name => 'verify',
    # All the jobs can fail since it's a validation step
    -failed_job_tolerance => 100,
    # Only retry to run the job once
    -max_retry_count => 1,
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
