#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long qw( :config no_ignore_case );
use Pod::Usage;
use JSON;
use Bio::EnsEMBL::Production::DBSQL::DBAdaptor;
# use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub run {
  my ($class) = @_;
  my $self = bless( {}, $class );
  $self->args();
  $self->check_opts();
  my $species = $self->_species();
  if($self->{opts}->{json}) {
    $self->_write_json($species);
  }
  else {
    $self->_write_text($species); 
  }
  return;
}

sub args {
  my ($self) = @_;

  my $opts = {
    # Master database location:
    mhost     => '',
    mport     => 3306,
    mdatabase => '',

    user => '',
    pass => q{},

    version => software_version(),
  };

  my @cmd_opts = qw/
    mhost|mh=s
    mport|mP=i
    muser|mu=s
    mpass|mp=s
    mdatabase|md=s
    host|h=s@
    port|p=i@
    user|u=s
    pass|p=s
    registy|reg_conf|reg=s
    verbose|v!
    file|f=s
    json!
    version=i
    help
    man
  /;
  GetOptions( $opts, @cmd_opts ) or pod2usage( -verbose => 1, -exitval => 1 );
  pod2usage( -verbose => 1, -exitval => 0 ) if $opts->{help};
  pod2usage( -verbose => 2, -exitval => 0 ) if $opts->{man};
  $self->{opts} = $opts;
  return;
}

sub check_opts {
  my ($self) = @_;
  my $o = $self->{opts};
  foreach my $required (qw/mhost muser file/) {
    my $msg = "Required parameter --${required} was not given";
    pod2usage( -msg => $msg, -verbose => 1, -exitval => 1 ) if !$o->{$required};
  }

  # if(! $o->{registry} && ! $o->{host} && ! $o->{port}) {
  #   my $msg = "You must specify a --registry or a --host and --port to load Ensembl databases from";
  #   pod2usage( -msg => $msg, -verbose => 1, -exitval => 1 ); 
  # }
  # else {
  #   $self->_populate_registry();
  # }
  
  my $file = $o->{file};
  $self->{close_fh} = 1;
  open my $fh, '>', $o->{file} or die "Cannot open '$file' for writing: $!";
  $self->{fh} = $fh;

  return;
}

sub _species {
  my ($self) = @_;
  my $dba   = $self->_production_dba();
  my $species = $dba->get_species_manager()->get_objects(
    query => [
      is_current => 1
    ],
    sort_by => 'production_name'
  );
  return $self->_species_to_content($species);
}

sub _species_to_content {
  my ($self, $species) = @_;
  my @output;
  foreach my $s (@{$species}) {
    my $production_name = $s->production_name();
    $self->v('Processing %s (species_id: %d)', $production_name, $s->species_id() );
    my $core = Bio::EnsEMBL::Registry->get_DBAdaptor($production_name, 'core', 'no alias check');
    if(! $core) {
      $self->v('Skipping %s as a core database cannot be found', $production_name);
      next;
    }

    # Add some default data
    my $content = {
      name => $production_name,
      common_name => $s->common_name(),
      taxon => $s->taxon(),
      aliases => [map { $_->alias() } @{$s->alias()}],
      assembly_update => 0,
      repeat_mask_update => 0,
      genebuild_update => 0,
      mitochondrion_update => 0,
    };

    # Add genome info
    my $genome = $core->get_GenomeContainer();
    $content->{version} = $genome->get_version();
    $content->{accession} = $genome->get_accession() if $genome->get_accession();
    $content->{geneset_created} = $genome->get_genebuild_initial_release_date() if $genome->get_genebuild_initial_release_date();
    $content->{geneset_last_updated} = $genome->get_genebuild_last_geneset_update() if $genome->get_genebuild_last_geneset_update();

    # Try for some regulation info
    my $regulation = Bio::EnsEMBL::Registry->get_DBAdaptor($production_name, 'funcgen', 'no alias check');
    if($regulation) {
      my $rmc = $regulation->get_MetaContainer();
      my $build = $rmc->single_value_by_key('regbuild.version');
      if($build) {
        $content->{regulation_build} = $build;
        $content->{regulation_build_created} = $rmc->single_value_by_key('regbuild.initial_release_date');
        $content->{regulation_build_updated} = $rmc->single_value_by_key('regbuild.last_annotation_update');
      }
    }

    # Oh don't forget variation; we can only add variation keys if we had one
    my $variation = Bio::EnsEMBL::Registry->get_DBAdaptor($production_name, 'variation', 'no alias check');
    if($variation) {
      $content->{variation_update} = 0;
    }

    # Now go for the changes
    my $changes = $s->changelog();
    foreach my $change (@{$changes}) {
      next if $change->release_id() != $self->{opts}->{version};
      next if $change->status() ne 'handed_over';
      $content->{assembly_update} = 1 if $change->assembly() eq 'Y';
      $content->{repeat_mask_update} = 1 if $change->repeat_masking() eq 'Y';
      $content->{genebuild_update} = 1 if $change->gene_set() eq 'Y';
      $content->{variation_update} = 1 if $change->variation_pos_changed() eq 'Y';
      $content->{mitochondrion_update} = 1 if $change->mitochondrion() ne 'N';
    }

    push(@output, $content);

    $core->dbc->disconnect_if_idle();
    $regulation->dbc->disconnect_if_idle() if $regulation;
    $variation->dbc->disconnect_if_idle() if $variation;

    $self->v('Done');
  }
  return \@output;
}

sub _write_json {
  my ($self, $species) = @_;
  $self->v('Writing content to JSON');
  my $json = JSON->new->pretty()->encode($species);
  print $json;
}

sub _write_text {
  my ($self, $species) = @_;
  $self->v('Writing content to TXT');
  my @keys = qw/
    name common_name taxon version accession aliases 
    assembly_update repeat_mask_update genebuild_update variation_update mitochondrion_update
    geneset_created geneset_last_updated
    variation_update
    regulation_build regulation_build_created regulation_build_updated
  /;

  foreach my $s (@{$species}) {
    my @columns;
    foreach my $key (@keys) {
      my $value = $s->{$key};
      next unless defined $value;
      #Serialise array
      if(ref($value) && ref($value) eq 'ARRAY') {
        my $joined = join(q{;}, @{$value});
        next unless $joined;
        push(@columns, "${key}=${joined};");
      }
      #Serialise raw value
      else {
        push(@columns, "${key}=${value};");
      }
    }
    print join("\t", @columns);
    print "\n";
  }
}

sub _production_dba {
  my ($self) = @_;
  my $o      = $self->{opts};
  my %args   = (
    -HOST   => $o->{mhost},
    -PORT   => $o->{mport},
    -DBNAME => $o->{mdatabase},
    -USER   => $o->{muser}
  );
  $args{-PASS} = $o->{mpass} if $o->{mpass};
  return Bio::EnsEMBL::Production::DBSQL::DBAdaptor->new(%args);
}

sub _populate_registry {
  my ($self) = @_;
  my $o = $self->{opts};
  my $loaded = 0;
  if($o->{registy}) {
    $loaded = Bio::EnsEMBL::Registry->load_all($o->{registy});
  }
  else {
    my $count = scalar(@{$o->{host}});
    my @connections;
    for(my $i = 0; $i < $count; $i++) {
      push(@connections, { 
        -HOST => $o->{host}->[$i], -PORT => $o->{port}->[$i], -USER => $o->{user}, -PASS => $o->{pass}, 
        -DB_VERSION => $o->{version}}
      );
    }
    $loaded = Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs(@connections);
  }
  $self->v('Managed to load %d database adaptors', $loaded);
  return;
}

sub v {
  my ( $self, $msg, @args ) = @_;
  return unless $self->{opts}->{verbose};
  my $s_msg = sprintf( $msg, @args );
  my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
    localtime( time() );
  print STDERR sprintf(
    "[%02d-%02d-%04d %02d:%02d:%02d] %s\n",
    $mday, $mon, $year + 1900,
    $hour, $min, $sec, $s_msg
  );
  return;
}

sub DESTROY {
  my ($self) = @_;
  if($self->{close_fh}) {
    close $self->{fh};
  }
  return;
}

__PACKAGE__->run();

__END__

=pod 

=head1 NAME

generate_default_aliases.pl

=head1 SYNOPSIS

  ./generate_default_aliases.pl 
    -mh host -mp password -mu user [-mP port] \\
    [-md database] \\
    [-th host] [-tP port] \\
    [-tu user] [-tp password] [-td database] \\
    [-species] [-write] \\
    [-v]

=head1 DESCRIPTION

A script used to generate a minimal set of required aliases. Assuming the
production_name I<homo_sapiens> we would generate the following

=over 8

=item B<homo_sapiens>

=item B<homo sapiens>

=item B<hsapiens>

=item B<hsap>

=item B<homsap>

=back

It is up to the user to add more via the admin interface. We do not remove
aliases with this script

=head1 OPTIONS

=over 8

=item B<-mh|--mhost>

Host for the production database

=item B<-mP|--mport>

Port for the production database

=item B<-mu|--muser>

User for the production database

=item B<-mp|--mpass>

Pass for the production database

=item B<-md|--mdatabase>

Name for the production database.

=item B<-s|--species>

Species to generate the names for. Can use a SQL pattern here and multiple
cmd line entries. Please use B<production_names>.

=item B<--write>

Turns writing on. Not on by default 

=item B<--verbose>

Make the script chatty

=item B<--help>

Help message

=item B<--man>

Man page

=back

=cut
