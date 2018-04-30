=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::Xref_update_metazoa_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Xref_update_conf');
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use Bio::EnsEMBL::ApiVersion qw/software_version/;


sub default_options {
    my ($self) = @_;

    return {
           %{ $self->SUPER::default_options() },
           'email'            => $self->o('ENV', 'USER').'@ebi.ac.uk',
           'release'          => software_version(),
           'sql_dir'          => $self->o('ENV', 'HOME')."/work/lib/ensembl/misc-scripts/xref_mapping",
           'pipeline_name'    => 'metazoa_xref_update_'.$self->o('release'),

           ## 'job_factory' parameters
           'species'          => ['caenorhabditis_elegans'],
           'antispecies'      => [],
           'division'         => [],
           'run_all'          => 0,
           'force'            => ['caenorhabditis_elegans'],
           'check_intentions' => 0,

           ## Parameters for source download
           'config_file'      => $self->o('ENV', 'HOME')."/work/lib/ensembl-production/modules/Bio/EnsEMBL/Production/Pipeline/Xrefs/xref_sources_metazoa.json",
           'source_dir'       => $self->o('ENV', 'HOME')."/work/lib/VersioningService/sql",
           'source_url'       => 'mysql://ensadmin:ensembl@mysql-ens-core-prod-1:4524/mr6_metazoa_source_db',
           'xref_db'          => 'mysql://ensadmin:ensembl@mysql-ens-core-prod-1:4524',
           'reuse_db'         => 0,
           'skip_download'    => 0,

           ## Parameters for xref database
        };
}

1;

