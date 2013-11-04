=head1 NAME

EGGeneric_conf

=head1 SYNOPSIS

EG specific extensions to the generic hive config.
Serves as a single place to configure EG pipelines.

=head1 DESCRIPTION



=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf;

use strict;
use warnings;

use base qw( Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf );

=head2 default_options

Description: Interface method that should return a hash of
             option_name->default_option_value pairs.
             
=cut

sub default_options {
  my $self = shift;
  return {
    # Inherit options from the base class.
    # Useful ones are:
    #  ensembl_cvs_root_dir (defaults to env. variable ENSEMBL_CVS_ROOT_DIR)
    #  ensembl_release (retrieved from the ApiVersion module)
    #  dbowner (defaults to env. variable USER)
    # The following db-related variables exist in the base class,
    # but will almost certainly need to be overwritten, either by
    # specific *_conf.pm files or on the command line:
    #  host, port, user, password, pipeline_name.
    # These variables are the default parameters used to create the pipeline_db.
    %{ $self->SUPER::default_options },
    
    # Generic EG-related options.
    email => $self->o('ENV', 'USER').'@ebi.ac.uk',
  }
}

=head2 resource_classes

Description: Interface method that should return a hash of
             resource_description_id->resource_description_hash.
             
=cut

sub resource_classes {
  my $self = shift;
  return {
    'default'          => {'LSF' => ''},
    'normal'           => {'LSF' => '-q production-rh6 -M  4000 -R "rusage[mem=4000]"'},
    '2Gb_mem'          => {'LSF' => '-q production-rh6 -M  2000 -R "rusage[mem=2000]"'},
    '4Gb_mem'          => {'LSF' => '-q production-rh6 -M  4000 -R "rusage[mem=4000]"'},
    '8Gb_mem'          => {'LSF' => '-q production-rh6 -M  8000 -R "rusage[mem=8000]"'},
    '12Gb_mem'         => {'LSF' => '-q production-rh6 -M 12000 -R "rusage[mem=12000]"'},
    '16Gb_mem'         => {'LSF' => '-q production-rh6 -M 16000 -R "rusage[mem=16000]"'},
    '24Gb_mem'         => {'LSF' => '-q production-rh6 -M 24000 -R "rusage[mem=24000]"'},
    '32Gb_mem'         => {'LSF' => '-q production-rh6 -M 32000 -R "rusage[mem=32000]"'},
    '2Gb_mem_4Gb_tmp'  => {'LSF' => '-q production-rh6 -M  2000 -R "rusage[mem=2000,tmp=4000]"'},
    '4Gb_mem_4Gb_tmp'  => {'LSF' => '-q production-rh6 -M  4000 -R "rusage[mem=4000,tmp=4000]"'},
    '8Gb_mem_4Gb_tmp'  => {'LSF' => '-q production-rh6 -M  8000 -R "rusage[mem=8000,tmp=4000]"'},
    '12Gb_mem_4Gb_tmp' => {'LSF' => '-q production-rh6 -M 12000 -R "rusage[mem=12000,tmp=4000]"'},
    '16Gb_mem_4Gb_tmp' => {'LSF' => '-q production-rh6 -M 16000 -R "rusage[mem=16000,tmp=4000]"'},
    '24Gb_mem_4Gb_tmp' => {'LSF' => '-q production-rh6 -M 24000 -R "rusage[mem=24000,tmp=4000]"'},
    '32Gb_mem_4Gb_tmp' => {'LSF' => '-q production-rh6 -M 32000 -R "rusage[mem=32000,tmp=4000]"'},
  }
}

1;
