=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::TSV::DumpFileEna;

=head1 DESCRIPTION


=head1 AUTHOR

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::TSV::DumpFileEna;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::TSV::Base/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;
use File::Spec::Functions qw/catdir/;
use File::Path qw/mkpath/;
use Data::Dumper;

sub param_defaults {
 return {
#   external_db  => 'UniProt%', #external_dbs => [qw/UniProt%/],
   type         => 'ena',
#   db_type      => 'core',
 };
}

sub fetch_input {
    my ($self) = @_;

    my $eg     = $self->param_required('eg');
    $self->param('eg', $eg);

    if($eg){
       my $base_path = $self->build_base_directory();
       my $release   = $self->param('eg_version');
       $self->param('base_path', $base_path);
       $self->param('release', $release);
    }

return;
}

sub run {
    my ($self) = @_;

    $self->info( "Starting ENA tsv dump for " . $self->param('species'));
    $self->_write_tsv();
    $self->_create_README();
    $self->info( "Completed ENA tsv dump for " . $self->param('species'));
    $self->cleanup_DBAdaptor();

return;
}

#############
##SUBROUTINES
#############
sub _write_tsv {
    my ($self) = @_;

    my $out_file  = $self->_generate_file_name();
    my $header    = $self->_build_headers();   

    open my $fh, '>', $out_file or die "cannot open $out_file for writing!";
    print $fh join ("\t", @$header);
    print $fh "\n";

    # get ENA contig details
    my $contig_ids = $self->_get_enacontigs();
    # create lookup list of translations to CDSs
    my $cds2acc    = $self->_get_cds();
    my $ta         = $self->core_dba()->get_TranscriptAdaptor();
    my $taxon_id   = $self->core_dba()->get_MetaContainer()->get_taxonomy_id();
    my $name       = $self->web_name();

    my $helper     = $self->core_dbc()->sql_helper();
    my $sql        = 'SELECT g.stable_id, t.stable_id, tr.stable_id, srs.synonym, NULL
                	FROM coord_system cs
                	JOIN seq_region sr USING (coord_system_id)
               		LEFT JOIN seq_region_synonym srs ON (srs.seq_region_id=sr.seq_region_id)
                	LEFT JOIN external_db es ON (srs.external_db_id=es.external_db_id AND db_name="EMBL")
                	JOIN gene g ON (g.seq_region_id=sr.seq_region_id)
                	JOIN transcript t using (gene_id)
                	LEFT JOIN translation tr using (transcript_id)
                	WHERE cs.species_id=? ORDER BY g.stable_id';

    my $iterator  = $helper->execute(
                              -SQL      => $sql,
                              -PARAMS   => [ $self->core_dba()->species_id() ],
                              -ITERATOR => 1);

    while($iterator->has_next()) {
        my $row   = $iterator->next();
        # Prepend taxon id and species name
        unshift @$row, $taxon_id;
        unshift @$row, $name;

	# species	taxid	gene_stable_id	transcript_stable_id	protein_stable_id	primary_accession	secondary_accession
	# Schizosaccharomyces_pombe	284812	SPAC1002.01	SPAC1002.01.1	SPAC1002.01.1:pep	CU329670	CAB90312
        if(!defined $row->[5]){
	   $row->[5] = $self->_find_contig($ta, $contig_ids, $row->[3] );
        } elsif( !defined $row->[6] && defined $row->[4]){
	   $row->[6] = $cds2acc->{$row->[4]}; 
 	} 

	if (defined $row->[5]) {
            $row->[5] =~ s/\.[0-9]+$//;
            $row->[6] =~ s/\.[0-9]+$// if (defined $row->[6]);
	    print $fh join "\t", @$row;
	    print $fh "\n";
        }
    }
    close $fh;

    $self->info( "Compressing ENA tsv dump for " . $self->param('species'));
    my $unzip_out_file = $out_file;
    `gzip $unzip_out_file`;


return;
}

sub _build_headers {
    my ($self) = @_;

    return [
	qw/species taxid gene_stable_id transcript_stable_id protein_stable_id primary_accession secondary_accession/
    ];
}

sub _get_enacontigs {
    my ($self) = @_;
    my $sql    = 'SELECT s.name
                   FROM coord_system cs
         	   JOIN seq_region s USING (coord_system_id)
         	   JOIN seq_region_attrib sa USING (seq_region_id)
         	   JOIN attrib_type a USING (attrib_type_id) 
         	   WHERE cs.species_id =?
	           AND sa.value="ENA"
		   AND a.code="external_db"';

    my $helper = $self->core_dbc()->sql_helper();

    # whitelist - sequence regions we know are ENA
    my %contig_ids = map { $_ => 1 } @{$helper->execute_simple(
  				    	-SQL    => $sql,
					-PARAMS => [ $self->core_dba()->species_id() ] ) 
				};

return \%contig_ids;
}

sub _get_cds {
    my ($self)  = @_;
    my $sql     = 'SELECT tr.stable_id, x.dbprimary_acc
	     	   FROM coord_system cs
		   JOIN seq_region sr USING (coord_system_id)
		   JOIN gene g ON (g.seq_region_id=sr.seq_region_id)
		   JOIN transcript t USING (gene_id)
		   JOIN translation tr USING (transcript_id)
		   JOIN object_xref ox ON (tr.translation_id = ox.ensembl_id AND ox.ensembl_object_type ="Translation")
		   JOIN xref x ON (ox.xref_id = x.xref_id)
		   JOIN external_db ex on (x.external_db_id = ex.external_db_id)
		   WHERE cs.species_id = ?
		   AND  ex.db_name="protein_id"';

    my $helper  = $self->core_dbc()->sql_helper();
    my $cds2acc = $helper->execute_into_hash(
	           -SQL => $sql, 
	           -PARAMS => [ $self->core_dba()->species_id() ] );

return $cds2acc;
}

sub _find_contig {
    my ( $self, $ta, $contig_ids, $transcript_id ) = @_;

    $self->info( "Finding missing contig for " . $transcript_id );
    my $transcript        = $ta->fetch_by_stable_id($transcript_id);
    my $transcript_contig = $transcript->transform('seqlevel');

    if ( defined $transcript_contig ) {
	my $contig_name = $transcript_contig->slice()->seq_region_name();

	if ( exists $contig_ids->{$contig_name} ) {
	  $self->info("Found contig " . $contig_name . " for " . $transcript_id );
	  return $contig_name;
	}
    }
return;
}

sub _create_README {
    my ($self) = @_;

    my $readme = <<README;
--------------------------
Tab Separated Values Dumps
--------------------------

The files provided here are to give highlevel summaries of datasets in an 
easy to parse format. All TSV files are gzipped and their first line is a 
header line for file content.

+++++++++++++++++++++++++
Stable ID to ENA Ac
+++++++++++++++++++++++++

Provides mappings from Gene, Transcript and Translation stable identifiers to 
ENA accessions.

File are named Species.assembly.release.ena.tsv.gz

README

    my $data_path = $self->get_data_path('tsv');
    mkpath($data_path);
    my $path      = File::Spec->catfile($data_path, 'README_ENA.tsv');

    work_with_file($path, 'w', sub {
      my ($fh) = @_;
      print $fh $readme;
    return;
    });

return;
}

1;
