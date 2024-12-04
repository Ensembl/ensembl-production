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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::ProteinFeatures_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    species      => [],
    antispecies  => [],
    division     => [],
    run_all      => 0,
    meta_filters => {},

    # Parameters for dumping and splitting Fasta protein files
    max_seqs_per_file       => 100,
    max_seq_length_per_file => undef,
    max_files_per_directory => 100,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),

    # InterPro settings
    interproscan_path         => '/hps/software/interproscan',
    interproscan_version      => 'current',
   	run_interproscan          => 1,
    local_computation         => 0,
    check_interpro_db_version => 0,

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

    interpro2go_logic_name => 'interpro2go',
    uniparc_logic_name     => 'uniparc_checksum',
    uniprot_logic_name     => 'uniprot_checksum',

    protein_feature_analyses =>
    [
      {
        logic_name      => 'cdd',
        db              => 'CDD',
        program         => 'InterProScan',
        ipscan_name     => 'CDD',
        ipscan_xml      => 'CDD',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'gene3d',
        db              => 'Gene3D',
        program         => 'InterProScan',
        ipscan_name     => 'Gene3D',
        ipscan_xml      => 'GENE3D',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'hamap',
        db              => 'HAMAP',
        program         => 'InterProScan',
        ipscan_name     => 'Hamap',
        ipscan_xml      => 'HAMAP',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'hmmpanther',
        db              => 'PANTHER',
        program         => 'InterProScan',
        ipscan_name     => 'PANTHER',
        ipscan_xml      => 'PANTHER',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'pfam',
        db              => 'Pfam',
        program         => 'InterProScan',
        ipscan_name     => 'Pfam',
        ipscan_xml      => 'PFAM',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'pfscan',
        db              => 'Prosite_profiles',
        program         => 'InterProScan',
        ipscan_name     => 'ProSiteProfiles',
        ipscan_xml      => 'PROSITE_PROFILES',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'pirsf',
        db              => 'PIRSF',
        program         => 'InterProScan',
        ipscan_name     => 'PIRSF',
        ipscan_xml      => 'PIRSF',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'prints',
        db              => 'PRINTS',
        program         => 'InterProScan',
        ipscan_name     => 'PRINTS',
        ipscan_xml      => 'PRINTS',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'scanprosite',
        db              => 'Prosite_patterns',
        program         => 'InterProScan',
        ipscan_name     => 'ProSitePatterns',
        ipscan_xml      => 'PROSITE_PATTERNS',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'sfld',
        db              => 'SFLD',
        program         => 'InterProScan',
        ipscan_name     => 'SFLD',
        ipscan_xml      => 'SFLD',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'smart',
        db              => 'Smart',
        program         => 'InterProScan',
        ipscan_name     => 'SMART',
        ipscan_xml      => 'SMART',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'superfamily',
        db              => 'SuperFamily',
        program         => 'InterProScan',
        ipscan_name     => 'SUPERFAMILY',
        ipscan_xml      => 'SUPERFAMILY',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'ncbifam',
        db              => 'NCBIfam',
        program         => 'InterProScan',
        ipscan_name     => 'NCBIfam',
        ipscan_xml      => 'NCBIFAM',
        ipscan_lookup   => 1,
      },
      {
        logic_name      => 'mobidblite',
        db              => 'MobiDBLite',
        program         => 'InterProScan',
        ipscan_name     => 'MobiDBLite',
        ipscan_xml      => 'MOBIDB_LITE',
        ipscan_lookup   => 0,
      },
      {
        logic_name      => 'ncoils',
        db              => 'ncoils',
        program         => 'InterProScan',
        ipscan_name     => 'Coils',
        ipscan_xml      => 'COILS',
        ipscan_lookup   => 0,
      },
      {
        logic_name      => 'signalp',
        db              => 'SignalP',
        program         => 'InterProScan',
        ipscan_name     => 'SignalP_EUK',
        ipscan_xml      => 'SIGNALP_EUK',
        ipscan_lookup   => 0,
      },
      {
        logic_name      => 'tmhmm',
        db              => 'TMHMM',
        program         => 'InterProScan',
        ipscan_name     => 'TMHMM',
        ipscan_xml      => 'TMHMM',
        ipscan_lookup   => 0,
      },
      {
        db               => 'Phobius',
        ipscan_lookup    => 1,
        ipscan_name      => 'Phobius',
        ipscan_xml       => 'PHOBIUS',
        logic_name       => 'phobius',
        program          => 'InterProScan',
      },
      {
        db              => 'SignalP_GRAM_POSITIVE',
        ipscan_lookup   => 1,
        ipscan_name     => 'SignalP_GRAM_POSITIVE',
        ipscan_xml      => 'SIGNALP_GRAM_POSITIVE',
        logic_name      => 'signalp_gram_positive',
        program         => 'InterProScan',
      },
      {
        db              => 'SignalP_GRAM_NEGATIVE',
        ipscan_lookup   => 1,
        ipscan_name     => 'SignalP_GRAM_NEGATIVE',
        ipscan_xml      => 'SIGNALP_GRAM_NEGATIVE',
        logic_name      => 'signalp_gram_negative',
        program         => 'InterProScan',
      },      
      #seg replaces low complexity regions in protein sequences with X characters(https://rothlab.ucdavis.edu/genhelp/seg.html)
      {
        logic_name      => 'seg',
        db              => 'Seg',
      },
    ],
    xref_analyses =>
    [
      {
        logic_name => $self->o('interpro2go_logic_name'),
        db         => 'InterPro2GO',
        annotate   => 1,
        local_file => $self->o('interpro2go_file_local'),
      },
      {
        logic_name => $self->o('uniparc_logic_name'),
        db         => 'UniParc',
        annotate   => $self->o('uniparc_xrefs'),
        local_file => $self->o('uniparc_file_local'),
      },
      {
        logic_name => $self->o('uniprot_logic_name'),
        db         => 'UniProt',
        annotate   => $self->o('uniprot_xrefs'),
        local_file => $self->o('mapping_file_local'),
      },
    ],

    # Remove existing analyses; if =0 then existing analyses
    # will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,

    # seg analysis is not part of InterProScan, so is always run locally.
    run_seg    => 0,
    seg_exe    => 'seg',
    seg_params => '-l -n',

    # Config/history files for storing record of datacheck run.
    config_file  => undef,
    history_file => undef,

    # By default the pipeline won't email with a summary of the results.
    # If this is switched on, you get one email per species.
    email_report => 0,
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
    email_report => $self->o('email_report'),
  };
}

sub pipeline_analyses {
  my $self = shift @_;

  return [
    {
      -logic_name      => 'FetchFiles',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -parameters      => {
                            local_computation => $self->o('local_computation'),
                          },
      -flow_into       => WHEN('#local_computation#' =>
                            ['FetchInterPro', 'FetchInterPro2GO'],
                          ELSE
                            ['FetchUniParc', 'FetchInterPro', 'FetchInterPro2GO']
                          ),
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
