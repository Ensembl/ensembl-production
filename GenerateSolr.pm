=head1 LICENSE

Copyright [1999-2015] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::GenerateSolr;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

use Path::Tiny qw(path);

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    'pathway_sources' => [],
  };
}

sub run {
  my ($self) = @_;
  my $xml_file        = $self->param_required('xml_file');
  my $tsv_file        = $self->param_required('tsv_file');
  
  (my $solr_file = $tsv_file) =~ s/(tsv)$/solr/;
  $self->param('solr_file', $solr_file);
  
  my $domains = $self->generate_solr($xml_file, $tsv_file, $solr_file);
  
  $self->param('with_domains', scalar(keys %$domains));
}

sub write_output {
  my ($self) = @_;
  
  my $output_ids =
  {
    'solr_file'    => $self->param('solr_file'),
    'with_domains' => $self->param('with_domains'),
  };
  $self->dataflow_output_id($output_ids, 1);
}

sub generate_solr {
  my ($self, $xml_file, $tsv_file, $solr_file) = @_;
  
  my $go_terms = $self->go_terms($xml_file);
  my $pathways = $self->pathways($xml_file);
  my $domains = $self->parse_tsv($tsv_file, $go_terms, $pathways);
  $self->write_solr($solr_file, $domains);
  
  return $domains;
}

sub go_terms {
  my ($self, $xml_file) = @_;
  
  my $go_file = "$xml_file.go";
  my $cmd = "grep '<go-xref ' $xml_file | sort -u > $go_file";
  system($cmd) == 0 || $self->throw("Failed to run '$cmd': $@");
  
  my $file_obj = path($go_file);
  my $data = $file_obj->slurp;
  $file_obj->remove;
  
  my @go_xrefs = split(/\n/, $data);
  
  my %go_terms;
  foreach my $go_xref (@go_xrefs) {
    my ($category, $id, $name) = $go_xref =~ /category="(\w+)".*id="([\w:]+)".*name="([^"]+)"/;
    $category = join " ", map {ucfirst} split "_", lc($category);
    $go_terms{$id} = "$category: $name ($id)";
  }
  
  return \%go_terms;
}

sub pathways {
  my ($self, $xml_file) = @_;
  my $pathway_sources = $self->param_required('pathway_sources');
  my %pathway_sources = map { $_ => 1 } @$pathway_sources;
  
  my $pathway_file = "$xml_file.pathway";
  my $cmd = "grep '<pathway-xref ' $xml_file | sort -u > $pathway_file";
  system($cmd) == 0 || $self->throw("Failed to run '$cmd': $@");
  
  my $file_obj = path($pathway_file);
  my $data = $file_obj->slurp;
  $file_obj->remove;
  
  my @pathway_xrefs = split(/\n/, $data);
  
  my %pathways;
  foreach my $pathway_xref (@pathway_xrefs) {
    my ($db, $id, $name) = $pathway_xref =~ /db="(\w+)".*id="([^"]+)".*name="([^"]+)"/;
    next unless defined $db && exists $pathway_sources{$db};
    $pathways{"$db: $id"} = "$db: $name ($id)";
  }
  
  return \%pathways;
}

sub parse_tsv {
  my ($self, $tsv_file, $go_terms, $pathways) = @_;
  
  my $file_obj = path($tsv_file);
  my $data = $file_obj->slurp;
  
  my @rows = split(/\n/, $data);
  
  my %domains;
  foreach my $row (sort @rows) {
    my @row = split(/\t/, $row);
    next unless scalar(@row) > 0;
    
    my $id = "VBMISC_".$row[0];
    
    $domains{$id}{'annotation_date'} = flip_date($row[10]).'T00:00:00Z';
    $domains{$id}{'domain_ids'}{$row[4]}++;
    
    if (defined $row[11]) {
      $domains{$id}{'interpro_ids'}{$row[11]}++;
    }
    
    if (scalar(@row) > 13) {
      my @go_ids = split(/\|/, $row[13]);
      foreach my $go_id (@go_ids) {
        $domains{$id}{'go_terms'}{$$go_terms{$go_id}}++;
      }
    }
    
    if (scalar(@row) > 14) {
      my @pathway_ids = split(/\|/, $row[14]);
      foreach my $pathway_id (@pathway_ids) {
        if (exists $$pathways{$pathway_id}) {
          $domains{$id}{'pathways'}{$$pathways{$pathway_id}}++;
        }
      }
    }
  }
  
  return \%domains;
}

sub write_solr {
  my ($self, $solr_file, $domains) = @_;
  my $interproscan_version = $self->param_required('interproscan_version');
  
  my $file_obj = path($solr_file);
  
  $file_obj->spew("[\n");
  
  my @annotations;
  foreach my $id (sort keys %$domains) {
    my $annotation_date = $$domains{$id}{'annotation_date'};
    my $domain_ids = join(", ", map { "\"$_\"" } sort keys %{ $$domains{$id}{'domain_ids'} });
    my $interpro_ids = join(", ", map { "\"$_\"" } sort keys %{ $$domains{$id}{'interpro_ids'} });
    my $interpro_urls = join(", ", map { "\"http://www.ebi.ac.uk/interpro/entry/$_\"" } sort keys %{ $$domains{$id}{'interpro_ids'} });
    my $go_terms = join(", ", map { "\"$_\"" } sort keys %{ $$domains{$id}{'go_terms'} });
    my $pathways = join(", ", map { "\"$_\"" } sort keys %{ $$domains{$id}{'pathways'} });
    
    my @annotation;
    push @annotation, ' {';
    push @annotation, "  \"id\": \"$id\",";
    push @annotation, "  \"InterProScan_version_s\": { \"set\" : \"$interproscan_version\" },";
    push @annotation, "  \"annotation_date_dt\" : { \"set\" : \"$annotation_date\" },";
    push @annotation, "  \"analysis_domain_ID_ss\": { \"set\" : [ $domain_ids ] },";
    push @annotation, "  \"InterPro_ID_ss\": { \"set\" : [ $interpro_ids ] },";
    push @annotation, "  \"InterPro_ID_ss_urls\": { \"set\" : [ $interpro_urls ] },";
    push @annotation, "  \"GO_terms_txt\": { \"set\" : [ $go_terms ] },";
    push @annotation, "  \"pathways_txt\": { \"set\" : [ $pathways ] },";
    push @annotation, ' }';
    
    my $annotation = join("\n", @annotation);
    push @annotations, $annotation;
  }
  
  my $annotations = join(",\n", @annotations)."\n";
  $file_obj->append($annotations);
  
  $file_obj->append("]\n");
}

sub flip_date {
  my ($date) = @_;
  my @date = split(/\-/, $date);
  return join('-', reverse @date);
}

1;
