=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::Common::Gzip;

=head1 DESCRIPTION

A simple script for gzipping files and catching errors

=head1 AUTHOR

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::Common::Gzip;;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use IO::Compress::Gzip qw(gzip $GzipError) ;

sub fetch_input {
    my ($self) = @_;
return;
}

sub run {
    my ($self) = @_;
    my @compress = $self->param_required('compress');

    foreach my $file (@compress) {
        my $output_file = $file.'.gz';
        eval {
            local $SIG{PIPE} = sub { die "gzip interrupted by SIGPIPE\n" };
            gzip $file => $output_file
                or die "gzip failed: $GzipError\n";
            unlink $file;
        };
        if ($@) {
            print "Error compressing '$file': $@\n";
        } else {
            print "Compressed '$file' to '$output_file' and removed the original file\n";
        }
    }
return;
}

1;
