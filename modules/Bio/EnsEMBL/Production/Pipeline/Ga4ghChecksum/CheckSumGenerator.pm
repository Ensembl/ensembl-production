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

=cut

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::CheckSumGenerator

=head1 DESCRIPTION

Generates Checksum for genomic sequences


=over 8 

=item 1 - Genomic sequences

=item 2 - Generates SHA512 hash 

=back

The script is responsible for generating secure hash for genomic sequences 

Allowed parameters are:

=over 8

=item hash_type - hash algorithm type 
=item sequence_type - type of genomic sequences


=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::CheckSumGenerator;

use strict;
use warnings;
use Digest::SHA;
use Digest::MD5;
use MIME::Base64 qw/encode_base64url/;
use Encode;

use Bio::EnsEMBL::Attribute;
use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;


sub param_defaults {
  my ($self) = @_;
  return {
   digest_size => 24,
   chunk_size  => 100000,
  };
}

sub fetch_input {
  my ($self) = @_;
  my $hash_types = $self->param('hash_types');
  $hash_types = ['sha512t24u', 'md5'] if scalar(@$hash_types) == 0 ;
  $self->param('hash_types', $hash_types);
  return;
}

sub run {

  my ($self) = @_;
  my $hash_types = $self->param('hash_types');
  my $type = $self->param('group');
  my $species = $self->param('species');
  my $seq_type = $self->param('seq_type');
  my ($genome_ad, $genome_feature,  $sequence, $attrib_table, $genome_feature_id, $genome_slice) ;
  my $dba  = $self->get_DBAdaptor($type);
  my $registry = 'Bio::EnsEMBL::Registry';
  if(! $dba) {
    $self->info("Cannot find adaptor for type %s", $type);
    next;
  }
  my $attribute_adaptor = $dba->get_adaptor('Attribute');
  if( $seq_type eq 'toplevel'){
    $genome_ad = $registry->get_adaptor( $species, $type, "Slice" );
    $attrib_table = "seq_region";
    $genome_feature_id = $self->param('seq_region_id');
    $genome_slice = $genome_ad->fetch_by_seq_region_id($self->param('seq_region_id'));
  }
  elsif($seq_type eq 'cdna' || $seq_type eq 'cds' || $seq_type eq 'pep'){
    $genome_ad = $registry->get_adaptor($species, $type, "Transcript");
    $genome_feature = $genome_ad->fetch_by_dbID($self->param('transcript_dbid'));
    $genome_slice = $genome_feature->seq; #create a seq object 
    $attrib_table = "transcript";
    $genome_feature_id = $self->param('transcript_dbid');

    if( $seq_type eq 'cds' ){
      $genome_slice->seq($genome_feature->translateable_seq);
    }
    if( $seq_type eq 'pep' ){
      $genome_slice = $genome_feature->translate;
      $attrib_table = "translation";
      $genome_feature_id = $self->param('translation_dbid');
    }	    
  }else{
    die "Unknown $seq_type : valid seq_types are toplevel, cdna, cds, pep";	  
  }

  #generate hash and update the attrb table 
  foreach my $hash_method (@$hash_types){
    my $at_code = $hash_method."_".$seq_type;
    my $sequence_hash = $self->generate_sequence_hash($genome_slice, $hash_method);
    $self->update_attrib_table($attribute_adaptor, $at_code, $sequence_hash, $genome_feature_id , $attrib_table);
  }  
}

sub generate_sequence_hash {
  my ($self, $slice, $hash_method) = @_;
  my $sequence_hash;
  if( $hash_method =~ /sha\-?(\d+)/){
    my $digest_size = $self->param('digest_size') || 24;
    my $algo = int($1);    
    $sequence_hash = $self->sha512t24u($slice, $algo, $digest_size);	  
  }elsif($hash_method eq "md5"){
     $sequence_hash = $self->md5($slice);	  
  }	  
  return $sequence_hash; 
}

sub sha512t24u {
  my ($self, $slice, $algo, $digest_size) = @_;

  if(($digest_size % 3) != 0) {
    die "Digest size must be a multiple of 3 to avoid padded digests";
  }
  my $sha = Digest::SHA->new(int($algo)); #even though we use sha512 algorithm we truncate the generated hash based on given digest size  
  $sha = $self->sequence_stream_digest($slice, $sha, $self->param('chunk_size')); 
  my $digest = $sha->digest;
  my $base64 = encode_base64url($digest);
  my $substr_offset = int($digest_size/3)*4;
  return substr($base64, 0, $substr_offset);
}

sub md5{
  my ($self, $slice) = @_;
  my $md5 = Digest::MD5->new;
  $md5 = $self->sequence_stream_digest($slice, $md5, $self->param('chunk_size'));
  my $digest = $md5->digest;
  my $base64 = encode_base64url($digest);
  return $base64 
}

sub sequence_stream_digest {
  my ($self, $slice, $hash_obj, $chunk_size) = @_;
  $chunk_size = $self->param('$chunk_size') unless $chunk_size;
  my $start = 1;
  my $end = $slice->length();
  my $seek = $start;
  while($seek <= $end) {
    my $seek_upto = $seek + $chunk_size - 1;
    $seek_upto = $end if($seek_upto > $end);
    my $seq = encode("utf8", $slice->subseq($seek, $seek_upto));
    $hash_obj->add($seq);
    $seek = $seek_upto + 1;
  }
  return $hash_obj;
}


sub update_attrib_table{
  my ($self, $attribute_adaptor, $at_code, $secure_hash, $genome_feature_id, $attrib_table  ) = @_;
  my $attrib_obj = $attribute_adaptor->fetch_by_code($at_code);
  my $attrib = Bio::EnsEMBL::Attribute->new(
                         -NAME  => $attrib_obj->[2],
                         -CODE  => $attrib_obj->[1],
                         -VALUE => $secure_hash,
                         -DESCRIPTION => $attrib_obj->[3]
    );
    $attribute_adaptor->store_on_Object($genome_feature_id, [$attrib], $attrib_table);
}

1;

