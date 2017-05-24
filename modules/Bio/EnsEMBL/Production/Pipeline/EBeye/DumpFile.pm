=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

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

=item type - The database type of data we are emitting. Should be core

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::EBeye::DumpFile;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::EBeye::Base);

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;

# use IO::Zlib;
use IO::File;
use XML::Writer;
use File::Temp;

my %exception_type_to_description = ('REF' => 'reference', 
				     'HAP' => 'haplotype', 
				     'PATCH_FIX' => 'fix_patch', 
				     'PATCH_NOVEL' => 'novel_patch');

sub param_defaults {
  my ($self) = @_;
  return {
    supported_types => { core => 1 },
    validator => 'xmllint', #can be xmlstarlet or xmllint
    xmlstarlet => 'xml',
    xmllint => 'xmllint',
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

  throw "No xmlstarlet executable given" 
    unless $self->param('xmlstarlet');
  $self->assert_executable($self->param('xmlstarlet'));
  
  return;
}

sub run {
  my ($self) = @_;

  my $type = $self->param('type');
  my $dba = $self->get_DBAdaptor($type);
  
  return unless defined $dba;

  my $dbc = $dba->dbc();
  defined $dbc or die "Unable to get DBConnection";

  my ($want_species_orthologs, $ortholog_lookup) =
    $self->_fetch_orthologs;
  
  my ($exons, $haplotypes, $alt_alleles, $xrefs, $gene_info, $snp_sth, $taxon_id, $system_name) = 
    ($self->_fetch_exons($dbc),
     $self->_fetch_haplotypes($dbc),
     $self->_fetch_alt_alleles($dbc),
     $self->_fetch_xrefs($dbc),
     $self->_fetch_gene_info($dbc),
     $self->_get_snp_sth,
     $self->_taxon_id($dbc),
     $self->_system_name($dbc));

  my $path = $self->_generate_file_name();
  $self->info("Dumping EBI Search output to %s", $path);

  # my $fh = IO::Zlib->new();
  # $fh->open($path, "wb9");
  my $fh = IO::File->new(">$path");
  my $w = XML::Writer->new(OUTPUT => $fh, 
			   DATA_MODE => 1, 
			   DATA_INDENT => 2);

  $w->xmlDecl("ISO-8859-1");
  $w->doctype("database");
  
  $w->startTag("database");
  
  $w->startTag("name");
  $w->characters($self->_dbname);
  $w->endTag;
  
  $w->startTag("description");
  my $species = $self->param('species'); $species =~ s/_/ /g;
  $w->characters(sprintf "Ensembl %s %s database", ucfirst($species), $self->param("type"));
  $w->endTag;
  
  $w->startTag("release"); 
  $w->characters($self->param("release")); 
  $w->endTag;

  $w->startTag("entries");

  my %old;

  foreach my $row (@{$gene_info}) {
    my (
  	$gene_id,                            $transcript_id,
  	$translation_id,                     $gene_stable_id,
  	$transcript_stable_id,               $translation_stable_id,
  	$gene_description,                   $extdb_db_display_name,
  	$xref_primary_acc,                   $xref_display_label,
  	$analysis_description_display_label, $analysis_description,
  	$gene_source,                        $gene_status,
  	$gene_biotype
       ) = @$row;
    if ( $old{'gene_id'} != $gene_id ) {
      if ( $old{'gene_id'} ) {

	# safe guard against problems with the variation DB
	# e.g. during testing, we don't have either the definition
	# of human variation test db or an up-to-date schema version
	eval {
	  if ( $snp_sth && $type eq 'core' ) {
	    my @transcript_stable_ids =
	      keys %{ $old{transcript_stable_ids} };
	    $snp_sth->execute("@transcript_stable_ids");
	    $old{snps} = $snp_sth->fetchall_arrayref;
	  }
	};

  	if ($want_species_orthologs) {
  	  $old{orthologs} =
  	    $ortholog_lookup->{ $old{'gene_stable_id'} };
  	}

  	$self->_write_gene($w, \%old);
      }

      my $alt_allele = 0;
      if (exists $alt_alleles->{$gene_id}) { # meaning reverses as alt_allele defines the ref alone
  	$alt_allele = $alt_alleles->{$gene_id} == 1 ? 0 : 1; 
      }
      my $hap_type = $haplotypes->{$gene_id} || q{REF};
                                
      %old = (
  	      'gene_id'                 => $gene_id,
  	      'haplotype'               => $exception_type_to_description{$hap_type},
  	      'alt_allele'              => $alt_allele,
  	      'gene_stable_id'          => $gene_stable_id,
  	      'description'             => $gene_description,
  	      'taxon_id'                => $taxon_id,
              'system_name'             => $system_name,
  	      'translation_stable_ids'  => {
  					    $translation_stable_id ? ( $translation_stable_id => 1 )
  					    : ()
  					   },
  	      'transcript_stable_ids' => {
  					  $transcript_stable_id ? ( $transcript_stable_id => 1 )
  					  : ()
  					 },
  	      'transcript_ids' => {
  				   $transcript_id ? ( $transcript_id => 1 )
  				   : ()
  				  },
  	      'exons'                => {},
  	      'external_identifiers' => {},
  	      'alt'                  => $xref_display_label
  	      ? "($extdb_db_display_name: $xref_display_label)"
  	      : "(novel gene)",
  	      'gene_name' => $xref_display_label ? $xref_display_label
  	      : $gene_stable_id,
  	      'ana_desc_label' => $analysis_description_display_label,
  	      'ad'             => $analysis_description,
  	      'source'         => ucfirst($gene_source),
  	      'st'             => $gene_status,
  	      'biotype'        => $gene_biotype
  	     );
      $old{'source'} =~ s/base/Base/;
      $old{'exons'} = $exons->{$gene_id};
      foreach my $K ( keys %{ $exons->{$gene_id} } ) {
  	$old{'i'}{$K} = 1;
      }

      foreach my $db ( keys %{ $xrefs->{'Gene'}{$gene_id} || {} } ) {
  	foreach my $K ( keys %{ $xrefs->{'Gene'}{$gene_id}{$db} } ) {
  	  $old{'external_identifiers'}{$db}{$K} = 1;

  	}
      }
      foreach my $db ( keys %{ $xrefs->{'Transcript'}{$transcript_id} || {} } ) {
  	foreach my $K ( keys %{ $xrefs->{'Transcript'}{$transcript_id}{$db} } ) {
  	  $old{'external_identifiers'}{$db}{$K} = 1;

  	}
      }
      if ($translation_id) {
        foreach my $db ( keys %{ $xrefs->{'Translation'}{$translation_id} || {} } ) {
  	  foreach my $K ( keys %{ $xrefs->{'Translation'}{$translation_id}{$db} } ) {
  	    $old{'external_identifiers'}{$db}{$K} = 1;
          }
  	}
      }
    } else {
      $old{'transcript_stable_ids'}{$transcript_stable_id}   = 1;
      $old{'transcript_ids'}{$transcript_id}                 = 1;

      foreach my $db ( keys %{ $xrefs->{'Transcript'}{$transcript_id} || {} } ) {
  	foreach my $K ( keys %{ $xrefs->{'Transcript'}{$transcript_id}{$db} } ) {
  	  $old{'external_identifiers'}{$db}{$K} = 1;
  	}
      }
      if ($translation_id) {
        $old{'translation_stable_ids'}{$translation_stable_id} = 1;
        foreach my $db ( keys %{ $xrefs->{'Translation'}{$translation_id} || {} } ) {
  	  foreach my $K ( keys %{ $xrefs->{'Translation'}{$translation_id}{$db} } ) {
  	    $old{'external_identifiers'}{$db}{$K} = 1;
          }
  	}
      }
    }
  }

  # safe guard against problems with the variation DB
  # e.g. during testing, we don't have either the definition
  # of human variation test db or an up-to-date schema version
  eval {
    if ( $snp_sth && $type eq 'core' ) {
      my @transcript_stable_ids = keys %{ $old{transcript_stable_ids} };
      $snp_sth->execute("@transcript_stable_ids");
      $old{snps} = $snp_sth->fetchall_arrayref;
    }
  };

  $old{orthologs} = $ortholog_lookup->{ $old{'gene_stable_id'} }
    if $want_species_orthologs and scalar @{$gene_info};

  $self->_write_gene($w, \%old);

  $w->endTag("entries");
  $w->endTag("database");
  $w->end();
  $fh->close();

  $self->info(sprintf "Validating %s against EB-eye data XSD", $path);
  $self->_validate($path);

  $self->run_cmd("gzip $path");

  return;
}


sub _write_gene {
  my ($self, $writer, $xml_data) = @_;

  return warn "gene id not set" 
    unless exists $xml_data->{'gene_stable_id'} and
      $xml_data->{'gene_stable_id'};

  my $gene_id     = $xml_data->{'gene_stable_id'};
  my $altid       = $xml_data->{'alt'} or die "altid not set";
  my $transcripts = $xml_data->{'transcript_stable_ids'}
    or die "transcripts not set";

  my $snps      = $xml_data->{'snps'};
  my $orthologs = $xml_data->{'orthologs'};

  my $peptides = $xml_data->{'translation_stable_ids'}
    or die "peptides not set";
  my $exons = $xml_data->{'exons'} or die "exons not set";
  my $external_identifiers = $xml_data->{'external_identifiers'}
    or die "external_identifiers not set";
  my $description = $xml_data->{'description'};
  my $gene_name   = $xml_data->{'gene_name'};
  my $type        = $xml_data->{'source'} . ' ' . $xml_data->{'biotype'}
    or die "problem setting type";
  my $haplotype        = $xml_data->{'haplotype'};
  my $alt_allele       = $xml_data->{'alt_allele'};
  my $taxon_id         = $xml_data->{'taxon_id'};
  my $system_name      = $xml_data->{'system_name'};
  my $exon_count       = scalar keys %$exons;
  my $transcript_count = scalar keys %$transcripts;
  # $description = escapeXML($description);
  # $gene_name = escapeXML($gene_name);
  # $gene_id = escapeXML($gene_id);
  # $altid = escapeXML($altid);

  $writer->startTag('entry', 'id' => $gene_id);

  $writer->startTag('name');
  $writer->characters("$gene_id $altid");
  $writer->endTag;

  $writer->startTag('description');
  $writer->characters($description);
  $writer->endTag;

  $writer->startTag('cross_references');
  $writer->emptyTag('ref', 'dbname' => 'ncbi_taxonomy_id', 'dbkey' => $taxon_id);

  my ($synonyms, $unique_synonyms);

  # for some types of xref, merge the subtypes into the larger type
  # e.g. Uniprot/SWISSPROT and Uniprot/TREMBL become just Uniprot
  # synonyms are stored as additional fields rather than cross references

  foreach my $ext_db_name ( keys %{$external_identifiers} ) {

    if ( $ext_db_name =~
	 /(Uniprot|GO|Interpro|Medline|Sequence_Publications|EMBL)/ ) {

      my $matched_db_name = $1;

      if ( $ext_db_name =~ /_synonym/ ) { # synonyms

	foreach my $ed_key ( keys %{ $external_identifiers->{$ext_db_name} } ) {
	  push @{$synonyms->{"${matched_db_name}_synonym"}}, $ed_key;
	}

      } else { # non-synonyms
	map { $writer->emptyTag('ref', 'dbname' => $matched_db_name, 'dbkey' => $_) } 
	  keys %{ $external_identifiers->{$ext_db_name} };
      }

    } else {

      foreach my $key ( keys %{ $external_identifiers->{$ext_db_name} } ) {
	# $key = escapeXML($key);
	$ext_db_name =~ s/^Ens.*/ENSEMBL/;

	if ( $ext_db_name =~ /_synonym/ ) {
	  $unique_synonyms->{$key} = 1;
	  push @{$synonyms->{"$ext_db_name"}}, $key;

	} else {
	  $writer->emptyTag('ref', 'dbname' => $ext_db_name, 'dbkey' => $key);
	}
      }

    }
  }

  map { $writer->emptyTag('ref', 'dbname' => 'ensemblvariation', 'dbkey' => $_->[0]) } @$snps;
  map { $writer->emptyTag('ref', 'dbname' => $_->[1], 'dbkey' => $_->[0]) } @$orthologs;
  $writer->endTag('cross_references');

  $writer->startTag('additional_fields');

  my $species = $self->param('species');
  $species =~ s/_/ /g;
  $species = ucfirst($species);
  $writer->startTag('field', 'name' => 'species'); $writer->characters($species); $writer->endTag;
  $writer->startTag('field', 'name' => 'system_name'); $writer->characters($system_name); $writer->endTag;
  $writer->startTag('field', 'name' => 'featuretype'); $writer->characters('Gene'); $writer->endTag;
  $writer->startTag('field', 'name' => 'source'); $writer->characters($type); $writer->endTag;
  $writer->startTag('field', 'name' => 'transcript_count'); $writer->characters($transcript_count); $writer->endTag;
  $writer->startTag('field', 'name' => 'gene_name'); $writer->characters($gene_name); $writer->endTag;
  $writer->startTag('field', 'name' => 'haplotype'); $writer->characters($haplotype); $writer->endTag;
  $writer->startTag('field', 'name' => 'alt_allele'); $writer->characters($alt_allele); $writer->endTag;
  
  map { $writer->startTag('field', 'name' => 'transcript'); $writer->characters($_); $writer->endTag } 
    keys %{$transcripts};
  $writer->startTag('field', 'name' => 'exon_count'); $writer->characters($exon_count); $writer->endTag;
  map { $writer->startTag('field', 'name' => 'exon'); $writer->characters($_); $writer->endTag } 
    keys %{$exons};
  map { $writer->startTag('field', 'name' => 'peptide'); $writer->characters($_); $writer->endTag } 
    keys %{$peptides};

  foreach my $s (keys %{$synonyms}) {
    map { $writer->startTag('field', 'name' => $s); $writer->characters($_); $writer->endTag }
      @{$synonyms->{$s}};
  }
    
  map { $writer->startTag('field', 'name' => 'gene_synonym'); $writer->characters($_); $writer->endTag } 
    keys %$unique_synonyms;

  $writer->endTag('additional_fields');
  $writer->endTag('entry');

  return;
}


sub _get_snp_sth {
  my ($self) = @_;
  my $dba = $self->get_DBAdaptor("variation");
  defined $dba and 
    return $dba->dbc->prepare("SELECT distinct(vf.variation_name) 
                               FROM transcript_variation AS tv, variation_feature AS vf 
                               WHERE vf.variation_feature_id = tv.variation_feature_id AND tv.feature_stable_id in(?)"
			     );
  
  return undef;
}

sub _taxon_id {
  my ($self, $dbc) = @_;

  my $taxon_id = $dbc->db_handle->selectrow_arrayref("SELECT meta_value 
                                                      FROM meta 
                                                      WHERE meta_key='species.taxonomy_id'")
    or die $dbc->db_handle->errstr;
  
  return $taxon_id->[0];
}

sub _system_name {
  my ($self, $dbc) = @_;

  my $system_name = $dbc->db_handle->selectrow_arrayref("SELECT meta_value
                                                      FROM meta
                                                      WHERE meta_key='species.production_name'")
    or die $dbc->db_handle->errstr;

  return $system_name->[0];
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

  my $alt_alleles = $dbc->db_handle->selectall_hashref(qq{SELECT gene_id, attrib FROM alt_allele a, alt_allele_attrib aa WHERE a.alt_allele_id = aa.alt_allele_id}, 
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

  my $gene_rows = []; # cache for batches of rows
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

    my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor('Multi', 'compara');
    defined $dba or die "Unable to get Compara DBAdaptor";
    my $dbc = $dba->dbc();
    defined $dbc or die "Unable to get Compara DBConnection";

    my @wanted_ortholog_species = keys %$orth_species;

    #  change perl array value interpolation
    local $" = qq{","};
    my $orth_species_string = qq/@wanted_ortholog_species/;

    # Get orthologs
    my $sth = $dbc->prepare(qq{SELECT gm1.stable_id, gm2.stable_id, gdb2.name
                               FROM genome_db gdb1 JOIN gene_member gm1 USING (genome_db_id) 
                                    JOIN homology_member hm1 USING (gene_member_id)
                                    JOIN homology h USING (homology_id)
                                    JOIN homology_member hm2 USING (homology_id)
                                    JOIN gene_member gm2 ON (hm2.gene_member_id = gm2.gene_member_id)
                                    JOIN genome_db gdb2 on (gm2.genome_db_id = gdb2.genome_db_id)
                               WHERE gdb1.name = "$orth_target_species" 
                                     AND gm2.source_name = "ENSEMBLGENE"
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
  # Gene_<dbname>.xml
  # e.g. Gene_homo_sapiens_core_72_37.xml
  #      Gene_mus_musculus_vega_72_38.xml
  my $file_name = sprintf "Gene_%s.xml", $self->_dbname();
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

sub _validate {
  my ($self, $ebeye_dump_xml) = @_;
  my $validator = $self->param('validator');
  if($validator eq 'xmlstarlet') {
    $self->_validate_xmlstarlet($ebeye_dump_xml);
  }
  elsif($validator eq 'xmllint') {
    $self->_validate_xmllint($ebeye_dump_xml);
  }
  else {
    $self->throw("Do not know how to validate using ${validator}");
  }
  return;
}

sub _validate_xmlstarlet {
  my ($self, $ebeye_dump_xml) = @_;
  my $xsd = $self->_create_ebeye_search_dump_xsd();
  my $err_file = $ebeye_dump_xml . '.err';
  my $cmd = 
    sprintf(q{%s val -e -s %s %s 2> %s}, 
      $self->param('xmlstarlet'),
      $xsd->filename(),
      $ebeye_dump_xml,
      $err_file);
  my ($rc, $output) = $self->run_cmd($cmd);
  throw sprintf "XML validator xmlstarlet reports failure(s) for %s EB-eye dump.\nSee error log at file %s", $self->param('species'), $err_file
    unless $output =~ /- valid/;
  unlink $err_file;
  unlink $xsd;
  return;
}

sub _validate_xmllint {
  my ($self, $ebeye_dump_xml) = @_;
  my $xsd = $self->_create_ebeye_search_dump_xsd();
  my $err_file = $ebeye_dump_xml . '.err';
  my $cmd = 
    sprintf(q{%s --schema %s --sax --stream -noout %s 2> %s}, 
      $self->param('xmllint'),
      $xsd->filename(),
      $ebeye_dump_xml,
      $err_file);
  my ($rc, $output) = $self->run_cmd($cmd);
  throw sprintf "XML validator xmllint reports failure(s) for %s EB-eye dump.\nSee error log at file %s", $self->param('species'), $err_file
    if $rc != 0;
  unlink $err_file;
  unlink $xsd;
  return;
}

sub _create_ebeye_search_dump_xsd {
  my ($self) = @_;
  
  # from http://www.ebi.ac.uk/ebisearch/XML4dbDumps.xsd 
  my $xsd = <<XSD;
<?xml version="1.0" encoding="UTF-8"?>

<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">

  <xsd:element name="database" type="databaseType" />

  <xsd:complexType name="databaseType">
    <xsd:all>
      <xsd:element name="name" type="xsd:string" minOccurs="1" />
      <xsd:element name="description" type="xsd:string" minOccurs="0" />
      <xsd:element name="release" type="xsd:string" minOccurs="0" />
      <xsd:element name="release_date" type="xsd:string" minOccurs="0" />
      <xsd:element name="entry_count" type="xsd:int" minOccurs="0" />
      <xsd:element name="entries" type="entriesType" minOccurs="1" />
    </xsd:all>
  </xsd:complexType>

  <xsd:complexType name="entriesType">
    <xsd:sequence>
      <xsd:element name="entry" type="entryType" maxOccurs="unbounded" minOccurs="1" />
    </xsd:sequence>
  </xsd:complexType>

  <xsd:complexType name="entryType">
    <xsd:all>

      <xsd:element name="name" minOccurs="0">
	<xsd:complexType>
	  <xsd:simpleContent>
	    <xsd:extension base="xsd:string">
	      <xsd:attribute name="boost" use="optional">
		<xsd:simpleType>
		  <xsd:restriction base="xsd:float">
		    <xsd:minInclusive value="1"/>
		    <xsd:maxInclusive value="3"/>
		  </xsd:restriction>
		</xsd:simpleType>
	      </xsd:attribute>
	    </xsd:extension>
	  </xsd:simpleContent>
	</xsd:complexType>
      </xsd:element>

      <xsd:element name="description" type="xsd:string" minOccurs="0" />
      <xsd:element name="authors" type="xsd:string" minOccurs="0" />
      <xsd:element name="keywords" type="xsd:string" minOccurs="0" />
      <xsd:element name="dates" type="datesType" minOccurs="0" />
      <xsd:element name="cross_references" type="cross_referencesType" minOccurs="0" />
      <xsd:element name="additional_fields" type="additional_fieldsType" minOccurs="0" />
    </xsd:all>
    <xsd:attribute name="id" type="xsd:string" use="required" />
    <xsd:attribute name="acc" type="xsd:string" />
  </xsd:complexType>

  <xsd:complexType name="additional_fieldsType">
    <xsd:sequence>
      <xsd:element name="field" type="fieldType" maxOccurs="unbounded" minOccurs="0" />
    </xsd:sequence>
  </xsd:complexType>

  <xsd:complexType name="fieldType">
    <xsd:simpleContent>
      <xsd:extension base="xsd:string">
	<xsd:attribute name="name" type="xsd:string" use="required" />
	<xsd:attribute name="boost" use="optional">
	  <xsd:simpleType>
	    <xsd:restriction base="xsd:float">
	      <xsd:minInclusive value="1"/>
	      <xsd:maxInclusive value="3"/>
	    </xsd:restriction>
	  </xsd:simpleType>
	</xsd:attribute>
      </xsd:extension>
    </xsd:simpleContent>
  </xsd:complexType>

  <xsd:complexType name="cross_referencesType">
    <xsd:sequence>
      <xsd:element name="ref" type="refType" maxOccurs="unbounded" minOccurs="0" />
    </xsd:sequence>
  </xsd:complexType>

  <xsd:complexType name="refType">
    <xsd:attribute name="dbname" type="xsd:string" use="required" />
    <xsd:attribute name="dbkey" type="xsd:string" use="required" />
    <xsd:attribute name="boost" use="optional">
      <xsd:simpleType>
	<xsd:restriction base="xsd:float">
	  <xsd:minInclusive value="1"/>
	  <xsd:maxInclusive value="3"/>
	</xsd:restriction>
      </xsd:simpleType>
    </xsd:attribute>
  </xsd:complexType>

  <xsd:complexType name="datesType">
    <xsd:sequence>
      <xsd:element name="date" type="dateType" maxOccurs="unbounded" minOccurs="0" />
    </xsd:sequence>
  </xsd:complexType>

  <xsd:complexType name="dateType">
    <xsd:attribute name="type" type="xsd:string" use="required" />
    <xsd:attribute name="value" type="xsd:string" use="required" />
  </xsd:complexType>

</xsd:schema>
XSD
  
  my $fh = File::Temp->new();
  print $fh $xsd;
  $fh->close();
  return $fh;
}

1;

