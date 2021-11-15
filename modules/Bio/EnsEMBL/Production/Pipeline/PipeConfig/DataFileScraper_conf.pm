=pod
=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 LICENSE
    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2021] EMBL-European Bioinformatics Institute
    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
         http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.
=head1 CONTACT
    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates
=cut


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DataFileScraper_conf;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        'pipeline_name' => 'datafile_scraper',
        'ftp_dir_ens'   => '/nfs/ensemblftp/PUBLIC/pub',
        'ftp_dir_eg'    => '/nfs/ensemblgenomes/ftp/pub',
        'ftp_url_ens'   => 'ftp://ftp.ensembl.org/pub',
        'ftp_url_eg'    => 'ftp://ftp.ensemblgenomes.org/pub',

        user  => $ENV{'USER'},
        email => $ENV{'USER'}.'@ebi.ac.uk',

        production_queue => 'production',
    }
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},

        # Create/alter tables used by ensembl.production.core.models.hive Python module
        $self->db_cmd('CREATE TABLE result (job_id int(10), output TEXT, PRIMARY KEY (job_id))'),
        $self->db_cmd('ALTER TABLE job DROP KEY input_id_stacks_analysis'),
        $self->db_cmd('ALTER TABLE job MODIFY input_id TEXT')
    ];
}

=head2 pipeline_analyses
=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {
            -logic_name      => 'load_manifest_data',
            -module          => 'ensembl.production.hive.DataFileCrawler',
            -language        => 'python3',
            -rc_name         => 'default',
            -input_ids       => [],
            -max_retry_count => 0,
            -meadow_type     => 'LOCAL',
            -flow_into       => {
                1 => [ 'get_metadata_from_files' ],
            },
        },
        {
            -logic_name      => 'get_metadata_from_files',
            -module          => 'ensembl.production.hive.DataFileParser',
            -language        => 'python3',
            -rc_name         => 'default',
            -input_ids       => [],
            -max_retry_count => 3,
            -parameters      => {
                'ftp_dir_ens' => $self->o('ftp_dir_ens'),
                'ftp_dir_eg'  => $self->o('ftp_dir_eg'),
                'ftp_url_ens' => $self->o('ftp_url_ens'),
                'ftp_url_eg'  => $self->o('ftp_url_eg'),
            },
            -meadow_type     => 'LOCAL',
            -flow_into       => {
                # Dataflow method DataFileCrawler Python module will output into this table result.
                2 => [ '?table_name=result', ],
            },
        }
    ];
}

1;