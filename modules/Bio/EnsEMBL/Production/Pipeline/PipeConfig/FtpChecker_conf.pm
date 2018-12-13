
=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License"); you
may not use this file except in compliance with the License.  You may
obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied.  See the License for the specific language governing
permissions and limitations under the License.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::FtpChecker_conf;

use strict;
use warnings;
use Data::Dumper;
use base qw/Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf/;

sub resource_classes {
  my ($self) = @_;
  return {
      'default' => { 'LSF' => '-q production-rh7' }
  };
}

=head2 default_options

    Description : Implements default_options() interface method of
    Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to
    initialize default options.

=cut

sub default_options {
  my ($self) = @_;
  return {
    %{ $self->SUPER::default_options()
      },    # inherit other stuff from the base class
    pipeline_name => 'ftp_checker',
    species       => [],
    division      => [],
    run_all       => 0,
    antispecies   => [],
    meta_filters  => {},
    force_update  => 0,
    base_path     => undef,
    failures_file  => './failures.txt',
 };
}

sub pipeline_analyses {
  my ($self) = @_;
  return [ 
	  {
	   -logic_name => 'SpeciesFactory',
	   -module =>
	   'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
           -max_retry_count => 1,
           -input_ids       => [ {} ],
           -parameters      => {
				species         => $self->o('species'),
				antispecies     => $self->o('antispecies'),
				division        => $self->o('division'),
				run_all         => $self->o('run_all'),
				meta_filters    => $self->o('meta_filters'),
				chromosome_flow => 0 },
           -flow_into     => { 
			      '2->A' => ['CheckCoreFtp'],
			      '4->A' => ['CheckVariationFtp'],
			      '5->A' => ['CheckComparaFtp'],
			      'A->1' => ['ReportFailures'],
			     },
           -hive_capacity => 1
	  }, 
	  {
	   -logic_name => 'CheckCoreFtp',
	   -module =>
	   'Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckCoreFtp',
	   -hive_capacity => 100,
	   -flow_into => {
			  2 => [ '?table_name=failures']
			 } 
	  },
	   {
	    -logic_name => 'CheckVariationFtp',
	    -module =>
	    'Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckVariationFtp',
	    -hive_capacity => 100,
	    -flow_into => {
			   2 => [ '?table_name=failures']
			  } 
	   },
	   {
	    -logic_name => 'CheckComparaFtp',
	    -module =>
	    'Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckComparaFtp',
	    -hive_capacity => 100,
	    -flow_into => {
			   2 => [ '?table_name=failures']
			  } 
	   },
	   {
	    -logic_name => 'ReportFailures',
	    -module =>
	    'Bio::EnsEMBL::Production::Pipeline::FtpChecker::ReportFailures',
	    -parameters      => {
				failures_file    => $self->o('failures_file')
				},
	   }


	 ];
} ## end sub pipeline_analyses

sub beekeeper_extra_cmdline_options {
  my $self = shift;
  return "-reg_conf " . $self->o("registry");
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
	  %{ $self->SUPER::pipeline_wide_parameters()
	   },    # inherit other stuff from the base class
	  base_path    => $self->o('base_path')
	 };
}

sub pipeline_create_commands {
  my ($self) = @_;
  return [
	  @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
	  $self->db_cmd('CREATE TABLE failures (species varchar(128), division varchar(16), type varchar(16), format varchar(16), file_path text)')
	 ];
}

1;

