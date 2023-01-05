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


package Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::ChromReport;

use Moose;

sub build_from_report {
  my ($class, $genome, $sort_by_name) = @_;
  my $report_path = $genome->chrom_hashes_path();
  confess "Cannot build the chrom report because the chrom.hashes file at ${report_path} does not exist" unless $report_path->is_file();
  my @reports;
  foreach my $line ($report_path->lines({chomp => 1})) {
    next if $line =~ /^#/;
    push(@reports, $class->build_from_report_line($genome, $line));
  }
  if($sort_by_name) { # do a schwartzian transform on the reports and return
    return [
      map   { $_->[0] }
      sort  { $a->[1] cmp $b->[1] }
      map   { [$_, $_->name()] }
      @reports
    ];
  }
  else {
    return \@reports;
  }
}

sub build_from_report_line {
  my ($class, $genome, $line) = @_;
  my ($name, $md5, $sha512, $accession, $length, $ucsc_style_name) = split(/\t/, $line);
	return $class->new(
    genome            => $genome,
		name              => $name,
    md5_hex           => $md5,
    sha512_hex        => $sha512,
		accession         => $accession,
		length            => $length,
		ucsc_style_name   => $ucsc_style_name,
	);
}

has 'genome'            => ( isa => 'Any', is => 'ro', required => 1 );
has 'name'              => ( isa => 'Str', is => 'ro', required => 1 );
has 'accession'         => ( isa => 'Str', is => 'ro', required => 1 );
has 'length'            => ( isa => 'Int', is => 'ro', required => 1 );
has 'ucsc_style_name'   => ( isa => 'Str', is => 'ro', required => 1 );
has 'md5_hex'           => ( isa => 'Str', is => 'ro', required => 1 );
has 'sha512_hex'        => ( isa => 'Str', is => 'ro', required => 1 );

sub get_seq_ref {
  my ($self) = @_;
  my $seq_path = $self->genome()->get_seq_path($self);
  if(! -f $seq_path->exists()) {
    if($ENV{ENS_USE_REFGET}) {
      return $self->_use_refget();
    }
    else {
      confess "Cannot find expected seq at $seq_path for ".$self->name() if ! $seq_path->exists();
    }
  }
  my $seq = $seq_path->slurp();
  return \$seq;
}

sub _use_refget {
  my ($self) = @_;
  my $url_format = $ENV{ENS_REFGET_BASEURL};
  $url_format //= 'https://www.ebi.ac.uk/ena/cram';
  $url_format .= '/sequence/%s';
  my $url = sprintf($url_format, $self->md5_hex());
  my $resp = HTTP::Tiny->new()->get($url, { headers => { Accept => 'text/plain' } });
  if(!$resp->{success}) {
    confess "Failed to download sequence from ${url}. $resp->{reason}";
  }
  my $seq = $resp->{content};
  return \$seq;

}

__PACKAGE__->meta->make_immutable;

1;
