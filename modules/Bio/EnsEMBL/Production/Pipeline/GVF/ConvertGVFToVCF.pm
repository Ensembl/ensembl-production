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
.

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::GVF::ConvertGVFToVCF;

=head1 DESCRIPTION


=head1 MAINTAINER 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::GVF::ConvertGVFToVCF;

use strict;
use Carp;
use Data::Dumper;
use Log::Log4perl qw/:easy/;
use Bio::EnsEMBL::Production::Pipeline::Common::SystemCmdRunner;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub run {
    my $self = shift;

    my $gvf_file               = $self->param('gvf_file');
    my $vcf_file               = $self->param('vcf_file');
    my $ensembl_gvf2vcf_script = $self->param('ensembl_gvf2vcf_script');
    my $registry_file          = $self->param('registry');
    my $species                = $self->param('species');

    my $logger = $self->get_logger;

    if (! -e $gvf_file) {
	$logger->warn("Expected file does not exist!");
	$logger->warn($gvf_file);
	return;
    }

    my $expected_vcf_file = $vcf_file . '.gz';

    if (-e $expected_vcf_file) {
	$logger->warn("Vcf file ($expected_vcf_file) has already been created, skipping.");
	return;
    }
    if (-e $vcf_file) {
	$logger->warn("Vcf file ($vcf_file) has been created, probably from a previous failed run. Deleting this and rerunning.");
	unlink($vcf_file);
    }

    my $cmd = qq(
perl $ensembl_gvf2vcf_script \\
    --gvf_file $gvf_file \\
    --registry_file $registry_file \\
    --species $species \\
    --debug \\
    --vcf_file $vcf_file \\
    --compress \\
);

    $logger->info("The command for converting gvf to vcf is:");
    $logger->info($cmd);

    my $runner = Bio::EnsEMBL::Production::Pipeline::Common::SystemCmdRunner->new();

    $runner->run_cmd(
        $cmd,
        [{
            test     => sub { return -f $expected_vcf_file },
            fail_msg => "Couldn't create file ${expected_vcf_file}!"
        },], 1
    );

}

1;
