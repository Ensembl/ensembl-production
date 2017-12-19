=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Xrefs::Alignment

=head1 DESCRIPTION

Configures and runs Exonerate according to the chunk parameters given to it

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::Alignment;

use strict;
use warnings;
use Bio::EnsEMBL::Mongoose::Utils::ExonerateAligner;
use Bio::EnsEMBL::Utils::Exception;
use File::Basename;
use File::Spec::Functions;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

sub run {
  my $self = shift;

  my $max_chunks    = $self->param_required('max_chunks');
  my $chunk         = $self->param_required('chunk');
  my $source        = $self->param('source_file');
  my $target        = $self->param('target_file');
  my $seq_type      = $self->param('seq_type');
  my $method        = $self->param_required('align_method');
  my $base_path     = $self->param_required('base_path');
  my $xref_url      = $self->param_required('xref_url');
  my $map_file      = $self->param_required('map_file');

  my ($user, $pass, $host, $port, $dbname);
  my $parsed_url = Bio::EnsEMBL::Hive::Utils::URL::parse($xref_url);
  $user = $parsed_url->{'user'};
  $pass = $parsed_url->{'pass'};
  $host = $parsed_url->{'host'};
  $port = $parsed_url->{'port'};
  $dbname = $parsed_url->{'dbname'};
  my $dbconn = sprintf( "dbi:mysql:host=%s;port=%s;database=%s", $host, $port, $dbname);
  my $dbi = DBI->connect( $dbconn, $user, $pass, { 'RaiseError' => 1 } ) or croak( "Can't connect to database: " . $DBI::errstr );
  my $sth = $dbi->prepare("insert into mapping_jobs (root_dir, map_file, status, out_file, err_file, array_number, job_id) values (?,?,?,?,?,?,?)");

  my $out_file = "xref_".$seq_type.".".$max_chunks."-".$chunk.".out";
  $sth->execute($base_path, $map_file, 'SUBMITTED', $out_file, $out_file, $max_chunks, $chunk);

  my $file_path = catfile($base_path, $map_file);
  my $fh = IO::File->new($file_path,'w') or throw("Couldn't open". $file_path ." for writing: $!\n");

  my $ryo = "xref:%qi:%ti:%ei:%ql:%tl:%qab:%qae:%tab:%tae:%C:%s\n";
  my $exe = `which exonerate`;
  $exe =~ s/\n//g;
  my $command_string = sprintf ("%s --showalignment FALSE --showvulgar FALSE --ryo '%s' --gappedextension FALSE --model 'affine:local' %s --subopt no --query %s --target %s --querychunktotal %s --querychunkid %s", $exe, $ryo, $method, $source, $target, $max_chunks, $chunk);
  my $output = `$command_string`;
  my @hits = grep {$_ =~ /^xref/} split "\n", $output; # not all lines in output are alignments

  while (my $hit = shift @hits) {
    print $fh $hit . "\n";
  }

  $fh->close();
  $sth->finish();
}

1;
