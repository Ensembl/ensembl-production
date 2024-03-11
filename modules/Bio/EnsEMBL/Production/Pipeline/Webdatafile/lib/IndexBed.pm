=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::IndexBed;

use Moose;
use Path::Tiny;

#with 'UcscIndex';

has 'genome'    => ( is => 'Any', is => 'ro', required => 1 );
has 'bed_type'  => ( isa => 'Str', is => 'ro', required => 0 );
has 'auto_sql'  => ( isa => 'Path::Tiny', is => 'ro', required => 0 );
has 'indexes'   => ( isa => 'Str', is => 'ro', required => 0 );

sub index {
  my ($self, $bed_path) = @_;
  confess "Cannot find $bed_path" unless $bed_path->exists();
  confess "$bed_path is not a file" unless $bed_path->is_file();
  my $sorted_bed_path = $self->sort_bed($bed_path);
  my $bb_path;
  eval { $bb_path = $self->to_bigbed($sorted_bed_path); };
  if ($@) {
    warn "Failed to generate big bed file for " . $sorted_bed_path->basename;
  }
  $sorted_bed_path->remove() if $self->remove_temp_files();
  return $bb_path;
}

sub sort_bed {
  my ($self, $bed_path) = @_;
  my $sorted_bed_name = $bed_path->basename().'.sorted';
  my $sorted_bed_path = $bed_path->sibling($sorted_bed_name);
  $self->system('sort', '-k1,1', '-k2,2n', '--output='.$sorted_bed_path->stringify(), $bed_path->stringify());
  return $sorted_bed_path;
}

sub to_bigbed {
  my ($self, $bed_path) = @_;
  my $indexed_name = $bed_path->basename('.bed.sorted').'.bb';
  my $indexed_path = $bed_path->sibling($indexed_name);
  my $cmd = 'bedToBigBed';
  my @args;
  push(@args, '-type='.$self->bed_type()) if $self->bed_type();
  push(@args, '-extraIndex='.$self->indexes()) if $self->indexes();
  push(@args, '-as='.$self->auto_sql()->stringify()) if $self->auto_sql();
  push(@args,
    $bed_path->stringify(),
    $self->chrom_sizes(),
    $indexed_path->stringify(),
  );
  $self->system($cmd, @args);
  return $indexed_path;
}

# Build an instance for what you want to index

# NOTE: type gene is currently not used for indexing
sub gene {
  my ($class, $genome) = @_;
  my $path = $class->get_autosql('geneInfo.as');
  return $class->new(genome => $genome, bed_type => 'bed6', indexes => 'name', auto_sql => $path, remove_temp_files => 1);
}

sub contig {
	my ($class, $genome) = @_;
	return $class->new(genome => $genome, bed_type => 'bed6', remove_temp_files => 1);
}

sub transcript {
  my ($class, $genome) = @_;
  my $path = $class->get_autosql('transcriptsSummary.as');
  return $class->new(genome => $genome, bed_type => 'bed4+14', indexes => 'name,geneId', auto_sql => $path, remove_temp_files => 1);
}

sub variants {
  my ($class, $genome) = @_;
  return $class->new(genome => $genome, remove_temp_files => 1);
}

sub get_autosql {
  my ($class, $autosql) = @_;
  my $common = path(__FILE__)->parent(2)->child('common_files');
  return $common->child($autosql);
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
