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

=cut

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.


=head1 DESCRIPTION

Produces FASTA dumps of sequence from Xref sources that we have parsed
Normally used for RefSeq (transcript and protein), Uniprot proteins, miRBase transcripts and UniGene genes

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::DumpXref;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;

  my $species     = $self->param_required('species');
  my $release     = $self->param_required('release');
  my $base_path   = $self->param_required('base_path');
  my $xref_url    = $self->param_required('xref_url');
  my $file_path   = $self->param_required('file_path');
  my $seq_type    = $self->param_required('seq_type');
  my $config_file = $self->param_required('config_file');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();
  my ($user, $pass, $host, $port, $dbname) = $self->parse_url($xref_url);
  my $dbi = $self->get_dbi($host, $port, $user, $pass, $dbname);
  my $source_sth = $dbi->prepare("SELECT distinct s.name, s.source_id from source s, primary_xref p, xref x WHERE p.xref_id = x.xref_id AND p.sequence_type = ? AND x.source_id = s.source_id");
  my $sequence_sth = $dbi->prepare("SELECT p.xref_id, p.sequence, x.species_id FROM primary_xref p, xref x WHERE p.xref_id = x.xref_id AND p.sequence_type = ? AND x.source_id = ?");
  my $mapping_source_sth = $dbi->prepare("insert ignore into source_mapping_method values (?,?)");

  # Create sequence files
  my $full_path = $self->get_path($base_path, $species, $release, "xref");

  # Create hash of available alignment methods
  my %method;
  my %query_cutoff;
  my %target_cutoff;
  my $sources = $self->parse_config($config_file);
  my $job_index = 1;
  foreach my $source (@$sources) {
    my $name = $source->{'name'};
    my $method = $source->{'method'};
    my $query_cutoff = $source->{'query_cutoff'};
    my $target_cutoff = $source->{'target_cutoff'};
    $method{$name} = $method;
    $query_cutoff{$name} = $query_cutoff;
    $target_cutoff{$name} = $target_cutoff;
  }

  $source_sth->execute($seq_type);
  while (my @row = $source_sth->fetchrow_array()) {
    my $name = $row[0];
    my $source = $name;
    my $source_id = $row[1];
    if ($name =~ /RefSeq_.*RNA/) { $name = 'RefSeq_dna'; }
    if ($name =~ /RefSeq_peptide/) { $name = 'RefSeq_peptide'; }
    if (defined $method{$name}) {
      my $method = $method{$name};
      my $query_cutoff = $query_cutoff{$name};
      my $target_cutoff = $target_cutoff{$name};
      $source =~ s/\///;
      my $filename = File::Spec->catfile($full_path, $seq_type ."_$source" . "_$source_id.fasta");
      open( my $DH,">", $filename) || die "Could not open $filename";
      $sequence_sth->execute($seq_type, $source_id);
      while(my @row = $sequence_sth->fetchrow_array()){
        # Ambiguous peptides must be cleaned out to protect Exonerate from J,O and U codes
        $row[1] = uc($row[1]);
        $row[1] =~ s/(.{60})/$1\n/g;
        if ($seq_type eq 'pep') { $row[1] =~ tr/JOU/X/ }
        print $DH ">".$row[0]."\n".$row[1]."\n";
      }
      $mapping_source_sth->execute($source_id, $seq_type);
      close $DH;
      my $dataflow_params = {
        species       => $species,
        ensembl_fasta => $file_path,
        seq_type      => $seq_type,
        xref_url      => $xref_url,
        method        => $method,
        query_cutoff  => $query_cutoff,
        target_cutoff => $target_cutoff,
        job_index     => $job_index,
        source_id     => $source_id,
        xref_fasta    => $filename
      };
      $self->dataflow_output_id($dataflow_params, 2);
      $job_index++;
    }
  }

  $source_sth->finish();
  $mapping_source_sth->finish();
  $sequence_sth->finish();
  
  return;
}

1;
