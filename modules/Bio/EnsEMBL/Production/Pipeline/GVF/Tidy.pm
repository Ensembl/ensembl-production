=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::GVF::Tidy;

=head1 DESCRIPTION


=head1 MAINTAINER 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::GVF::Tidy; 

use strict;
use Carp;
use Data::Dumper;
use Bio::EnsEMBL::Production::Pipeline::Common::SystemCmdRunner;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub run {
    my $self = shift;

    my $tidy_gvf_dump_script = $self->param('tidy_gvf_dump_script');
    my $gvf_species_dir      = $self->param('gvf_species_dir'),

    my $runner = Bio::EnsEMBL::Production::Pipeline::Common::SystemCmdRunner->new();

    my $expected_readme_file = "$gvf_species_dir/README";

    $runner->run_cmd(
        "perl $tidy_gvf_dump_script --output_dir $gvf_species_dir/..",
        [{
            test     => sub { return -f $expected_readme_file },
            fail_msg => "The readme file $expected_readme_file wasn't created!"
        },]
    );

    $runner->run_cmd(
        "perl -p -i -e 's/helpdesk\@ensembl.org/helpdesk\@ensemblgenomes.org/g;' -e 's/Ensembl/EnsemblGenomes/g;' $expected_readme_file",
        [{
            test     => sub { return -f $expected_readme_file },
            fail_msg => "The readme file $expected_readme_file wasn't created!"
        },]
    );
    
}

1;
