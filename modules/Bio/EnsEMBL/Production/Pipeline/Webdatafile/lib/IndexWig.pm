=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::IndexWig;

use Moose;


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

sub chrom_sizes {
  my ($self) = @_;
  return $self->genome()->chrom_sizes_path()->stringify();
}



sub system {
        my ($self, $cmd, @args) = @_;
        my ($stdout, $stderr, $exit) = capture {
                system($cmd, @args);
        };
        if($exit != 0) {
    print STDERR $stdout;
    print STDERR $stderr;
                confess "Return code was ${exit}. Failed to execute command $cmd: $!";
        }
        return;
}


1;
