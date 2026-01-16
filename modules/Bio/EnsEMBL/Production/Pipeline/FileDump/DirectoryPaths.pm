=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2025] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Production::Pipeline::FileDump::DirectoryPaths;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::FileDump::Base');
use Bio::EnsEMBL::DBSQL::DBAdaptor;

use File::Spec::Functions qw/catdir/;
use Path::Tiny;
use Data::Dumper;
sub run {
  my ($self) = @_;
  my $analysis_types = $self->param_required('analysis_types');
  my $data_category  = $self->param_required('data_category');

  if (scalar(@$analysis_types) == 0) {
    $self->complete_early("No $data_category analyses specified");
  }

  my $dba = $self->dba;
  $self->param('species_name', $self->species_name($dba));
  $self->param('annotation_source', $self->annotation_source($dba));
  $self->param('assembly', $self->assembly($dba));
  if ($data_category =~ /geneset|variation|homology/) {
    $self->param('geneset', $self->geneset($dba));
  }

  my ($output_dir, $web_dir, $ftp_dir) =
    $self->directories($data_category);

  $self->param('output_dir', $output_dir);
  $self->param('web_dir', $web_dir);
  $self->param('ftp_dir', $ftp_dir);

}

sub write_output {
  my ($self) = @_;

  my $data_category = $self->param_required('data_category');

  my %output = (
    data_category   => $data_category,
    species_name    => $self->param('species_name'),
    assembly        => $self->param('assembly'),
    output_dir      => $self->param('output_dir'),
    web_dir         => $self->param('web_dir'),
    ftp_dir         => $self->param('ftp_dir'),
    annotation_source => $self->param_required('annotation_source')
  );
  if ($data_category =~ /geneset|variation|homology/) {
    $output{'geneset'} = $self->param('geneset');
  }

  $self->dataflow_output_id(\%output, 3);
}

sub directories {
  my ($self, $data_category) = @_;
  sub split_assembly {

	my $assembly = shift();
	my $subdir_len = 3;

	my @substrs = split(/\_/,$assembly);
	my @version = split(/\./,$substrs[1]);
	my @sub_dirs = ();

	for (my $begin = 0; $begin <= length($substrs[1]) - $subdir_len; $begin += $subdir_len ) {
	my $sub_dir_str = substr($substrs[1], $begin, $subdir_len);
	push (@sub_dirs, $sub_dir_str);
 	}

 	return $substrs[0], @sub_dirs, $version[1] ;
  }
  my $dump_dir              = $self->param_required('dump_dir');
  my $species_dirname       = $self->param_required('species_dirname');
  my $web_dirname           = $self->param_required('web_dirname');
  my $species_name          = $self->param('species_name');
  my $assembly              = $self->param('assembly');
  my @assembly_dir          = split_assembly($assembly);
  my $homology_date_label   = $self->date_for_homology($assembly);
  my $subdirs;
  my @data_categories = ("genome", "geneset", "rnaseq", "variation", "homology", "stats");
  if ( grep( /^$data_category$/, @data_categories ) ) {
    foreach my $asm_dir (@assembly_dir){
     $subdirs = catdir( $subdirs, $asm_dir);
    }
    $subdirs = catdir(
      $subdirs,
      $self->param_required('annotation_source'),
      $self->param_required("${data_category}_dirname"),
    );
  }
  #Genome should just have assembly files.
   if ( $data_category =~ /genome/ ) {
      $subdirs = catdir(\
      $species_dirname,
      $species_name,
      $assembly,
      $self->param_required("${data_category}_dirname"),
     );
  }
  if ( $data_category =~ /geneset|variation|homology/ ) {
    # Variation, geneset, homology add an extra `YYYY_MM` subdir.
    $subdirs = catdir ($subdirs, $self->param('geneset'));
     if ( $data_category =~ /homology/ ) {
  	$subdirs = catdir ($subdirs, $homology_date_label);
     }
  }
  my $output_dir = catdir(
    $dump_dir,
    $subdirs
  );

  my $web_dir = catdir(
    $dump_dir,
    $web_dirname
  );

  my $ftp_dir;
  if ($self->param_is_defined('ftp_root')) {
    $ftp_dir = catdir(
      $self->param('ftp_root'),
      $subdirs
    );
  }

  return ($output_dir, $web_dir, $ftp_dir);
}

sub date_for_homology {

  my $assembly = shift();
  my $dbname = 'ensembl_genome_metadata';
  my $dbuser = 'ensro';
  my $dbpass = '';
  my $dbhost = 'mysql-ens-production-1';
  my $dbport = '4721';

  my $prodb = new Bio::EnsEMBL::DBSQL::DBAdaptor(
    -host => $dbhost,
    -port => $dbport,
    -user => $dbuser,
    -dbname => $dbname,
    -pass => $dbpass,
  );

  my $label_query = $prodb->dbc->prepare("SELECT ensembl_release.label \
      FROM genome  \
      JOIN genome_release ON genome.genome_id = genome_release.genome_id \
      JOIN assembly ON genome.assembly_id = assembly.assembly_id \
      JOIN ensembl_release ON genome_release.release_id = ensembl_release.release_id \
      WHERE assembly.accession='$assembly' \
      AND ensembl_release.status='Released' \
      AND ensembl_release.release_type='Partial' ");

  $label_query->execute();
  while (my $label_row= $label_query->fetchrow_arrayref()){
    my ($label) = @$label_row;
    $label =~ s/\-/_/g;
    print "$label\n";
    return $label;
  }

}

1;
