=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2025] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::ProteinFeaturesMVP_RunInterpro_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version;

use File::Spec::Functions qw(catdir);

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        species                              => [],
        antispecies                          => [],
        division                             => [],
        run_all                              => 0,
        meta_filters                         => {},

        # Parameters for dumping and splitting Fasta protein files
        max_seqs_per_file                    => 100,
        max_seq_length_per_file              => undef,
        max_files_per_directory              => 100,
        max_dirs_per_directory               => $self->o('max_files_per_directory'),

        # InterPro settings
        interproscan_path                    => '/hps/software/interproscan',
        interproscan_version                 => 'current',
        run_interproscan                     => 1,
        local_computation                    => 0,
        check_interpro_db_version            => 0,

        # Load UniParc/UniProt xrefs.
        uniparc_xrefs                        => 0,
        uniprot_xrefs                        => 0,

        # We need some data files, all of which we should be able to get from the
        # local file system, because they are created by other groups at the EBI.
        # If not, the code falls back on externally-available routes.
        # From UniParc, we get a list of protein sequence md5sums, which will
        # be in the InterProScan lookup service. From InterPro, we get: a list of
        # all the entries with descriptions, which are loaded as xrefs; and a
        # mapping between InterPro and GO terms, so that we can transitively
        # annotate GO xrefs. Optionally, we may also want a mapping between
        # UniParc and UniProt IDs, in order to create UniProt xrefs.
        interpro_ebi_path                    => '/nfs/ftp/public/databases/interpro/current_release',
        interpro_ftp_uri                     => 'ftp://ftp.ebi.ac.uk/pub/databases/interpro/current_release',
        uniparc_ebi_path                     => '/nfs/ftp/public/contrib/uniparc',
        uniparc_ftp_uri                      => 'ftp://ftp.ebi.ac.uk/pub/contrib/uniparc',
        uniprot_ebi_path                     => '/nfs/ftp/public/databases/uniprot/current_release/knowledgebase/idmapping',
        uniprot_ftp_uri                      => 'ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/idmapping',

        interpro_file    => 'names.dat',
        interpro2go_file => 'interpro2go',
        uniparc_file     => 'upidump.lis.gz',
        mapping_file     => 'idmapping_selected.tab.gz',

        # Files are retrieved and stored locally with the same name.    #TODO: Add subdirectory resource 
        interpro_file_local                  => catdir($self->o('pipeline_dir'), $self->o('interpro_file')),
        interpro2go_file_local               => catdir($self->o('pipeline_dir'), $self->o('interpro2go_file')),
        uniparc_file_local                   => catdir($self->o('pipeline_dir'), $self->o('uniparc_file')),
        mapping_file_local                   => catdir($self->o('pipeline_dir'), $self->o('mapping_file')),
        uniprot_file_local                   => catdir($self->o('pipeline_dir'), 'uniprot.txt'),

        interpro2go_logic_name               => 'interpro2go',
        uniparc_logic_name                   => 'uniparc_checksum',
        uniprot_logic_name                   => 'uniprot_checksum',

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
        delete_existing                      => 1,

        # seg analysis is not part of InterProScan, so is always run locally.
        run_seg                              => 0,
        seg_exe                              => 'seg',
        seg_params                           => '-l -n',

        # Config/history files for storing record of datacheck run.
        config_file                          => undef,
        history_file                         => undef,

        # By default the pipeline won't email with a summary of the results.
        # If this is switched on, you get one email per species.
        email_report                         => 0,
        'dataset_type'                       => 'protein_features',
        'genome_factory_dynamic_output_flow' => {
            '3->A' => { 'InterProScanVersionCheck' => INPUT_PLUS() },
            'A->3' => [ { 'UpdateDatasetStatus' => INPUT_PLUS() } ]
        },
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
    return [
        @{$self->SUPER::pipeline_create_commands},
        'mkdir -p ' . $self->o('pipeline_dir'),
        'mkdir -p ' . $self->o('scratch_large_dir'),
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
        @{Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf::factory_analyses($self)},
        {
            -logic_name      => 'InterProScanVersionCheck',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScanVersionCheck',
            -max_retry_count => 0,
            -parameters      => {
                interproscan_path    => $self->o('interproscan_path'),
                interproscan_version => $self->o('interproscan_version'),
                local_computation    => $self->o('local_computation'),
            },
            -flow_into       => {
              '3' => [ 'AnnotateProteinFeatures' ],
            },
            -rc_name           => '4GB_D',
        },
        {
            -logic_name      => 'AnnotateProteinFeatures',
            -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -max_retry_count => 0,
            -flow_into       => {
                '1' => [ 'DbFactory' ],
            },
            -rc_name           => '1GB_D',
        },
        {
            -logic_name      => 'DbFactory',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
            -max_retry_count => 1,
            -parameters      => {
                species      => $self->o('species'),
                antispecies  => $self->o('antispecies'),
                division     => $self->o('division'),
                run_all      => $self->o('run_all'),
                meta_filters => $self->o('meta_filters'),
            },
            -flow_into       => {
                '2' => [ 'AnalysisConfiguration' ],
            },
            -rc_name           => '4GB_D',
        },
        {
          -logic_name        => 'AnalysisConfiguration',
          -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::AnalysisConfiguration',
          -max_retry_count   => 0,
          -parameters        => {
                                  protein_feature_analyses  => $self->o('protein_feature_analyses'),
                                  check_interpro_db_version => $self->o('check_interpro_db_version'),
                                  run_seg                   => $self->o('run_seg'),
                                  xref_analyses             => $self->o('xref_analyses'),
                                },
          -rc_name           => '8GB_D',

          -flow_into 	       => {
                                  '2->A' => ['AnalysisSetup'],            #Todo: we can remove analsysi step in inthis pipleine assumimg analysis logics are added via production db pipleine by datateams before handover 
                                  'A->3' => ['SpeciesFactory'],
                                }
        },
        {
            -logic_name        => 'AnalysisSetup',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::AnalysisSetup',
            -max_retry_count   => 0,
            -analysis_capacity => 20,
            -parameters        => {
                db_backup_required => 1,
                db_backup_file     => catdir('#pipeline_dir#', '#dbname#', 'pre_pipeline_bkp.sql.gz'),
                delete_existing    => $self->o('delete_existing'),
                linked_tables      => [ 'protein_feature', 'object_xref' ],
                production_lookup  => 1,
            },
            -rc_name           => '8GB_D',
        },
        {
          -logic_name        => 'SpeciesFactory',
          -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbAwareSpeciesFactory',
          -max_retry_count   => 1,
          -analysis_capacity => 20,
          -parameters        => {},
          -flow_into         => {
                                  '2' => ['DumpProteome'],
                                },
          -rc_name           => '4GB_D',

        },

        {
          -logic_name        => 'DumpProteome',   #chage the proteome_dir to the  standard location 
          -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DumpProteome',
          -max_retry_count   => 0,
          -analysis_capacity => 20,
          -parameters        => {
                                  proteome_dir => catdir('#pipeline_dir#', '#species#'),
                                  header_style => 'dbID',
                                  overwrite    => 1,
                                },
          -flow_into         => {
                                  '-1' => ['DumpProteome_HighMem'],
                                  '1'  => ['SplitDumpFile', 'ChecksumProteinsMVP'],
                                },
          -rc_name           => '16GB_D',
        },
        {
            -logic_name        => 'DumpProteome_HighMem', #chage the proteome_dir to the  standard location
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DumpProteome',
            -max_retry_count   => 0,
            -analysis_capacity => 20,
            -parameters        => {
                proteome_dir => catdir('#pipeline_dir#', '#species#'),
                header_style => 'dbID',
                overwrite    => 1,
            },
            -rc_name           => '32GB_D',
            -flow_into         => {
                '1' => [ 'SplitDumpFile', 'ChecksumProteinsMVP' ],
            },
        },

        {
          -logic_name        => 'SplitDumpFile',
          -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::FastaSplit',
          -max_retry_count   => 0,
          -analysis_capacity => 50,
          -parameters        => {
                                  fasta_file              => '#proteome_file#',
                                  max_seqs_per_file       => $self->o('max_seqs_per_file'),
                                  max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                                  max_files_per_directory => $self->o('max_files_per_directory'),
                                  max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                                },
          -rc_name           => '4GB_D',
          -flow_into         => {
                                  '2' => ['RunSeg'],
                                },
        },
        {
          -logic_name        => 'RunSeg',
          -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
          -analysis_capacity => 10,
          -batch_size        => 10,
          -max_retry_count   => 1,
          -parameters        =>
          {
            cmd => $self->o('seg_exe').' #split_file# '.$self->o('seg_params').' > #split_file#.seg.txt',
          },
          -rc_name           => '4GB_D',
        },
        {
          -logic_name        => 'ChecksumProteinsMVP',
          -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::ChecksumProteinsMVP',
          -analysis_capacity => 50,
          -max_retry_count   => 0,
          -parameters        => {
                                  fasta_file         => '#proteome_file#',
                                  uniparc_xrefs      => $self->o('uniparc_xrefs'),
                                  uniprot_xrefs      => $self->o('uniprot_xrefs'),
                                  uniparc_logic_name => $self->o('uniparc_logic_name'),
                                  uniprot_logic_name => $self->o('uniprot_logic_name'),
                                },
          -rc_name           => '8GB_D',
          -flow_into         => {
                                  '3' => ['SplitChecksumFile'],
                                  '4' => ['SplitNoChecksumFile'],
                                },
        },
        {
            -logic_name        => 'SplitChecksumFile',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::FastaSplit',
            -analysis_capacity => 50,
            -max_retry_count   => 0,
            -parameters        => {
                fasta_file              => '#checksum_file#',
                max_seqs_per_file       => $self->o('max_seqs_per_file'),
                max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                max_files_per_directory => $self->o('max_files_per_directory'),
                max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                delete_existing_files   => $self->o('run_interproscan'),
            },
            -flow_into         => {
                '2' => [ 'InterProScanLookup', 'InterProScanNoLookup' ],
            },
            -rc_name           => '8GB_D',
        },
        {
            -logic_name        => 'SplitNoChecksumFile',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::FastaSplit',
            -analysis_capacity => 50,
            -max_retry_count   => 0,
            -parameters        => {
                fasta_file              => '#nochecksum_file#',
                max_seqs_per_file       => $self->o('max_seqs_per_file'),
                max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                max_files_per_directory => $self->o('max_files_per_directory'),
                max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                delete_existing_files   => $self->o('run_interproscan'),
            },
            -flow_into         => {
                '2' => [ 'InterProScanLocal' ],
            },
            -rc_name           => '8GB_D',
        },

        {
            -logic_name      => 'InterProScanLookup',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
            -hive_capacity   => 200,
            -max_retry_count => 1,
            -parameters      =>
                {
                    input_file                => '#split_file#',
                    run_mode                  => 'lookup',
                    interproscan_applications => '#interproscan_lookup_applications#',
                    run_interproscan          => $self->o('run_interproscan'),
                },
            -rc_name         => '8GB_W',
            -flow_into       => {
                # '3'  => [ 'StoreInterProxmlforProteinFeatures' ],
                '-1' => [ 'InterProScanLookup_HighMem' ],
            },
        },

        {
            -logic_name      => 'InterProScanLookup_HighMem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
            -hive_capacity   => 200,
            -max_retry_count => 1,
            -parameters      =>
                {
                    input_file                => '#split_file#',
                    run_mode                  => 'lookup',
                    interproscan_applications => '#interproscan_lookup_applications#',
                    run_interproscan          => $self->o('run_interproscan'),
                },
            -rc_name         => '50GB_D',
        },

        {
          -logic_name        => 'InterProScanNoLookup',
          -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
          -hive_capacity     => 200,
          -max_retry_count   => 1,
          -parameters        =>
          {
            input_file                => '#split_file#',
            run_mode                  => 'nolookup',
            interproscan_applications => '#interproscan_nolookup_applications#',
            run_interproscan          => $self->o('run_interproscan'),
          },
          -rc_name           => '32GB_8CPU',
          -flow_into         => {
                                  '-1' => ['InterProScanNoLookup_HighMem'],
                                },
        },

        {
            -logic_name      => 'InterProScanNoLookup_HighMem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
            -hive_capacity   => 200,
            -max_retry_count => 1,
            -parameters      =>
                {
                    input_file                => '#split_file#',
                    run_mode                  => 'nolookup',
                    interproscan_applications => '#interproscan_nolookup_applications#',
                    run_interproscan          => $self->o('run_interproscan'),
                },
            -rc_name         => '64GB_8CPU',
        },

        {
          -logic_name        => 'InterProScanLocal',
          -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
          -hive_capacity     => 200,
          -max_retry_count   => 1,
          -parameters        =>
          {
            input_file                => '#split_file#',
            run_mode                  => 'local',
            interproscan_applications => '#interproscan_local_applications#',
            run_interproscan          => $self->o('run_interproscan'),
          },
          -rc_name           => '32GB_8CPU',
          -flow_into         => {
                                  '-1' => ['InterProScanLocal_HighMem'],
                                },
        },
        {
            -logic_name      => 'InterProScanLocal_HighMem',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::InterProScan',
            -hive_capacity   => 200,
            -max_retry_count => 1,
            -parameters      =>
                {
                    input_file                => '#split_file#',
                    run_mode                  => 'local',
                    interproscan_applications => '#interproscan_local_applications#',
                    run_interproscan          => $self->o('run_interproscan'),
                },
            -rc_name         => '64GB_8CPU',
        },

    ];
}

sub resource_classes {
    my ($self) = @_;

  return {
    %{$self->SUPER::resource_classes},
    '4GB_8CPU'  => { 'LSF' => '-q ' . $self->o('production_queue') . ' -n 8 -M  4000 -R "rusage[mem=4000]"' },
    '16GB_8CPU' => {'LSF' => '-q '.$self->o('production_queue').' -n 8 -M 16000 -R "rusage[mem=16000]"',
                          'SLURM' => ' --partition=standard --time=7-00:00:00  --mem=16000m -n 8 -N 1'},
    '32GB_8CPU' => {'LSF' => '-q '.$self->o('production_queue').' -n 8 -M 32000 -R "rusage[mem=32000]"',
                    'SLURM' => ' --partition=standard --time=7-00:00:00  --mem=32000m -n 8 -N 1'},

    '64GB_8CPU' => {'SLURM' => ' --partition=standard --time=7-00:00:00  --mem=64000m -n 8 -N 1'},
  }
}

1;
