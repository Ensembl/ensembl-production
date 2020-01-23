=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PipeConfig::TSLsAppris_conf

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::TSLsAppris_conf;
use strict;
use warnings;
use File::Spec::Functions qw(catfile catdir);
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;


=head2 default_options

 Description: It returns a hashref containing the default options for HiveGeneric_conf
 Returntype : Hashref
 Exceptions : None


=cut

sub default_options {
    my ($self) = @_;

    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() },
        release => software_version(), # Use it on the commandline: -release XX
        base_dir => '', #path to your perl modules
#################
#        Everything below should not need modification
#################
        pipeline_name => 'tsl_appris_'.$self->o('ensembl_release'),
        muser     => undef,
        mdbname   => undef,
        mhost     => undef,
        mport     => undef,
        division => [],
        production_dir => catdir($self->o('base_dir'), 'ensembl-production'),
        tsl_ftp_base => 'http://hgwdev.gi.ucsc.edu/~markd/gencode/tsl-handoff/',
        appris_ftp_base => 'http://apprisws.bioinfo.cnio.es/forEnsembl',
        load_tsl_script => catfile($self->o('production_dir'), 'scripts', 'import_transcript_support_levels.pl'),
        load_appris_script => catfile($self->o('production_dir'), 'scripts', 'import_appris.pl'),
    };
}


=head2 pipeline_analyses

 Arg [1]    : None
 Description: Returns a hashref containing the analyses to run
 Returntype : Hashref
 Exceptions : None

=cut

sub pipeline_analyses {
  my ($self) = @_;
  return [
    {
      -logic_name => 'process_appris_tsl_files',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::PostGenebuild::ProcessApprisTSLFiles',
      -rc_name => 'default',
      -parameters => {
          'appris_ftp_base' => $self->o('appris_ftp_base'),
          'tsl_ftp_base' => $self->o('tsl_ftp_base'),
          'working_dir' => $self->o('working_dir'),
          'mdbname'     => $self->o('mdbname'),
          'mhost'       => $self->o('mhost'),
          'mport'       => $self->o('mport'),
          'muser'      => $self->o('muser'),
          'division'   => $self->o('division'),
          'release'    => $self->o('release')
      },
      -input_ids         => [ {} ],
      -max_retry_count => 1,
      -flow_into => {
          '1' => ['load_appris'],
          '2' => ['load_tsl']
      },
    },

    {
      -logic_name => 'load_appris',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::PostGenebuild::LoadAppris',
      -rc_name => 'default',
      -max_retry_count => 1
    },

    {
      -logic_name => 'load_tsl',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::PostGenebuild::LoadTsl',
      -rc_name => 'default',
      -max_retry_count => 1
    },
  ];
}


=head2 resource_classes

 Arg [1]    : None
 Description: Resources needed for the pipeline, it uses the default one at 1GB and one requesting 4GB if needed
 Returntype : Hashref
 Exceptions : None

=cut

sub resource_classes {
    my $self = shift;
    return {
        %{ $self->SUPER::resource_classes() },  # inherit other stuff from the base class
      'default' => { LSF => '-q production-rh74 -M1000 -R"select[mem>1000] rusage[mem=1000]"'},
      '4GB' => { LSF => '-q production-rh74 -M4000 -R"select[mem>4000] rusage[mem=4000]"'},
    };
}

1;
