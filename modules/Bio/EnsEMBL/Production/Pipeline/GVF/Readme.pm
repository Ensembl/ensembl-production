=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::GVF::Readme;

=head1 DESCRIPTION


=head1 MAINTAINER 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::GVF::Readme;

use strict;
use Carp;
use Data::Dumper;
use Log::Log4perl qw/:easy/;
use Bio::EnsEMBL::Production::Pipeline::Common::SystemCmdRunner;
use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

sub run {
    my $self = shift;

    my $species          = $self->param('species');
    my $ftp_vcf_file_dir = $self->param('ftp_vcf_file_dir');

    my $logger              = $self->get_logger;
    my $ftp_vcf_species_dir = $ftp_vcf_file_dir . '/' . $species;

    use File::Path qw(make_path);
    if (! -d $ftp_vcf_species_dir) {
	make_path($ftp_vcf_species_dir);
    }
    
    my $readme_file_name = $ftp_vcf_species_dir . '/README';

    $logger->info("Readme file will be written to: $readme_file_name");

    my $vcf_file_default               = "${species}.vcf.gz";
    my $vcf_file_structural_variations = "${species}_structural_variations.vcf.gz";
    my $vcf_file_incl_consequences     = "${species}_incl_consequences.vcf.gz";
    my $vcf_file_failed                = "${species}_failed.vcf.gz";

    #my @referenced_files = ($vcf_file_default, $vcf_file_structural_variations, $vcf_file_incl_consequences);
    my $file_is_missing;

    for my $referenced_file (($vcf_file_default, $vcf_file_structural_variations, $vcf_file_incl_consequences)) {
	if (! $referenced_file) {
	    $logger->error("File $referenced_file is referenced in readme, but doesn't exist!");
	    $file_is_missing = 1;
	}
    }
    confess("File referenced in readme doesn't exist!") if ($file_is_missing);

my $readme_text =<<README;
This directory contains a sorted and gzip-compressed VCF (Variant Call Format)
file containing all germline variations from the current EnsemblGenomes
release for this species, named $vcf_file_default. Variations that have been
failed by the EnsemblGenomes QC checks are not included. However, we provide
GVF dumps for failed variations.

If this species has any structural variation data this is provided in a file
named ${vcf_file_structural_variations}.

A file including the consequences of the variations on the EnsemblGenomes
transcriptome, as called by the variation consequence pipeline, can be found
in a file called ${vcf_file_incl_consequences}.

The data contained in these files is presented in VCF format. For more
details about the format refer to:
http://www.1000genomes.org/wiki/Analysis/Variant%20Call%20Format/vcf-variant-call-format-version-41

For various reasons it may be necessary to store information about a variation that has failed quality checks in the Variation pipeline. Variations can be considered to be "failed_variations" for the following reasons:

- Variation maps to more than 3 different locations
- None of the variant alleles match the reference allele
- Variation has more than 3 different alleles
- Loci with no observed variant alleles in dbSNP
- Variation does not map to the genome
- Variation has no genotypes
- Genotype frequencies do not add up to 1
- Variation has no associated sequence
- Variation submission has been withdrawn by the 1000 genomes project due to high false positive rate
- Additional submitted allele data from dbSNP does not agree with the dbSNP refSNP alleles
- Variation has more than 3 different submitted alleles
- Alleles contain non-nucleotide characters
- Alleles contain ambiguity codes
- Mapped position is not compatible with reported alleles
- Variation can not be re-mapped to the current assembly
- Supporting evidence can not be re-mapped to the current assembly
- Flagged as suspect by dbSNP
- Variation maps to more than one genomic location

Keeping track of failed variations can be used as a way to check why some variations that were present in the dataset mapped to the genome are not to be found anywhere on the genome. These failed variations are stored in the file ${vcf_file_failed}.

Questions about these files can be addressed to the Ensembl helpdesk:
helpdesk\@ensembl.org, or to the developer's mailing list: dev\@ensembl.org.
README
;

    open OUT, ">" . $readme_file_name;
    print OUT $readme_text;
    close OUT;

}

1;
