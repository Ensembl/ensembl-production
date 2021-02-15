=head1 DESCRIPTION  

=head1 LICENSE
    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2020] EMBL-European Bioinformatics Institute
    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
         http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.
=head1 CONTACT
    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates
=cut


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::MirrorLoad_conf;

use strict;
use warnings;
use Data::Dumper;
use strict;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;


sub resource_classes {
    my ($self) = @_;
    return { 'default' => { 'LSF' => '-q production-rh74' } };
}

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        'pipeline_name'    => "mirror_load_database",
        'copy_service_uri' => "http://production-services.ensembl.org/api/dbcopy/requestjob",
        'division'        => [],
        'run_all'         => 0, 
        'process_mart'    => 0,
        'process_grch37'  => 0,     
        'email_subject' => $self->o('pipeline_name').'  pipeline has finished',
        'ENS_DELETE_VERSION' => ( software_version() - 3 ),
    }
}

#$self->db_cmd('')

=head2 pipeline_analyses
=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [

       {
            -logic_name => 'ListDatabasesToDelete',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::MirrorLoad::ListDatabase',
            -input_ids  => [ {} ], # required for automatic seeding
            -parameters => {
                division             => $self->o('division'),
                run_all              => $self->o('run_all'),
                release              => $self->o('ENS_DELETE_VERSION'),
	        process_mart         => $self->o('process_mart'),
                process_grch37       => $self->o('process_grch37'),
                tocopy               => 0,  
             },
            -flow_into  => { '2->A' => [ 'DeleteDBs' ],
		             'A->1' => [ 'ListDatabasesToCopy' ]		
                           },

        },
        {
            -logic_name => 'DeleteDBs',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::MirrorLoad::DeleteDBs',
            -parameters => {
             },

        }, 
        {
            -logic_name => 'ListDatabasesToCopy',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::MirrorLoad::ListDatabase',
            -parameters => {
                division             => $self->o('division'),
                run_all              => $self->o('run_all'),
                release              => software_version(),
                process_mart         => $self->o('process_mart'),
                process_grch37       => $self->o('process_grch37'),
                tocopy               => 1, 
             },

            -flow_into  => { '2->A' => [ 'CopyToMirror' ],
			     'A->1' => [ 'email_notification' ]	
		           }
        },
        {
            -logic_name      => 'CopyToMirror',
            -module          => 'ensembl.production.hive.ProductionDBCopy',
            -language        => 'python3',
            -rc_name         => 'default',
            -max_retry_count => 0,
            -parameters      => {
                'endpoint'      => $self->o('copy_service_uri'),
                'method'        => 'post',
            },
            -meadow_type     => 'LOCAL',
	},

        {
           -logic_name => 'email_notification',
           -module     => 'Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
           -parameters => {
                           'email'   => $self->o('email'),
                           'subject' => 'Mirror Load ',
                           'text'    => 'All db loaded to mirror ',
                          },
        },
		
		
    ];
}
1;

