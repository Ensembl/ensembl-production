=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::ProteinFeaturesReferenceDB_conf;

use strict;
use warnings;

# use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    protein_reference_db_uri => self->o('protein_reference_db_uri')

    # Load UniParc/UniProt xrefs.
    uniparc_xrefs => 0,
    uniprot_xrefs => 0,

    # We need some data files, all of which we should be able to get from the
    # local file system, because they are created by other groups at the EBI.
    # If not, the code falls back on externally-available routes.
    # From UniParc, we get a list of protein sequence md5sums, which will
    # be in the InterProScan lookup service. From InterPro, we get: a list of
    # all the entries with descriptions, which are loaded as xrefs; and a
    # mapping between InterPro and GO terms, so that we can transitively
    # annotate GO xrefs. Optionally, we may also want a mapping between
    # UniParc and UniProt IDs, in order to create UniProt xrefs.
    interpro_ebi_path => '/nfs/ftp/public/databases/interpro/current_release',
    interpro_ftp_uri  => 'ftp://ftp.ebi.ac.uk/pub/databases/interpro/current_release',
    uniparc_ebi_path  => '/nfs/ftp/public/contrib/uniparc',
    uniparc_ftp_uri   => 'ftp://ftp.ebi.ac.uk/pub/contrib/uniparc',
    uniprot_ebi_path  => '/nfs/ftp/public/databases/uniprot/current_release/knowledgebase/idmapping',
    uniprot_ftp_uri   => 'ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/idmapping',

    interpro_file    => 'names.dat',
    interpro2go_file => 'interpro2go',
    uniparc_file     => 'upidump.lis.gz',
    mapping_file     => 'idmapping_selected.tab.gz',

    # Files are retrieved and stored locally with the same name.
    interpro_file_local    => catdir($self->o('pipeline_dir'), $self->o('interpro_file')),
    interpro2go_file_local => catdir($self->o('pipeline_dir'), $self->o('interpro2go_file')),
    uniparc_file_local     => catdir($self->o('pipeline_dir'), $self->o('uniparc_file')),
    mapping_file_local     => catdir($self->o('pipeline_dir'), $self->o('mapping_file')),
    uniprot_file_local     => catdir($self->o('pipeline_dir'), 'uniprot.txt'),
  };

}

# Ensures that species output parameter gets propagated implicitly.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  my $uniparc_table_sql = q/
    CREATE TABLE uniparc (
      upi VARCHAR(13) NOT NULL,
      md5sum VARCHAR(32) NOT NULL COLLATE latin1_swedish_ci
    );
  /;

  my $uniprot_table_sql = q/
    CREATE TABLE uniprot (
      acc VARCHAR(10) NOT NULL,
      upi VARCHAR(13) NOT NULL,
      tax_id INT NOT NULL
    );
  /;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('pipeline_dir'),
    'mkdir -p '.$self->o('scratch_large_dir'),
    $self->db_cmd($uniparc_table_sql),
    $self->db_cmd($uniprot_table_sql),
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    pipeline_dir => $self->o('pipeline_dir'),
    scratch_dir  => $self->o('scratch_large_dir'),
  };
}

sub pipeline_analyses {
  my $self = shift @_;

  return [
    {
      -logic_name      => 'FetchFiles',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -flow_into       => ['FetchUniParc', 'FetchInterPro', 'FetchInterPro2GO']
                          
    },

    {
      -logic_name      => 'FetchInterPro',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::FetchFile',
      -max_retry_count => 1,
      -parameters      => {
                            ebi_path    => $self->o('interpro_ebi_path'),
                            ftp_uri     => $self->o('interpro_ftp_uri'),
                            remote_file => $self->o('interpro_file'),
                            local_file  => $self->o('interpro_file_local'),
                          },
      -rc_name         => 'dm',
    },

    {
      -logic_name      => 'FetchInterPro2GO',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::FetchFile',
      -max_retry_count => 1,
      -parameters      => {
                            ebi_path    => $self->o('interpro_ebi_path'),
                            ftp_uri     => $self->o('interpro_ftp_uri'),
                            remote_file => $self->o('interpro2go_file'),
                            local_file  => $self->o('interpro2go_file_local'),
                          },
      -rc_name         => 'dm',
    },

    {
      -logic_name      => 'FetchUniParc',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::FetchFile',
      -max_retry_count => 1,
      -parameters      => {
                            ebi_path      => $self->o('uniparc_ebi_path'),
                            ftp_uri       => $self->o('uniparc_ftp_uri'),
                            remote_file   => $self->o('uniparc_file'),
                            local_file    => $self->o('uniparc_file_local'),
                            uniprot_xrefs => $self->o('uniprot_xrefs'),
                          },
      -flow_into       => WHEN('#uniprot_xrefs#' =>
                            ['FetchUniProt', 'LoadUniParc'],
                          ELSE
                            ['LoadUniParc']
                          ),
      -rc_name         => 'dm',
    },

    {
      -logic_name      => 'FetchUniProt',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::FetchFile',
      -max_retry_count => 1,
      -parameters      => {
                            ebi_path    => $self->o('uniprot_ebi_path'),
                            ftp_uri     => $self->o('uniprot_ftp_uri'),
                            remote_file => $self->o('mapping_file'),
                            local_file  => $self->o('mapping_file_local'),
                          },
      -flow_into       => ['LoadUniProt'],
      -rc_name         => 'dm',
    },

    {
      -logic_name      => 'LoadUniParc',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::LoadUniParc',
      -max_retry_count => 1,
      -parameters      => {
                            uniparc_file_local => $self->o('uniparc_file_local'),
                          },
      -rc_name           => '2GB_W',

    },

    {
      -logic_name      => 'LoadUniProt',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::LoadUniProt',
      -max_retry_count => 1,
      -parameters      => {
                            mapping_file_local => $self->o('mapping_file_local'),
                            uniprot_file_local => $self->o('uniprot_file_local'),
                          },
      -flow_into       => ['dump_unparc_table_into_protein_reference_db'],
    },
    {
      -logic_name => 'dump_unparc_table_into_protein_reference_db',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
      -parameters => {
                       dest_db_conn => $self->o('protein_reference_db_uri'),
                       table => 'uniparc',
                       renamed_table => 'uniparc_new'
                      },
      -flow_into  => { 1 => 'create_taxonomy_table_in_metadata_db_if_not_exists' },
    },
    {
      -logic_name => 'dump_unprot_table_into_protein_reference_db',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
      -parameters => {
                       dest_db_conn => $self->o('protein_reference_db_uri'),
                       table => 'uniprot',
                       renamed_table => 'uniprot_new'
                      },
      -flow_into  => { 1 => 'rename_tables_in_target_db' },
    },

    {
      -logic_name => 'rename_tables_in_target_db',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
      -parameters => {
                        db_conn => $self->o('protein_reference_db_uri'),
                        sql => [
                                qw{
                                 },

                                 "RENAME TABLE uniparc TO uniparc_back",
                                 "RENAME TABLE uniparc_new TO uniparc",
                                 "RENAME TABLE uniprot TO uniprot_back",
                                 "RENAME TABLE uniprot_new TO uniprot",
                               ]
                      },
      -flow_into  => { 1 => 'drop_back_up_in_reference_db' },
    },
    {
      -logic_name => 'drop_back_up_in_reference_db',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
      -parameters => {
                        db_conn => $self->o('metadata_db_uri'),
                        sql => [
                                 "DROP TABLE IF EXISTS uniparc_back",
                                 "DROP TABLE IF EXISTS uniprot_back",
                               ]
                      },
      -flow_into  => { 1 => 'TidyScratch' },
    },
    {
      -logic_name        => 'TidyScratch',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              cmd => 'rm -rf #scratch_dir# && rm -rf #pipeline_dir#',
                            },
      -flow_into  => 'CleanTables',
    }
    {
        -logic_name => 'CleanTables',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
        -parameters => {
            sql => 'DROP table uniparc; drop table uniprot',
        },
    },
  ];
}

sub resource_classes {
  my ($self) = @_;

  return {
    %{$self->SUPER::resource_classes},
    '16GB_8CPU' => {'LSF' => '-q '.$self->o('production_queue').' -n 8 -M 16000 -R "rusage[mem=16000]"',
                          'SLURM' => ' --partition=standard --time=1-00:00:00  --mem=16000m -n 8 -N 1'},
    '32GB_8CPU' => {'LSF' => '-q '.$self->o('production_queue').' -n 8 -M 32000 -R "rusage[mem=32000]"',
                    'SLURM' => ' --partition=standard --time=1-00:00:00  --mem=32000m -n 8 -N 1'},
  }
}

1;
