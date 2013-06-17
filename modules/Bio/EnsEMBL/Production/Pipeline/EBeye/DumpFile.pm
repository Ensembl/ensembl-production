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
use Bio::EnsEMBL::Utils::IO qw/gz_work_with_file/;
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

  my $dbc = $dba->dbc();
  defined $dbc or die "Unable to get DBConnection";

  # disable for the moment
  # my ($want_species_orthologs, $ortholog_lookup) =
  #   $self->_fetch_orthologs;
  #
  # my ($exons, $haplotypes, $alt_alleles, $xrefs, $gene_info) = 
  #   ($self->_fetch_exons($dbc),
  #    $self->_fetch_haplotypes($dbc),
  #    $self->_fetch_alt_alleles($dbc),
  #    $self->_fetch_xrefs($dbc),
  #    $self->_fetch_gene_info($dbc));
  
  my $path = $self->_generate_file_name();
  $self->info("Dumping EBI Search output to %s", $path);

  gz_work_with_file($path, 'w', 
		    sub {
		      my ($fh) = @_;
		      print $fh "Test\n";
		    });
  
}

sub _fetch_gene_info {
  my ($self, $dbc) = @_;

  my $gene_info = $dbc->db_handle->selectall_arrayref("SELECT g.gene_id, t.transcript_id, tr.translation_id,
                                                              g.stable_id AS gsid, t.stable_id AS tsid, tr.stable_id AS trsid,
                                                              g.description, ed.db_name, x.dbprimary_acc, 
                                                              x.display_label, ad.display_label, ad.description, 
                                                              g.source, g.status, g.biotype
                                                       FROM ((
                                                             ( gene AS g, analysis_description AS ad, transcript AS t) 
                                                             LEFT JOIN 
                                                               translation AS tr ON t.transcript_id = tr.transcript_id) 
                                                             LEFT JOIN
                                                               xref AS x ON g.display_xref_id = x.xref_id) 
                                                             LEFT JOIN
                                                               external_db AS ed ON ed.external_db_id = x.external_db_id
                                                       WHERE t.gene_id = g.gene_id AND g.analysis_id = ad.analysis_id
                                                       ORDER BY g.stable_id, t.stable_id" 
						     ) or die $dbc->db_handle->errstr;

  return $gene_info;
}

sub _fetch_xrefs {
  my ($self, $dbc) = @_;

  my %xrefs      = ();
  foreach my $type (qw(Gene Transcript Translation)) {
    my $T = $dbc->db_handle->selectall_arrayref("SELECT ox.ensembl_id, x.display_label, x.dbprimary_acc, ed.db_name, es.synonym
                                                 FROM (object_xref AS ox, xref AS x, external_db AS ed) LEFT JOIN external_synonym AS es ON es.xref_id = x.xref_id
                                                 WHERE ox.ensembl_object_type = '$type' AND ox.xref_id = x.xref_id AND x.external_db_id = ed.external_db_id"
					       ) or die $dbc->db_handle->errstr;

    foreach (@$T) {
      $xrefs{$type}{ $_->[0] }{ $_->[3] }{ $_->[1] } = 1 if $_->[1];
      $xrefs{$type}{ $_->[0] }{ $_->[3] }{ $_->[2] } = 1 if $_->[2];
      $xrefs{$type}{ $_->[0] }{ $_->[3] . "_synonym" }{ $_->[4] } = 1
	if $_->[4];
    }

  }

  return \%xrefs;
}

#
# WARNING
#
# This has to be changed at some point, 
# as Kieron is changing the table structure
#
sub _fetch_alt_alleles {
  my ($self, $dbc) = @_;

  my $alt_alleles = $dbc->db_handle->selectall_hashref(qq{SELECT gene_id, is_ref FROM alt_allele}, 
						       'gene_id') or die $dbc->db_handle->errstr;

  return $alt_alleles;
}

sub _fetch_haplotypes {
  my ($self, $dbc) = @_;

  my $haplotypes = $dbc->db_handle->selectall_hashref("SELECT gene_id, exc_type 
					               FROM gene g, assembly_exception ae 
                                                       WHERE g.seq_region_id=ae.seq_region_id
                                                             AND ae.exc_type IN (?,?,?)", 
						      'gene_id', {}, 'HAP', 'PATCH_NOVEL', 'PATCH_FIX'
						     ) or die $dbc->db_handle->errstr;

  return $haplotypes;
}

sub _fetch_exons {
  my ($self, $dbc) = @_;

  my %exons = ();
  my $get_genes_sth = $dbc->prepare("SELECT DISTINCT t.gene_id, e.stable_id
                                     FROM transcript AS t, exon_transcript As et, exon AS e
                                     WHERE t.transcript_id = et.transcript_id and et.exon_id = e.exon_id"
				   );


  $get_genes_sth->execute;
  my $gene_rows = [];		# cache for batches of rows

  while (
	 my $row = (
		    shift(@$gene_rows) || # get row from cache, or reload cache:
		    shift(
			  @{
			    $gene_rows =
			      $get_genes_sth->fetchall_arrayref( undef, 10_000 )
				|| []
			      }
			 )
		   )
	) {
    $exons{ $row->[0] }{ $row->[1] } = 1;
  }
  $get_genes_sth->finish;

  return \%exons;
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

