=pod

=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::EBeye::DumpFile

=head1 DESCRIPTION

The main workhorse of the EBeye dumping pipeline.

The script is responsible for creating the filenames of these target
files, taking data from the database and the formatting of the XML files.
The final files are all Gzipped at normal levels of compression.

Allowed parameters are:

=over 8

=item species - The species to dump

=item base_path - The base of the dumps

=item release - The current release we are emitting

=item type - The database type of data we are emitting. Should be core or vega

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::EBeye::DumpFile;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::EBeye::Base);

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::SeqDumper;
use Bio::EnsEMBL::Utils::IO qw/gz_work_with_file work_with_file/;
use File::Path qw/rmtree/;

sub param_defaults {
  my ($self) = @_;
  return {
    supported_types => { core => 1, vega => 1 },
  };
}

sub fetch_input {
  my ($self) = @_;
  
  my $type = $self->param('type');
  throw "No type specified" unless $type;
  throw "Unsupported type '$type' specified" unless $self->param('supported_types')->{$type};
  
  throw "Need a species" unless $self->param('species');
  throw "Need a release" unless $self->param('release');
  throw "Need a base_path" unless $self->param('base_path');
  
  return;
}

sub run {
  my ($self) = @_;

  my $type = $self->param('type');
  my $dba = $self->get_DBAdaptor($type);

  return unless defined $dba;
  
  my ($want_species_orthologs, $ortholog_lookup) =
    $self->_fetch_orthologs;

  
  
}

sub _fetch_orthologs {
  my $self = shift;

  my $orth_species = {
		      'homo_sapiens'             => 'ensembl_ortholog',
		      'mus_musculus'             => 'ensembl_ortholog',
		      'drosophila_melanogaster'  => 'ensemblgenomes_ortholog',
		      'caenorhabditis_elegans'   => 'ensemblgenomes_ortholog',
		      'saccharomyces_cerevisiae' => 'ensemblgenomes_ortholog'
		     };

  my $want_species_orthologs;
  my $ortholog_lookup;
  my $species = $self->param('species');
  my $orth_target_species;
  ( $orth_target_species = lcfirst($species) ) =~ s/\s/_/;

  if ( $want_species_orthologs =
       delete( $orth_species->{$orth_target_species} ) ) {

    $self->info("Fetching orthologs [%s]", $species);

    my $dbc = Bio::EnsEMBL::Registry->get_DBAdaptor('Multi', 'compara')->dbc();
    defined $dbc or die "Unable to get Compara DBConnection";

    my @wanted_ortholog_species = keys %$orth_species;

    #  change perl array value interpolation
    local $" = qq{","};
    my $orth_species_string = qq/@wanted_ortholog_species/;

    # Get orthologs
    my $sth = $dbc->prepare(qq{SELECT m1.stable_id , m2.stable_id, gdb2.name
                               FROM genome_db gdb1 JOIN member m1 USING (genome_db_id) 
                                    JOIN homology_member hm1 USING (member_id)
                                    JOIN homology h USING (homology_id)
                                    JOIN homology_member hm2 USING (homology_id)
                                    JOIN member m2 ON (hm2.member_id = m2.member_id)
                                    JOIN genome_db gdb2 on (m2.genome_db_id = gdb2.genome_db_id)
                               WHERE gdb1.name = "$orth_target_species" 
                                     AND m2.source_name = "ENSEMBLGENE"
                                     AND gdb2.name IN ("$orth_species_string")
                                     AND h.description in ("ortholog_one2one", 
                                                           "apparent_ortholog_one2one", 
                                                           "ortholog_one2many", 
                                                           "ortholog_many2many")}
			   );

    $sth->execute;
    my $rows = []; # cache for batches of rows
    while (
	   my $row = (
		      shift(@$rows) || # get row from cache, or reload cache:
		      shift(
			    @{
			      $rows =
				$sth->fetchall_arrayref( undef, 10_000 )
				  || []
				}
			   )
		     )
          ) {
      push @{ $ortholog_lookup->{ $row->[0] } },
	[ $row->[1], $orth_species->{ $row->[2] } ];

    }
    $sth->finish;

    $self->info("Done Fetching Orthologs");
  }

  return ($want_species_orthologs, $ortholog_lookup);
}



sub _generate_file_name {
  my ($self) = @_;

  # File name format looks like:
  # Gene_<dbname>.xml.gz
  # e.g. Gene_homo_sapiens_core_72_37.xml.gz
  #      Gene_mus_musculus_vega_72_38.xml.gz
  my @name_bits;
  push @name_bits, 'Gene';
  push @name_bits, $self->_dbname();
  push @name_bits, 'xml', 'gz';

  my $file_name = join( '.', @name_bits );
  my $path = $self->data_path();

  return File::Spec->catfile($path, $file_name);
}

sub _dbname {
  my $self = shift;

  my $type = $self->param('type');
  my $dbname = $self->get_DBAdaptor($type)->dbc()->dbname();
  die "Unable to get dbname" unless defined $dbname;
  
  return $dbname;
}

1;

