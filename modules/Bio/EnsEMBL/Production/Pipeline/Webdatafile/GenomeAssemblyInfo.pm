=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenomeAssemblyInfo;

=head1 DESCRIPTION
  Compute bootstrap step for webdatafile dumps

=cut

package Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenomeAssemblyInfo;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Path::Tiny qw(path);
use Array::Utils qw(intersect);
use Path::Tiny qw(path);
use JSON qw/decode_json/;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup;

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
    type       => $self->param('division'),  
    root_path  => path($self->param('root_path'))
  };

  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $self->param('species'), $self->param('group') );
  my $lookup = Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup->new("genome_data" => $genome_data); 
  my $genome = $lookup->get_genome('1');

  #bootstrap
  $self->get_assembly_report($genome, $dba);
  $self->report_to_chrom_lookups($genome);
  $self->generate_genome_summary_bed($genome);
}

sub get_assembly_report {

  my ($self, $genome, $dba) = @_;

  my $target_path = $genome->genome_report_path()->stringify;
  open(my $fh, ">", $target_path);


  my $query_result = $dba->dbc->sql_helper()->execute( -SQL => $self->prepare_sql(1) ); 
  $self->write_column_headers($fh);
  $self->write_report($fh, $query_result);
}

sub report_to_chrom_lookups{

   my ($self, $genome) = @_;
   my $genome_report = $genome->get_genome_report();
   my $write_seqs_out =  $self->param('write_seqs_out'); 
   my @chrom_hashes;
   my @chrom_sizes;
   while(my $report = shift @{$genome_report}) {  
     next unless $report->is_assembled();
     if($report->missing_accession()) {
        next;
     }
    my $md5 = $report->md5_hex();
    my $trunc512 = $report->trunc512_hex();
    push(@chrom_hashes, join("\t", $report->name(), $md5, $trunc512, $report->accession(), $report->length(), $report->ucsc_style_name()), "\n");
    push(@chrom_sizes, join("\t", $report->name(), $report->length(), $md5, $trunc512, $report->accession(), $report->ucsc_style_name()), "\n");
    if($write_seqs_out) {
      my $seqs = $genome->seqs_path();
      $report->write_seq($seqs);
    }

   }
  $genome->chrom_hashes_path->spew(@chrom_hashes);
  $genome->chrom_sizes_path->spew(@chrom_sizes);


}

sub generate_genome_summary_bed{
   my ($self, $genome) = @_;
   my @bed;
   my $bin_number = $self->param('ENS_BIN_NUMBER');
   my $chrom_reports = $genome->get_chrom_report('sortbyname');
  foreach my $chrom (@{$chrom_reports}) {
    my $name = $chrom->name();
    my $length = $chrom->length();
    my $bin_size = $length / $bin_number;
    for( my $i = 0; $i < $bin_number; $i++) {
      my $start = int($bin_size * $i);
      my $end = int($bin_size * ($i+1));
      $end = $length if $end > $length;
      push(@bed, join("\t", ($name, $start, $end))."\n");
    }
  }
  my $path = $genome->genome_summary_bed_path();
  $path->spew(@bed);

}

sub prepare_sql {

  my ($self, $genome_id) = @_;
      # Query suggested by Andy that reproduces assembly reports that we used to get from NCBI
      #   # (example of NCBI assembly report: ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.27_GRCh38.p12/GCA_000001405.27_GRCh38.p12_assembly_report.txt)
  
    return "
    select sr.name, CASE WHEN IFNULL(sra3.value, 0) = 0 AND cs.name = 'chromosome' THEN 'assembled-molecule' ELSE 'unlocalized-scaffold' END, sr.name, cs.name, srs1.synonym, '=', srs2.synonym, 'Primary Assembly', sr.length, srs3.synonym
    from coord_system cs
    join seq_region sr on (cs.coord_system_id = sr.coord_system_id)
    join seq_region_attrib sra1 on (sr.seq_region_id = sra1.seq_region_id)
    join attrib_type at1 on (sra1.attrib_type_id = at1.attrib_type_id)
    left join seq_region_attrib sra2 on (sr.seq_region_id = sra2.seq_region_id and sra2.attrib_type_id = (select attrib_type_id from attrib_type where code = 'karyotype_rank'))
    left join seq_region_synonym srs1 on (sr.seq_region_id = srs1.seq_region_id and srs1.external_db_id = (select external_db_id from external_db where db_name = 'INSDC'))
    left join seq_region_synonym srs2 on (sr.seq_region_id = srs2.seq_region_id and srs2.external_db_id = (select external_db_id from external_db where db_name = 'RefSeq_genomic'))
    left join seq_region_synonym srs3 on (sr.seq_region_id = srs3.seq_region_id and srs3.external_db_id = (select external_db_id from external_db where db_name = 'UCSC'))
    left join seq_region_attrib sra3 on (sr.seq_region_id = sra3.seq_region_id and sra3.attrib_type_id = (select attrib_type_id from attrib_type where code = 'non_ref'))
    where at1.code = 'toplevel'
    and cs.species_id = $genome_id
    order by IFNULL(CONVERT(sra2.value, UNSIGNED), 5e6) asc, sr.name;
  ";


}


sub write_column_headers {
  my ($self, $file_handler) = @_;
  my $column_names = "# Sequence-Name   Sequence-Role   Assigned-Molecule       Assigned-Molecule-Location/Type GenBank-Accn    Relationship    RefSeq-Accn     Assembly-Unit   Sequence-Length UCSC-style-name\n";
  print $file_handler $column_names;
}

sub write_report {
  my ($self, $file_handler, $data) = @_;

  foreach my $row (@$data) {
    my @row_of_strings = map { defined $_ ? $_ : '-' } @{$row};
    print $file_handler join("\t", @row_of_strings) . "\n";
  }
}




sub write_output {
  my ($self) = @_;
  my $species        = $self->param('species');
  my $group          = $self->param('group');
  my $current_step   = $self->param('current_step');
  
  if ($current_step eq 'bootstrap') {
        my @steps     = @{$self->param('step')};
        my %each_flow = (
             'transcripts' => 2,
             'contigs'     => 3,
             'gc'          => 4,
             'variants'    => 5,
        );
  
        my @existing_steps = keys %each_flow;
        my @all_steps = scalar intersect(@steps, @existing_steps) ? intersect(@steps, @existing_steps) : @existing_steps;
        for my $each_step (@all_steps){
            $self->dataflow_output_id(
              {
                 species => $species,
                 group   => $group,
                 current_step => $each_step,
                 dbname     => $self->param('dbname'),
                 gca        => $self->param('gca'),
                 assembly_default => $self->param('assembly_default'),
                 assembly_ucsc => $self->param('assembly_ucsc'),
                 level      => $self->param('level'),
                 genome_id  => $self->param('genome_id'),
                 version    => $self->param('version'),
                 type       => $self->param('division'),
                 root_path  => $self->param('root_path'),
    
              }, $each_flow{$each_step}
            );
        }  
  }
}



1;
