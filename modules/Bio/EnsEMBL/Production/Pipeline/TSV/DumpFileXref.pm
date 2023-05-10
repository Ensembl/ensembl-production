=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::TSV::DumpFileXref;

=head1 DESCRIPTION

 Perform xref dumping which provides mappings
 from Gene, Transcript and Translation stable identifiers to UniProtKB/RefSeq/Entrez accessions.

=head1 AUTHOR

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::TSV::DumpFileXref;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::TSV::Base/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;
use File::Spec::Functions qw/catdir/;
use File::Path qw/mkpath/;

sub param_defaults {
 return {
   db_type      => 'core',
 };
}

sub fetch_input {
    my ($self) = @_;

    my $type = $self->param('type');
    my $external_db = $self->param('external_db');
    $self->param('type', $type);
    $self->param('external_db', $external_db);
    $self->param('dba', $self->get_DBAdaptor());

return;
}

sub run {
    my ($self) = @_;

    $self->info( "Starting tsv dump for " . $self->param('species'));
    $self->_write_tsv();
    $self->_create_README();
    $self->info( "Completed tsv dump for " . $self->param('species'));

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

    my $slices = $self->get_Slices($self->param('db_type'), 1);
    $self->info('Working with %s toplevel slices', scalar(@$slices));

    my $type = $self->param('type');
    my $xrefs_exist = 0;

    foreach my $slice (@$slices) {
       my @genes = @{$slice->get_all_Genes};
       $self->info('Fetch %s number of genes from slice %s', scalar(@genes), $slice->seq_region_name());

       foreach my $gene (@genes){
          my $transcript_list = $gene->get_all_Transcripts();
          foreach my $transcript (@$transcript_list){
             my $translation = $transcript->translation();

                # Get DBEntry for external_db
                my $dbentries;
                $dbentries = $transcript->get_all_DBLinks($self->param('external_db')) if($type!~/entrez/);
                $dbentries = $gene->get_all_DBLinks($self->param('external_db'))       if ($type=~/entrez/);

    		foreach my $dbentry (@$dbentries) {
                   my $src_identity  ='-';
                   my $xref_identity ='-';
                   my $linkage_type  ='-';
 		   my $g_id          = $gene->stable_id();
                   my $tr_id	     = $transcript->stable_id();
  		   my $tl_id         = '-';
		   $tl_id = $translation->stable_id() if($translation);
                   my $xref_id       = $dbentry->primary_id();
                   my $xref_db       = $dbentry->dbname();
                   my $xref_info_type= $dbentry->info_type();

                   if ($dbentry->isa('Bio::EnsEMBL::IdentityXref')){ 
 		      $src_identity  = $dbentry->ensembl_identity(); 
                      $xref_identity = $dbentry->xref_identity(); 
                   }
		   $linkage_type = join(' ', @{$dbentry->get_all_linkage_types()})if($dbentry->isa('Bio::EnsEMBL::OntologyXref'));
                   print $fh "$g_id\t$tr_id\t$tl_id\t$xref_id\t$xref_db\t$xref_info_type\t$src_identity\t$xref_identity\t$linkage_type\n";
                   $xrefs_exist = 1;
	       }#dbentry
         }#transcript
      }#gene
  }#slice 
  close $fh; 

  if ($xrefs_exist == 1) {
    $self->info( "Compressing tsv dump for " . $self->param('species'));
    my $unzip_out_file = $out_file;
    `gzip -n $unzip_out_file`;

    if (-e $unzip_out_file) { `rm $unzip_out_file`; }
  } else {
    # If we have no xrefs, delete the file (which will just have a header).
    unlink $out_file  or die "failed to delete $out_file!";
  }

return;
}

sub _build_headers {
    my ($self) = @_;

    return [qw(
      gene_stable_id transcript_stable_id protein_stable_id xref
      db_name info_type source_identity xref_identity linkage_type
  )];
}

sub _create_README {
    my ($self) = @_;
    my $type   = $self->param('type');

    my $readme = <<README;
--------------------------
Tab Separated Values Dumps
--------------------------

The files provided here are to give highlevel summaries of datasets in an 
easy to parse format. All TSV files are gzipped and their first line is a 
header line for file content.

+++++++++++++++++++++++++
Stable ID to $type Ac
+++++++++++++++++++++++++

Provides mappings from Gene, Transcript and Translation stable identifiers to 
$type accessions with reports as to the % identity of the hit where 
applicable. Dumps contain all Ensembl exeternal database names which started
with $type so duplication of hits is possible.
If there are no such mappings in the database, the file will not exist.

File are named Species.assembly.release.$type.tsv.gz

README

    my $data_path = $self->get_dir('tsv');
    my $file      = 'README_'.$type.'.tsv';
    my $path      = File::Spec->catfile($data_path, $file);

    work_with_file($path, 'w', sub {
      my ($fh) = @_;
      print $fh $readme;
    return;
    });

return;
}

1;
