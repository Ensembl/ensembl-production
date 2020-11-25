package Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::variants::VariationBedWriter;

################################################################
#
# Opens a bed file named by concatenating the name of the genome
# with the name of the chromosome. Writes data to this bed files,
# line by line. When the chromosome changes, closes the current file
# and opens a new file for writing. Hopefully, this should be faster
# than opening and closing a file to write every single line.
#
# Intended to cover cases when a single VCF file contains data
# about multiple chromosomes (we want the output to be
# a bed file per chromosome).
#
################################################################

use Moose;
use Path::Tiny qw(path);
has 'file_handle' => ( isa => 'FileHandle', is => 'rw', clearer => 'clear_file_handle');
has 'current_chromosome' => ( isa => 'Str', is => 'rw', clearer => 'clear_current_chromosome' );
has 'genome' => (isa => 'Genome', is => 'rw');
has 'root_path'   => ( isa => 'Path::Tiny', is => 'ro', required => 1 );

sub write_line {
  $\ = "\n"; # use line break for output separator
  my ($self, $genome_id, $chromosome, $line) = @_;

  if (!$self->current_chromosome || $self->current_chromosome ne $chromosome) {
    $self->close_file();
    $self->open_file($genome_id, $chromosome);
    $self->current_chromosome($chromosome);
  }

  print { $self->file_handle } $line;
}

# FIXME use VariantFileName?
sub build_file_name {
  my ($self, $genome_id, $chromosome) = @_;
  return $chromosome ? "$genome_id\$$chromosome.bed" : "$genome_id.bed";
}

sub open_file {
  my ($self, $genome_id, $chromosome) = @_;
  my $file_name = $self->build_file_name($genome_id, $chromosome);
  my $path_to_file = $self->get_output_path($genome_id)->child($file_name)->stringify();
  open(my $file_handle, '>>', $path_to_file) or die "Cannot open variation file $path_to_file";
  $self->file_handle($file_handle);
}

sub get_output_path {
  my ($self, $genome_id) = @_;
  return $self->variants_path($genome_id);
}

sub close_file {
  my ($self) = @_;
  if ($self->file_handle) {
    close ($self->file_handle);
    $self->clear_file_handle;
    $self->clear_current_chromosome;
  }
}

sub variants_path {
  my ($self, $genome_id) = @_;
  return $self->ensure_path($self->root_path->child('variants')->child($genome_id));
}

sub ensure_path {
  my ($self, $path) = @_;
  if(! $path->is_dir()) {
    $path->mkpath();
  }
  return $path;
}
   

1;
