package Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::Genome;

use Moose;
use Path::Tiny qw(path);
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeReport;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::ChromReport;
use DBI;

#use ProjectPath qw(output_path);

use overload '""' => 'stringify';

has 'genome_id'   => ( isa => 'Str', is => 'ro', required => 1 );
has 'gca'         => ( isa => 'Str', is => 'ro', required => 1 );
has 'species'     => ( isa => 'Str', is => 'ro', required => 1 );
has 'division'    => ( isa => 'Str', is => 'ro', required => 0 );
has 'species_id'  => ( isa => 'Int', is => 'ro', required => 1, default =>  1 );
has 'version'     => ( isa => 'Str', is => 'ro', required => 1 );
has 'dbname'      => ( isa => 'Str', is => 'ro', required => 0 );
has 'type'        => ( isa => 'Str', is => 'ro', required => 1, default => 'EnsemblVertebrates' );
has 'chunk_size'  => ( isa => 'Int', is => 'ro', required => 1, default => 5000000 );
has 'root_path'   => ( isa => 'Path::Tiny', is => 'ro', required => 1 );

#has 'settings'    => ( isa => 'HashRef', is => 'ro', default => sub {
#  return {
#    grch37    => { hostname => 'ensembldb.ensembl.org', port => 3337, user => 'anonymous', rest => 'grch37.rest.ensembl.org' },
#    EnsemblVertebrates      => { hostname => 'mysql-ens-sta-1.ebi.ac.uk', port => 4519, user => 'ensro', rest => 'rest.ensembl.org' },
#    non_vert  => { hostname => 'mysql-eg-publicsql.ebi.ac.uk', port => 4157, user => 'anonymous', rest => 'rest.ensembl.org' },
#  }
#});

sub stringify {
  my ($self) = @_;
  return $self->genome_id();
}

#sub get_dbh {
#  my ($self) = @_;
#  my $s = $self->settings()->{$self->type()};
#  my $database = $self->dbname();
#  my $hostname = $s->{hostname};
#  my $port = $s->{port};
#  my $user = $s->{user};
#  my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
#  my $dbh = DBI->connect($dsn, $user, undef, { RaiseError => 1});
#  return $dbh;
#}

#sub rest {
#  my ($self) = @_;
#  return $self->settings()->{$self->type()}->{rest};
#}

sub genome_output_path {
  my ($self) = @_;
  return $self->root_path; #output_path();
}

sub common_files_path {
  my ($self) = @_;
  my $path = $self->genome_output_path()->child('common_files')->child($self->genome_id());
  return $self->_check_path($path);
}

sub genes_transcripts_path {
	my ($self) = @_;
	my $path =$self->genome_output_path()->child('genes_and_transcripts')->child($self->genome_id());
  return $self->_check_path($path);
}

sub contigs_path {
	my ($self) = @_;
	my $path =$self->genome_output_path()->child('contigs')->child($self->genome_id());
	return $self->_check_path($path);
}

sub seqs_path {
	my ($self) = @_;
	my $path =$self->genome_output_path()->child('seqs')->child($self->genome_id());
	return $self->_check_path($path);
}

sub gc_path {
	my ($self) = @_;
	my $path =$self->genome_output_path()->child('gc')->child($self->genome_id());
	return $self->_check_path($path);
}

sub variants_path {
	my ($self) = @_;
	my $path =$self->genome_output_path()->child('variants')->child($self->genome_id());
	return $self->_check_path($path);
}

sub to_seq_id {
  my ($self, $object) = @_;
  my $sub = $object->can('md5_hex');
  if(! defined $sub) {
    confess "Cannot call the method md5_hex on the given object ${object}";
  }
  return $sub->($object);
}

sub get_seq_path {
  my ($self, $object) = @_;
  my $seq_id = $self->to_seq_id($object);
  my $path = $self->seqs_path()->child($seq_id);
  return $path;
}

sub genome_report_path {
  my ($self) = @_;
  return $self->common_files_path->child('genome_report.txt');
}

sub chrom_sizes_path {
  my ($self) = @_;
  return $self->common_files_path->child('chrom.sizes');
}

sub chrom_hashes_path {
	my ($self) = @_;
	return $self->common_files_path->child('chrom.hashes');
}

sub genome_summary_bed_path {
	my ($self) = @_;
	return $self->common_files_path->child('genome_summary.bed');
}

sub contigs_bb_path {
  my ($self) = @_;
	return $self->contigs_path->child('contigs.bb');
}

sub gc_bw_path {
	my ($self) = @_;
	return $self->gc_path->child('gc.bw');
}

sub canonical_transcripts_bb_path {
	my ($self) = @_;
	return $self->genes_transcripts_path->child('canonical.bb');
}

sub all_transcripts_bb_path {
	my ($self) = @_;
	return $self->genes_transcripts_path->child('all.bb');
}

sub genes_bb_path {
	my ($self) = @_;
	return $self->genes_transcripts_path->child('genes.bb');
}

sub _check_path {
  my ($self, $path) = @_;
  if(! $path->is_dir()) {
    $path->mkpath();
  }
  return $path;
}

sub get_genome_report {
  my ($self) = @_;
  return Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeReport->build_from_report($self);
}

sub get_chrom_report {
  my ($self, $sort_by_name) = @_;
  return Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::ChromReport->build_from_report($self, $sort_by_name);
}

__PACKAGE__->meta->make_immutable;

1;
