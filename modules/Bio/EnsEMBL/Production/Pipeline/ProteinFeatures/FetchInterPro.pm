=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
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


=pod

=head1 NAME

Bio::EnsEMBL::EGPipeline::ProteinFeatures::FetchInterPro

=head1 DESCRIPTION

Download InterPro descriptions file from ftp site.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::FetchInterPro;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FetchExternal');

use File::Spec::Functions qw(catdir);
use Path::Tiny;

sub param_defaults {
  return {
    'ebi_path'       => '/ebi/ftp/pub/databases/interpro/current',
    'ftp_uri'        => 'ftp://ftp.ebi.ac.uk/pub/databases/interpro/current',
    'file'           => 'names.dat',
    'external_db_id' => 1200,
  };
}

sub run {
  my ($self) = @_;
  my $ebi_path    = $self->param_required('ebi_path');
  my $ftp_uri     = $self->param_required('ftp_uri');
  my $file        = $self->param_required('file');
  my $edb_id      = $self->param_required('external_db_id');
  my $output_file = $self->param_required('output_file');
  
  my $ebi_file = catdir($ebi_path, $file);
  
  if (-e $ebi_file) {
    $self->fetch_ebi_file($ebi_file, $output_file);
  } else {
    my $ftp = $self->get_ftp($ftp_uri);
    $self->fetch_ftp_file($ftp, $file, $output_file);
  }
  
  # Insert constant values for xref columns, to make loading easier.
  my $output = path($output_file);
  my $descriptions = $output->slurp;
  $descriptions =~ s/^(\S+)\t+(.*)/$edb_id\t$1\t$1\t0\t$2\tDIRECT\t/gm;
  $output->spew($descriptions);
}

sub write_output {
  my ($self) = @_;
}

1;
