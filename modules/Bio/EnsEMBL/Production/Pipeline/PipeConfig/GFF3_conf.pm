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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GFF3_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
    my ($self) = @_;
    
    return {
      # inherit other stuff from the base class
      %{ $self->SUPER::default_options() }, 
      
      ### OVERRIDE
      
      #'registry' => 'Reg.pm', # default option to refer to Reg.pm, should be full path
      #'base_path' => '', #where do you want your files
      
      ### Optional overrides        
      species => [],
      
      # the release of the data
      release => software_version(),

      # always run every species
      run_all => 0, 

      ### Defaults 
      
      pipeline_name => 'gff3_dump_'.$self->o('release'),
      
      ## GFF3 specific options
      feature_type     => ['Gene', 'Transcript'],
      per_chromosome   => 0,
      include_scaffold => 1,
      logic_name       => [],
      db_type          => 'core',
      out_file_stem    => undef,
      xrefs            => 0,
      gt_exe        => '/software/ensembl/central/bin/gt',
      gff3_tidy     => $self->o('gt_exe').' gff3 -tidy -sort -retainids',
      gff3_validate => $self->o('gt_exe').' gff3validator',

      ## Dump out files with abinitio predictions as well
      abinitio         => 1,

      email => $self->o('ENV', 'USER').'@sanger.ac.uk',
      
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
      # inheriting database and hive tables' creation
      @{$self->SUPER::pipeline_create_commands}, 
    ];
}

## See diagram for pipeline structure 
sub pipeline_analyses {
    my ($self) = @_;
    
    return [
    
      {
        -logic_name => 'ScheduleSpecies',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::SpeciesFactory',
        -parameters => {
          species => $self->o('species'),
          randomize => 1,
        },
        -input_ids  => [ {} ],
        -flow_into  => {
          1 => 'Notify',
          2 => [ qw/DumpGFF3 ChecksumGeneratorGFF3/ ]
        },
      },
      
      ######### DUMPING DATA

      {
        -logic_name => 'DumpGFF3',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::GFF3::DumpFile',
        -parameters => {
          feature_type       => $self->o('feature_type'),
          per_chromosome     => $self->o('per_chromosome'),
          include_scaffold   => $self->o('include_scaffold'),
          logic_name         => $self->o('logic_name'),
          db_type            => $self->o('db_type'),
          abinitio           => $self->o('abinitio'),
          out_file_stem      => $self->o('out_file_stem'),
          xrefs              => $self->o('xrefs'),
        },
        -max_retry_count  => 1,
        -analysis_capacity => 30,
        -rc_name => 'dump',
        -flow_into         => ['gff3Tidy'],
      },


      ####### DATA TIDY

      {
        -logic_name        => 'gff3Tidy',
        -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -analysis_capacity => 10,
        -batch_size        => 10,
        -parameters        => {
                                cmd => $self->o('gff3_tidy').' -gzip -o #out_file#.sorted.gz #out_file#',
                              },
        -rc_name           => 'dump',
        -flow_into         => ['gff3Move'],
      },

      {
        -logic_name        => 'gff3Move',
        -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -analysis_capacity => 10,
        -parameters        => {
                                cmd => 'mv #out_file#.sorted.gz #out_file#',
                              },
        -rc_name           => 'dump',
        -flow_into         => ['gff3Validate'],
        -meadow_type       => 'LOCAL',
      },

      {
        -logic_name        => 'gff3Validate',
        -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -analysis_capacity => 10,
        -batch_size        => 10,
        -parameters        => {
                                cmd => $self->o('gff3_validate').' #out_file#',
                              },
        -rc_name           => 'dump',
      },

      ####### CHECKSUMMING
      
      {
        -logic_name => 'ChecksumGeneratorGFF3',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::GFF3::ChecksumGenerator',
        -wait_for   => ['gff3Validate', 'DumpGFF3'],
        -hive_capacity => 10,
      },
      
      ####### NOTIFICATION
      
      {
        -logic_name => 'Notify',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::GTF::EmailSummary',
        -parameters => {
          email   => $self->o('email'),
          subject => $self->o('pipeline_name').' has finished',
        },
        -wait_for   => [ qw/ChecksumGeneratorGFF3 gff3Tidy DumpGFF3/ ],
      }
    
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    
    return {
        %{ $self->SUPER::pipeline_wide_parameters() },  # inherit other stuff from the base class
        base_path => $self->o('base_path'),
        release => $self->o('release'),
    };
}

# override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
    my $self = shift;
    return "-reg_conf ".$self->o("registry");
}

sub resource_classes {
    my $self = shift;
    return {
      %{$self->SUPER::resource_classes()},
      #Max memory consumed in a previous run was 1354MB. This gives us some breathing room
      dump => { 'LSF' => '-q normal -M1600 -R"select[mem>1600] rusage[mem=1600]"'},
    }
}

1;
