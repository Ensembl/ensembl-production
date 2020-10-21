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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFileVariation;

=head1 DESCRIPTION
  Process vcf file for webdatafile dumps

=cut

package Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFileVariation;

use strict;
use warnings;

use VCF;
use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Path::Tiny qw(path);
use Carp qw/croak/;
use JSON qw/decode_json/;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::IndexBed;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::variants::VariantsScaler;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::variants::VariationBedWriter;
use CoordinateConverter qw(to_zero_based);


sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults},
  };
}


sub run {

  my ($self) = @_;
  my $species = $self->param('species');
  my $current_step = $self->param('current_step') ;
  my $output = $self->param('output_path');
  my $app_path = $self->param('app_path'); 
  my $genome_data = {
    dbname     => $self->param('dbname'),
    gca        => $self->param('gca'),
    genome_id  => $self->param('genome_id'),
    species    => $self->param('species'),
    version    => $self->param('version'),
    type       => $self->param('type'),  
    root_path  => path($self->param('root_path'))
  };
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $self->param('species'), $self->param('group') );
  my $lookup = Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup->new("genome_data" => $genome_data); 
  my $genome = $lookup->get_genome('1');
  my $variation_bed_writer = Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::variants::VariationBedWriter->new(root_path => path($self->param('root_path')));
  ##my $release = get_release_versions();

  $self->clear_output_folder($variation_bed_writer, $genome);
  my $vcf_files = $self->get_vcf_files($genome);

  foreach my $vcf_file_path (@{$vcf_files}) {
    $self->warning($vcf_file_path);
    $self->write_bed_from_vcf($vcf_file_path, $variation_bed_writer, $genome);
  }
  
  $self->scale_bed_files($variation_bed_writer, $genome);
  $self->generate_bigbeds($variation_bed_writer, $genome)
}


sub scale_bed_files {
  my ($self, $variation_bed_writer, $genome) = @_;
  foreach my $bed_file_path ($variation_bed_writer->variants_path($genome->genome_id())->children) {
    Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::variants::VariantsScaler->new(
                                     input_bed_file => $bed_file_path, 
                                     genome_id => $genome->genome_id(), genome => $genome, 
                                     variant_path => $variation_bed_writer->variants_path($genome->genome_id()) )->scale_variants_bed();
    $bed_file_path->remove;
  }
}


sub clear_output_folder {
  my ($self, $variation_bed_writer, $genome ) = @_;
  foreach my $file_path ($variation_bed_writer->variants_path($genome->genome_id())->children) {
    $file_path->remove;
  };
}


sub generate_bigbeds {
  my ($self, $variation_bed_writer, $genome) = @_;
  foreach my $bed_file_path ($variation_bed_writer->variants_path($genome->genome_id())->children) {
    print "Generating big bed from " . $bed_file_path->basename;
    my $indexer = Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::IndexBed->variants($genome);
    $indexer->index($bed_file_path);
    $bed_file_path->remove;
  }
}





sub get_vcf_files {

  my ($self, $genome) = @_;
  my $genome_type = $genome->type(); 
  my $species = $genome->species();
  my $ensembl_release = $self->param('ENS_VERSION');
  my $ensembl_genomes_release = $self->param('EG_VERSION');
  my $base_ftp_dir = '/nfs/production/panda/ensembl/production/ensemblftp/';
  if( $genome->type eq	'EnsemblVertebrates' ||  $genome->assembly_default eq 'GRCH37'){
       $base_ftp_dir = $base_ftp_dir . "release-$ensembl_release/variation/vcf/$species";
  }else{
       $base_ftp_dir = $base_ftp_dir . "release-$ensembl_genomes_release/$genome_type/variation/vcf/$species";    
  }

  my $vcf_file_name_pattern_string = "${species}_incl_consequences.*.vcf.gz";
  my @vcf_file_matches = path($base_ftp_dir)->children(qr/${species}_incl_consequences.*.vcf.gz$/);
  return \@vcf_file_matches;
}

sub write_bed_from_vcf {
  my ($self, $vcf_file_path, $variation_bed_writer, $genome) = @_;
  $self->warning('vcf file name:'); 
  $self->warning($vcf_file_path);
  my $vcf = VCF->new(file=>$vcf_file_path);
  $vcf->parse_header();

  while (my $record = $vcf->next_data_hash()) {
    my $alts = $record->{'ALT'}; # this is an array of alternative nucleotide sequences
    my $ref = $record->{'REF'};
    my $chrom = $record->{'CHROM'};
    my $pos = $record->{'POS'};
    my $ve = $record->{'INFO'}->{'VE'};
    my ($conseq) = split(/\|/, $ve);

    my $line;

    my ($longest_alt) = sort { length($b) <=> length($a) } @$alts;
    my $start_pos = to_zero_based($pos);

    if (length($longest_alt) > length($ref)) {
      $line = join("\t", $chrom, $start_pos, $start_pos, $conseq);
      $variation_bed_writer->write_line($genome->genome_id(), $chrom, $line);
    }

    $line = join "\t", (
      $chrom,
      $start_pos,
      $start_pos + length($ref),
      $conseq
    );

    $variation_bed_writer->write_line($genome->genome_id(), $chrom, $line);
  }

  $variation_bed_writer->close_file();
}





1;
