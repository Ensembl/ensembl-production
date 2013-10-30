=head1 NAME

EGGeneric_conf

=head1 SYNOPSIS

EG specific extensions to the generic hive config. Serves as a single
place to configure everything EG.

=head1 DESCRIPTION



=cut

package eg_pipeline_conf;

use strict;
use warnings;

## We base our hive (config) module off the generic hive config
use base qw( Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf );



=head2 default_options

    Description : Interface method that should return a hash of
                  option_name->default_option_value pairs.  Please see
                  existing defaults in HiveGeneric_conf!

=cut
sub default_options {
    return {
        ## Inherit many useful options from the base class
        %{ $self->SUPER::default_options },

        ## Add more here if needed...
    }
}



=head2 resource_classes

    Description : Interface method that should return a hash of
                  resource_description_id->resource_description_hash.
                  Please see existing PipeConfig modules for examples.

=cut

sub resource_classes {
    my $self = shift;
    return {
        'default'         => {'LSF' => '-q production-rh6     -M  4000
-R "rusage[mem =  4000]" -n 4'},
        'mem'             => {'LSF' => '-q production-rh6     -M 12000
-R "rusage[mem = 12000]" -n 4'},

        '250Mb_job'       => {'LSF' => '-q production-rh6 -C0 -M   250
-R "rusage[mem =   250] select[mem >   250]"'},
        '500Mb_job'       => {'LSF' => '-q production-rh6 -C0 -M   500
-R "rusage[mem =   500] select[mem >   500]"'},
        '1Gb_job'         => {'LSF' => '-q production-rh6 -C0 -M  1000
-R "rusage[mem =  1000] select[mem >  1000]"'},
        '2Gb_job'         => {'LSF' => '-q production-rh6 -C0 -M  2000
-R "rusage[mem =  2000] select[mem >  2000]"'},
        '8Gb_job'         => {'LSF' => '-q production-rh6 -C0 -M  8000
-R "rusage[mem =  8000] select[mem >  8000]"'},
        '24Gb_job'        => {'LSF' => '-q production-rh6 -C0 -M 24000
-R "rusage[mem = 24000] select[mem > 24000]"'},

        'urgent_hcluster' => {'LSF' => '-q production-rh6 -C0 -M  8000
-R "rusage[mem =  8000] select[mem >  8000]"'},

        'msa'             => {'LSF' => '-q production-rh6
                         -W 24:00'},
        'msa_himem'       => {'LSF' => '-q production-rh6     -M 32768
-R "rusage[mem = 32768]" -W 24:00'},
    }
}


1;

