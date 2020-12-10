package Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::IndexWig;

use Moose;

with 'UcscIndex';

has 'clip'              => ( isa => 'Bool', is => 'ro', required => 1, default => 1 );
has 'all_chrs'          => ( isa => 'Bool', is => 'ro', required => 1, default => 1 );
has 'fixed_summaries'   => ( isa => 'Bool', is => 'ro', required => 1, default => 1 );
has 'strip_track_lines' => ( isa => 'Bool', is => 'ro', required => 1, default => 1 );
has 'genome' => ( isa => 'Any', is => 'rw', required => 1 );

sub index_gzip_wig {
  my ($self, $wig_path, $target_path) = @_;
  confess "Cannot find the path ${wig_path}" unless $wig_path->is_file();
  my $remove_temp_files = $self->remove_temp_files();
  my $strip_track_lines = $self->strip_track_lines();
  my $genome = $self->genome();
  my $genome_id = $genome->genome_id();
  if(! defined $target_path) {
    $target_path = $wig_path->sibling($wig_path->basename('.wig.gz'));
  }
  my $target_fh = $target_path->openw();
  my $raw_path = $wig_path->stringify();
  open my $fh, '-|', 'gzip -dc '.$raw_path or confess "Cannot open $raw_path for reading through gzip: $!";
  while(my $line = <$fh>) {
    if($strip_track_lines && $line =~ /^track type=.+/) {
      next;
    }
    print $target_fh $line or confess "Cannot print to file concat filehandle: $!";
  }
  close $fh or confess "Cannot close input wig file: $!";
  close $target_fh or confess "Cannot close target wig file: $!";
  my $bigwig = $self->to_bigwig($target_path);
  $target_path->remove() if $remove_temp_files;
  return $bigwig;
}

sub index {
	my ($self, $wig_path, $indexed_path) = @_;
	confess "Cannot find $wig_path" unless $wig_path->exists();
	confess "$wig_path is not a file" unless $wig_path->is_file();
	return $self->to_bigwig($wig_path, $indexed_path);
}

sub to_bigwig {
	my ($self, $wig_path, $indexed_path) = @_;
  if(! defined $indexed_path) {
	  my $indexed_name = $wig_path->basename('.wig').'.bw';
	  $indexed_path = $wig_path->sibling($indexed_name);
  }
	my $cmd = 'wigToBigWig';
	my @args;
	push(@args, '-clip') if $self->clip();
  push(@args, '-keepAllChromosomes') if $self->all_chrs();
  push(@args, '-fixedSummaries') if $self->fixed_summaries();
	push(@args, $wig_path->stringify(), $self->chrom_sizes(), $indexed_path->stringify());
	$self->system($cmd, @args);
	return $indexed_path;
}

sub bigwig_cat {
  my ($self, $bigwig_paths, $target_path) = @_;
  confess 'No target path given' if ! defined $target_path;
  my $cmd = 'bigWigCat';
  my @args = ($target_path->stringify(), map { $_->stringify() } @{$bigwig_paths});
  $self->system($cmd, @args);
	return $target_path;
}

1;
