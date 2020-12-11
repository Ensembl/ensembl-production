package Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeReport;

use Moose;

use HTTP::Tiny;
use IO::String;
use Digest::MD5;
use Digest::SHA;

sub build_from_report {
  my ($class, $genome) = @_;
  my $report_path = $genome->genome_report_path;
  my @reports;
  foreach my $line ($report_path->lines({chomp => 1})) {
    next if $line =~ /^#/;
    push(@reports, $class->build_from_report_line($genome,$line));
  }
  return \@reports;
}

sub build_from_report_line {
  my ($class, $genome, $line) = @_;
  my ($name, $role, $assigned_mol, $location, $accession, $relationship, $refseq_accession, $assembly_unit, $length, $ucsc_style_name) = split(/\t/, $line);
  return $class->new(
    genome            => $genome,
    name              => $name,
    role              => $role,
    assigned_mol      => $assigned_mol,
    location          => $location,
    accession         => $accession,
    relationship      => $relationship,
    refseq_accession  => $refseq_accession,
    assembly_unit     => $assembly_unit,
    length            => $length,
    ucsc_style_name   => $ucsc_style_name,
  );
}

my $URL_FORMAT = 'https://www.ebi.ac.uk/ena/browser/api/fasta/%s';

has 'genome'            => ( isa => 'Any', is => 'ro', required => 1 ); 
has 'name'              => ( isa => 'Str', is => 'ro', required => 1 );
has 'role'              => ( isa => 'Str', is => 'ro', required => 1 );
has 'assigned_mol'      => ( isa => 'Str', is => 'ro', required => 1 );
has 'location'          => ( isa => 'Str', is => 'ro', required => 1 );
has 'accession'         => ( isa => 'Str', is => 'ro', required => 1 );
has 'relationship'      => ( isa => 'Str', is => 'ro', required => 1 );
has 'refseq_accession'  => ( isa => 'Str', is => 'ro', required => 1 );
has 'assembly_unit'     => ( isa => 'Str', is => 'ro', required => 1 );
has 'length'            => ( isa => 'Int', is => 'ro', required => 1 );
has 'ucsc_style_name'   => ( isa => 'Str', is => 'ro', required => 1 );

has 'url_format'  => ( isa => 'Str', is => 'ro', default => $URL_FORMAT );
has 'md5'         => ( isa => 'Digest::MD5', is => 'ro', default => sub { Digest::MD5->new()} );
has 'sha512'      => ( isa => 'Digest::SHA', is => 'ro', default => sub { Digest::SHA->new(512)} );
has 'seq'         => ( isa => 'ScalarRef', is => 'rw', lazy => 1, builder => 'build_seq' );

sub is_assembled {
  my ($self) = @_;
  return ($self->role() eq 'assembled-molecule') ? 1 : 0;
}

sub missing_accession {
  my ($self) = @_;
  return ($self->accession() eq 'na') ? 1 : 0;
}

sub build_seq {
  my ($self) = @_;
  my $accession = $self->accession();
  my $url_format = $self->url_format();
  my $url = sprintf($url_format, $accession);
   
  my $resp = HTTP::Tiny->new()->get($url);
  if(!$resp->{success}) {
    confess "Failed to download ${accession}. $resp->{reason}";
  }
  my $fasta_fh = IO::String->new($resp->{content});
  my $seq_ref = $self->process_fasta($fasta_fh);
  return $seq_ref;
}

sub process_fasta {
  my ($self, $fasta_fh) = @_;
  my $seq = q{};
  my $md5 = $self->md5;
  my $sha512 = $self->sha512;
  while(my $fasta_line = <$fasta_fh>) {
    next if $fasta_line =~ />/;
    $fasta_line =~ s/\s+//g;
    $seq .= $fasta_line;
    $md5->add($fasta_line);
    $sha512->add($fasta_line);
  }
  return \$seq;
}

sub write_seq {
  my ($self, $target_path) = @_;
  $self->genome()->get_seq_path($self)->spew(${$self->seq()});
  return;
}

sub md5_hex {
  my ($self) = @_;
  $self->seq;
  return $self->md5->clone->hexdigest();
}

sub trunc512_hex {
  my ($self) = @_;
  $self->seq;
  my $hex = $self->sha512->clone->hexdigest();
  return substr($hex, 0, 48);
}

__PACKAGE__->meta->make_immutable;

1;
