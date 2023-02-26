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

Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::SecureHashGenerator

=head1 DESCRIPTION

aGenerates secure hash for genomic sequences


=over 8 

=item 1 - Genomic sequences

=item 2 - Generates SHA512 hash 

=back

The script is responsible for genomic sequences for given sequence type

Allowed parameters are:

=over 8

=item hash_type - hash algorithm type 


=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::SecureHashGenerator;

use strict;
use warnings;
use Digest::SHA qw/sha512/;
use MIME::Base64 qw/encode_base64url/;
use Digest::MD5 qw(md5_hex);
use Encode;

use Bio::EnsEMBL::Attribute;
use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;


sub param_defaults {
  my ($self) = @_;
  return {
  	  
  };
}

sub fetch_input {
  my ($self) = @_;
  my $hash_types = $self->param('hash_types');
  $hash_types = ['sha512', 'md5'] unless $hash_types;
  my %hash_func = (
    'sha512' => \&sha512,
    'md5' => \&md5_hex    
  );
  $self->param('hash_func', \%hash_func);
  $self->param('hash_types', $hash_types);
  return;
}

sub run {

  my ($self) = @_;
  my $hash_types = $self->param('hash_types');
  my $type = $self->param('group');
  my $species = $self->param('species');
  my $seq_type = $self->param('seq_type');
  my ($genome_ad, $genome_feature,  $sequence, $attrib_table, $genome_feature_id) ;
  my $dba  = $self->get_DBAdaptor($type);
  my $hash_func = $self->param('hash_func');
  my $registry = 'Bio::EnsEMBL::Registry';
  if(! $dba) {
    $self->info("Cannot find adaptor for type %s", $type);
    next;
  }
  my $attribute_adaptor = $dba->get_adaptor('Attribute');
  if( $seq_type eq 'toplevel'){
    $genome_ad = $registry->get_adaptor( $species, $type, "Slice" );
    $genome_feature = $genome_ad->fetch_by_seq_region_id($self->param('seq_region_id'));
    $attrib_table = "seq_region";
    $genome_feature_id = $genome_feature->get_seq_region_id();
    $sequence = $genome_feature->seq();
  }
  elsif($seq_type eq 'cdna' || $seq_type eq 'cds'){
    $genome_ad = $registry->get_adaptor($species, $type, "Transcript");
    $genome_feature = $genome_ad->fetch_by_dbID($self->param('transcript_dbid'));
    $sequence = ($seq_type eq 'cdna') ? $genome_feature->spliced_seq() : $genome_feature->translateable_seq();
    $attrib_table = "transcript";
    $genome_feature_id = $genome_feature->dbID();
  }
  elsif($seq_type eq 'pep'){
    $genome_ad = $registry->get_adaptor( $species, $type, "Translation" );
    $genome_feature = $genome_ad->fetch_by_dbID($self->param('translation_dbid'));
    $sequence = $genome_feature->seq();
    $attrib_table = "translation";
    $genome_feature_id = $genome_feature->dbID();
       	  
  }else{
    die "Unknown $seq_type : valid seq_types are toplevel, cdna, cds, pep";	  
  }	  

  $sequence = encode("utf8", $sequence);
  my $digest_size = $self->param('digest_size', 24);

  #generate hash and update the attrb table 
  foreach my $hash_method (@$hash_types){
    my $secure_hash = $self->generate_securehash($sequence, $hash_method, $hash_func, $digest_size);
    my $at_code = $hash_method."_".$seq_type;
    $self->update_attib_table($attribute_adaptor, $at_code, $secure_hash, $genome_feature_id , $attrib_table);
  }  
	    
}



sub generate_securehash {
  my ($self, $sequence, $hash_method, $hash_func,  $digest_size) = @_;
  $digest_size //= 24;
  if(($digest_size % 3) != 0) {
    die "Digest size must be a multiple of 3 to avoid padded digests";
  }
  $sequence  = encode("utf8", $sequence);
  if(exists $hash_func->{$hash_method}){
    my $digest = $hash_func->{$hash_method}->($sequence);
    my $base64 = encode_base64url($digest);
    my $substr_offset = int($digest_size/3)*4;
    return substr($base64, 0, $substr_offset);
  }else{
    die "No hash method $hash_method ";	  
  }	  

}


sub update_attib_table{
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

