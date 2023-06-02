=pod
=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 LICENSE
    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2023] EMBL-European Bioinformatics Institute
    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
         http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.
=head1 CONTACT
    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates
=cut


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DataFileScanner_conf;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::BasePython_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'pipeline_name' => 'datafile_scanner',
        'root_dir'      => '/nfs/ftp/ensemblftp/ensembl/PUBLIC/pub',
        'release'       => 0,
        'overwrite'     => 1
    }
}

=head2 pipeline_analyses
=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {
            -logic_name => 'create_manifest_data',
            -module     => 'ensembl.production.hive.DataFileScanner',
            -language   => 'python3',
            -rc_name    => 'default',
            -input_ids  => [{}],
            -parameters => {
                'root_dir'  => $self->o('root_dir'),
                'release'   => $self->o('release'),
                'overwrite' => $self->o('overwrite')
            }
        },
    ];
}

1;
