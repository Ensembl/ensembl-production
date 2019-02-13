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

  Bio::EnsEMBL::Production::Pipeline::PipeConfig::AutoCompleteStableIds_conf

=head1 DESCRIPTION

  Web Gene autocomplete database creation pipeline

=head1 AUTHOR

 mchakiachvili@ebi.ac.uk

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::AutoCompleteStableIds_conf;
use strict;
use warnings FATAL => 'all';

sub default_options {
  my ($self) = @_;
  return {
      %{$self->SUPER::default_options},
      'no_delete'             => 0, # By default delete complete set
      'pipeline_name'         => 'gene_autocomplete_' . $self->o('ens_version'),
      'autocomplete_database' => 'ensembl_web_site_'. $self->o('ens_version')
  }
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
      %{$self->SUPER::pipeline_wide_parameters},               # here we inherit anything from the base class
      'pipeline_name'            => $self->o('pipeline_name'), #This must be defined for the beekeeper to work properly
      'release'                  => $self->o('ens_version'),
      'eg_version'               => $self->o('eg_version'),
      'no_delete'                => $self->o('no_delete'),
      'sub_dir'                  => $self->o('ftp_dir'),
      'stable_id_script'         => $self->o('ensembl_cvs_root_dir') . '/ensembl/misc-scripts/stable_id_lookup/populate_stable_id_lookup.pl',
      'gene_autocomplete_script' => $self->o('ensembl_cvs_root_dir') . '/ensembl/misc-scripts/stable_id_lookup/populate_stable_id_lookup.pl',
      'staging_user'             => $self->o('staging_user'),
      'staging_host'             => $self->o('staging_host'),
      'staging_port'             => $self->o('staging_port'),
      'autocomplete_database'    => $self->o('autocomplete_database'),
      'species'                  => $self->o('species')
  };
}

sub resource_classes {
  my $self = shift;
  return {
      'default' => { 'LSF' => '-q production-rh7 -n 4 -M 4000   -R "rusage[mem=4000]"' },
      '16GB'    => { 'LSF' => '-q production-rh7 -n 4 -M 16000   -R "rusage[mem=16000]"' },
      '32GB'    => { 'LSF' => '-q production-rh7 -n 4 -M 32000  -R "rusage[mem=32000]"' },
      '64GB'    => { 'LSF' => '-q production-rh7 -n 4 -M 64000  -R "rusage[mem=64000]"' },
      '128GB'   => { 'LSF' => '-q production-rh7 -n 4 -M 128000 -R "rusage[mem=128000]"' },
      '256GB'   => { 'LSF' => '-q production-rh7 -n 4 -M 256000 -R "rusage[mem=256000]"' },
  }
}


sub pipeline_analyses {
  my ($self) = @_;
  return [
      {
          -logic_name => 'gene_autocomplete_setup',
          -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
          -input_ids  => [ {} ],
          -parameters => {
              'sql' => [
                  qq/
                  CREATE TABLE IF NOT EXISTS gene_autocomplete (
                      species       varchar(255) DEFAULT NULL,
                      stable_id     varchar(128) NOT NULL DEFAULT "",
                      display_label varchar(128) DEFAULT NULL,
                      location      varchar(60)  DEFAULT NULL,
                      db            varchar(32)  NOT NULL DEFAULT "core",
                      KEY i  (species, display_label),
                      KEY i2 (species, stable_id),
                      KEY i3 (species, display_label, stable_id);
                  / ],
          },
          -rc_name    => [ 'default' ],
          -flow_into  => {
              1 => WHEN(
                  '#species#' => [ 'specie_autocomplete' ],
                  ELSE [ 'full_autocomplete' ]
              )
          },
      },
      {
          -logic_name => 'specie_autocomplete',
          -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
          -parameters => {
              "species_list" => "#expr( join(',', @{ #species#}) ) expr#",
              'sql' => [ qq/DELETE FROM gene_autocomplete WHERE species IN ('#species_list#');/],
          },
          -rc_name    => [ 'default' ],
          -flow_into => [ '']
      },
      {
          -logic_name => 'full_autocomplete',
          -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
          -parameters => {
              'sql' => [
                  qq/TRUNCATE gene_autocomplete;/
              ],
          },
          -rc_name    => [ 'default' ],
      },
      {
          -logic_name      => "gene_auto_complete",
          -module          => 'Bio::EnsEMBL::Production::Pipeline::GeneAutocomplete::CreateGeneAutoComplete',
          -max_retry_count => 1,
          -parameters      => {

          }
      },
      {
          -logic_name      => 'stable_ids',
          -module          => 'Bio::EnsEMBL::Production::Pipeline::StableIds::StableIds',
          -max_retry_count => 1,
          -input_ids       => [ {} ],
          -parameters      => {
              'inputcmd' => $self->o('stable_id_script') . ' -lhost ' . $self->o('staging_host') . '-luser' . $self->o('staging_user') . '-lpass ' . $self->o('staging_pass') . '-lport ' . $self->o('staging_port') . '-dbname ensembl_stable_ids_' . $self->o('release') . ' -create -host ' . $self->o('ensprod_host') . ' -user ' . $self->o('ensprod_user') . ' -port ' . $self->o('ensprod_port') . ' -version ' . $self->o('release') . ' -create_index',
          },
          -rc_name         => '16GB',
          -flow_into       => [ 'gene_auto_complete' ],
      },
  ]
}

1;