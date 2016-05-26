=head1 LICENSE

Copyright [2009-2015] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::TSV::Base;

=head1 DESCRIPTION


=head1 MAINTAINER

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::TSV::Base;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

sub _generate_file_name {
    my ($self) = @_;
    # File name format looks like:
    # <species>.<assembly>.<release>.<dbname>.tsv.gz
    # e.g. Arabidopsis_thaliana.TAIR10.31.uniprot.tsv.gz
    my @name_bits;
    push @name_bits, $self->web_name();
    push @name_bits, $self->assembly();
    push @name_bits, $self->param('release');
    push @name_bits, $self->param('type');    
    push @name_bits, 'tsv';

    my $file_name = join( '.', @name_bits );
    my $data_path = $self->get_data_path('tsv');
 
return File::Spec->catfile($data_path, $file_name);
}


1;
