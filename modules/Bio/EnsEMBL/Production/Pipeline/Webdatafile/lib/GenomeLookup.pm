package Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup;

use Moose;
use Path::Tiny qw(path);
use YAML::Tiny;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::Genome;

has 'location' => ( isa => 'Str', is => 'ro', required => 1, lazy => 1, default => sub {
  my ($self) = @_;
  return $self->root_path()->child('common_files')->child('genome_id_info.yml')->stringify;
});

has 'root_path' => ( isa => 'Path::Tiny', is => 'ro', lazy => 1, required => 1, default => sub {
  return path(__FILE__)->absolute->parent(2);
});

has 'yaml' => ( is => 'HashRef', is => 'ro', lazy => 1, default => sub {
  my ($self) = @_;
  my $location = $self->location;
  confess "Cannot find $location" unless -f $location;
  my $yaml = YAML::Tiny->read($location)->[0];
  return $yaml;
});

has 'lookup' =>  ( isa => 'HashRef', is => 'ro', lazy => 1, builder => 'build_lookup' );

has 'genome_data' => ( isa => 'HashRef', is => 'rw', lazy => 1, required => 1, default => sub { return {}});

sub build_lookup {
  my ($self) = @_;
  my %genome = %{$self->genome_data};
  my $lookup = {};
  $lookup->{'1'} = Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::Genome->new( "gca"=>$genome{"gca"}, "genome_id"=> $genome{"genome_id"}, 
                                                                                      "root_path"=>$genome{"root_path"}, "species"=> $genome{"species"}, 
                                                                                      "version"=>$genome{"version"}, "dbname"=>$genome{"dbname"}, "type" => $genome{"type"});
  return $lookup;
}

sub get_genome {
  my ($self, $id) = @_;
  confess "No genome id given" if ! $id;
  my $lookup = $self->lookup();
  confess "Cannot find $id in lookup" unless exists $lookup->{$id};
  return $lookup->{$id};
}

sub get_all_genomes {
  my ($self) = @_;
  my $lookup = $self->lookup();
  return [values %{$lookup}];
}

__PACKAGE__->meta->make_immutable;

1;
