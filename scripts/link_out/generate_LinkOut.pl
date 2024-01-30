# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2024] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Generate LinkOut resource file for NCBI website.
# Author: Monika Komorowska
# Date : 06.04.2011


use strict;
use DBI;
use Getopt::Long;

sub new_file;

my ( $dbpattern, $out_file, $config_file, $output_dir );

GetOptions( "dbpattern|pattern=s", \$dbpattern, "out_file=s", \$out_file,
            "config_file=s", \$config_file,"output_dir=s", \$output_dir );

if ( !$dbpattern ) {
  usage();
}

if ( !$config_file ) {
  $config_file = "linkOut_config.txt";
}
if (!$output_dir)
{
  $output_dir="./";
}

open( CFH, "<$config_file" ) or die("Can't open $config_file\n");
my @hosts;
while ( my $line = <CFH> ) {
  push( @hosts, $line );
}
close CFH;

#delete the old resource files
if ( -e $output_dir."resources1.xml" ) {
  exec("rm -r ".$output_dir."resources*");
}

if ( !$out_file ) {
  $out_file = "resources";
}

my $file_size;
my $number_of_files = 1;

my $header = <<HEADER;
<?xml version="1.0"?>
<!DOCTYPE LinkSet PUBLIC "-//NLM//DTD LinkOut 1.0//EN"
"http://www.ncbi.nlm.nih.gov/entrez/linkout/doc/LinkOut.dtd"
[<!ENTITY base.url "http://www.ensembl.org/id/">]>

<LinkSet>
HEADER

my $header_size;
{
  use bytes;
  $header_size = length($header);
}

new_file();
my $link_no = 0;

foreach my $host_line (@hosts) {
  $host_line =~ /([^\s]+)\s+([^\s]+)\s*(\d*)/;
  my $host = $1;
  my $user = $2;
  my $port = $3;

  my $dsn = "DBI:mysql:host=$host";
  if ( $port =~ /\d+/ ) {
    $dsn .= ";port=$port";
  }
  my $db = DBI->connect( $dsn, $user );
  if ( !defined $db ) {
    my $message = "Can't connect to host: $host, port: ";
    if ( $port =~ /\d+/ ) {
      $message .= $port;
    } else {
      $message .= 'default';
    }
    $message .= ", user: $user\n";
    print STDOUT $message;
    next;
  }

  my @dbnames =
    map { $_->[0] } @{ $db->selectall_arrayref("show databases") };

  for my $dbname (@dbnames) {
    if ($dbpattern) {
      if ( $dbname !~ /$dbpattern/ ) {
        next;
      }
    }

    $db->do("use $dbname");
    #get nucleotide data
    my ( $entrez_db, $ref_seq_accession, $ensembl_stable_id );
    my $current_file_no = $number_of_files;
    $entrez_db = "Nucleotide";

    my $sth = $db->prepare(
"SELECT dbprimary_acc,  stable_id FROM object_xref o INNER JOIN xref x on o.xref_id = x.xref_id INNER JOIN external_db e on e.external_db_id =x.external_db_id INNER JOIN transcript on ensembl_id = transcript_id WHERE db_name in ('RefSeq_dna', 'RefSeq_dna_predicted', 'RefSeq_mRNA', 'RefSeq_mRNA_predicted', 'RefSeq_ncRNA', 'RefSeq_ncRNA_predicted') GROUP BY dbprimary_acc,  stable_id"
    );
    $sth->execute();
    print STDOUT "Writing out nucleotide links for database $dbname\n";
    my $nucleotide_links = 0;
    while ( ( $ref_seq_accession, $ensembl_stable_id ) =
            $sth->fetchrow_array() )
    {
      $link_no++;
      my $link = " <Link>
  <LinkId>$link_no</LinkId>
  <ProviderId>7853</ProviderId>
  <ObjectSelector>
    <Database>$entrez_db</Database>
    <ObjectList>
      <Query>$ref_seq_accession</Query>
    </ObjectList>
  </ObjectSelector>
  <ObjectUrl>
    <Base>&base.url;</Base>
    <Rule>$ensembl_stable_id</Rule>
  </ObjectUrl>
 </Link>\n";
      {
        use bytes;
        my $byte_size = length($link);
        $file_size += $byte_size;
      }
      #each file has a limit of 20Mb
      if ( $file_size >= 19900000 ) {
        $number_of_files++;
        new_file();
      }
      print FH $link;
      $nucleotide_links++;
    } ## end while ( ( $ref_seq_accession...))

    $sth->finish();
    my $message =
      "Written out $nucleotide_links nucleotide links for database $dbname";
    if ( $nucleotide_links > 0 ) {
      $message .= " in file(s):\n";
      for ( my $i = $current_file_no ; $i <= $number_of_files ; $i++ ) {
        $message .= $out_file . "_" . "$i\n";
      }
    } else {
      $message .= "\n";
    }
    print STDOUT $message;

    #get protein data
    $current_file_no = $number_of_files;
    $entrez_db       = "Protein";
    $sth = $db->prepare(
"SELECT dbprimary_acc,  stable_id FROM object_xref o INNER JOIN xref x on o.xref_id = x.xref_id INNER JOIN external_db e on e.external_db_id =x.external_db_id INNER JOIN translation on ensembl_id = translation_id WHERE db_name in ('RefSeq_peptide', 'RefSeq_peptide_predicted') group by dbprimary_acc,  stable_id"
    );
    $sth->execute();
    print STDOUT "Writing out protein links for database $dbname\n";
    my $protein_links = 0;
    while ( ( $ref_seq_accession, $ensembl_stable_id ) =
            $sth->fetchrow_array() )
    {
      $link_no++;
      my $link = " <Link>
  <LinkId>$link_no</LinkId>
  <ProviderId>7853</ProviderId>
  <ObjectSelector>
    <Database>$entrez_db</Database>
    <ObjectList>
      <Query>$ref_seq_accession</Query>
    </ObjectList>
  </ObjectSelector>
  <ObjectUrl>
    <Base>&base.url;</Base>
    <Rule>$ensembl_stable_id</Rule>
  </ObjectUrl>
 </Link>\n";
      {
        use bytes;
        my $byte_size = length($link);
        $file_size += $byte_size;
      }
      #each file has a limit of 20Mb
      if ( $file_size >= 19900000 ) {
        $number_of_files++;
        new_file();
      }
      print FH $link;
      $protein_links++;
    } ## end while ( ( $ref_seq_accession...))

    $sth->finish();
    $message =
      "Written out $protein_links protein links for database $dbname";
    if ( $protein_links > 0 ) {
      $message .= " in file(s):\n";
      for ( my $i = $current_file_no ; $i <= $number_of_files ; $i++ ) {
        $message .= $out_file . "$i\n";
      }
    } else {
      $message .= "\n";
    }
    print STDOUT $message;
  } ## end for my $dbname (@dbnames)

  $db->disconnect();
  print FH "</LinkSet>";
  close FH;
} ## end foreach my $host_line (@hosts)

sub usage {
  print STDERR <<EOF

    Usage: generate_LinkOut options
      -dbpattern database name pattern
      -out_file output resource file name, default 'resources'
      -output_dir output directory
      -config_file should contain one or more lines with: host user port(optional), e.g. ens-staging1 ensro
EOF
    ;
  exit;
}

sub new_file {
  if ( $number_of_files > 1 ) {
    print FH "</LinkSet>";
    close FH;
  }
  my $file_name = $output_dir . $out_file . $number_of_files . '.xml';
  open( FH, ">$file_name" ) or die("Can't open $file_name\n");
  print FH $header;
  $file_size = $header_size;
}
