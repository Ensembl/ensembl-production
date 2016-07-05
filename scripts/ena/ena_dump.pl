#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
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


use strict;
use warnings;

use Getopt::Long;
use IO::File;

use Bio::EnsEMBL::Registry;
use Net::FTP;

my $gene_file;
my $trans_file;
my $host = 'ens-livemirror';
my $port = 3306;
my $user = 'ensro';
my $version;
my $upload_only;
my $dump_only;
my $ftp_user;
my $ftp_pass;
my $help;
my $reg_file;

GetOptions(
    "gene_file=s" => \$gene_file,
    "trans_file=s" => \$trans_file,
    "host=s" => \$host,
    "port=i" => \$port,
    "user=s" => \$user,
    "db_version=i" => \$version,
    "upload_only!" => \$upload_only,
    "dump_only!" => \$dump_only,
    "ftp_user=s" => \$ftp_user,
    "ftp_pass=s" => \$ftp_pass,
    "h|help!" => \$help,
    "reg_file=s" => \$reg_file,
);

if (
       ($upload_only && $gene_file && $trans_file && $ftp_user && $ftp_pass)
    || ($dump_only && $host && $user && $port && $gene_file && $trans_file)
    || ($host && $port && $user && $gene_file && $trans_file && $ftp_user && $ftp_pass)
    || ($dump_only && $reg_file && $gene_file && $trans_file)
    || ($reg_file && $gene_file && $trans_file && $ftp_user && $ftp_pass)
) {
    print "Beginning\n";
} elsif ($help) {
    &usage;
} else {
    print "Required argument missing\n";
    &usage;
    exit 1;
}

my $reg = 'Bio::EnsEMBL::Registry';
our ($gene_fh, $transcript_fh);

unless ($upload_only) {
    print "Dumping\n";

    if ($reg_file) {
        $reg->load_all($reg_file);
    } else {
        $reg->load_registry_from_db(
              -host    => $host,
              -user    => $user,
              -port    => $port,
              -DB_VERSION => $version,
              -set_disconnect_when_inactive => 1,
              -set_reconnect_when_lost => 1,
        );
    }

    $gene_fh = new IO::File "> $gene_file";
    $transcript_fh = new IO::File "> $trans_file";

    print $gene_fh "INSDC\tProtein ID\tFeature ID\tDB name\tTaxon\n";
    print $transcript_fh "INSDC\tProtein ID\tFeature ID\tDB name\tTaxon\n";

    my @species = @{$reg->get_all_species()};

    foreach my $name (@species) {
        dump_features($name);
    }

    $gene_fh->close;
    $transcript_fh->close;
}

unless ($dump_only) {
    print "Attempting to upload to FTP site\n";
    my $result = upload_to_ftp($gene_file,$trans_file);
    if ($result) {
        print "Mission accomplished.\n";
        exit 1;
    } else {
        die "Upload to FTP failed. Check login details and FTP host status";
    }
}
######

sub dump_features {
    my $species = shift;

    my $meta = $reg->get_adaptor($species,'Core','MetaContainer');
    my $taxon = $meta->get_taxonomy_id();

    my $dbea = $reg->get_adaptor($species,'core','DBEntry');
    my $external_dbid = $dbea->get_external_db_id('EMBL',undef,1);

    my @db_ids = $dbea->list_gene_ids_by_external_db_id($external_dbid);

    my $gene_xrefs = 0;
    my $trans_xrefs = 0;

    my $ga = $reg->get_adaptor($species,'core','gene');
    my $change = 0;
    foreach my $gene_dbID (@db_ids) {
        my $gene = $ga->fetch_by_dbID($gene_dbID);
        $change = write_feature($gene,$taxon);
        $gene_xrefs += $change;
        if ($change && $gene_xrefs % 1000 == 1) {print "Dumped $gene_xrefs genes\n";}
    }

    my $ta = $reg->get_adaptor($species,'core','transcript');    
    @db_ids = $dbea->list_transcript_ids_by_external_db_id($external_dbid);
    $change = 0;
    foreach my $tran_dbID (@db_ids) {
        my $tran = $ta->fetch_by_dbID($tran_dbID);
        $change = write_feature($tran,$taxon);
        $trans_xrefs += $change;
        if ($change && $trans_xrefs % 1000 == 1) {print "Dumped $trans_xrefs transcripts\n";}
    }

    printf "%s: Dumped %s Gene Xrefs and %s Transcript Xrefs\n",$species,$gene_xrefs,$trans_xrefs;
}

sub write_feature {
    my $feature = shift;
    my $taxon = shift;
    my $fh;
    if (ref($feature) eq 'Bio::EnsEMBL::Gene') {$fh = $gene_fh;}
    elsif (ref($feature) eq 'Bio::EnsEMBL::Transcript') {$fh = $transcript_fh;}
    my $xref_id;
    my $dbes = $feature->get_all_DBLinks('EMBL');

    foreach my $xref (@$dbes) {
        printf $fh "%s\t%s\t%s\t%s\n",
               $xref->primary_id,
               $feature->stable_id,
               $feature->adaptor->dbc->dbname,
               $taxon;
    }
    return scalar(@$dbes);
}

sub upload_to_ftp {
    my ($gene_file, $trans_file) = @_;
    my $ftp = Net::FTP->new("ftp-private.ebi.ac.uk");
    if (! $ftp) { die "$@    FTP client setup failed. Check URL"}
    $ftp->login($ftp_user,$ftp_pass) or die "FTP login failed";
    $ftp->cwd("xref");
    $ftp->put($gene_file) or warn "Pushing of gene file failed";
    $ftp->put($trans_file) or warn "Pushing of transcript file failed";
    $ftp->quit();
}

sub usage {
    print <<DOC
USAGE INSTRUCTIONS

Script for extracting all Gene and Transcript cross-links from Ensembl databases that
derive from the EMBL source. 

Arguments:

--reg_file       when dumping from multiple hosts, use a registry file to configure the
                 database parameters. It is wise to include a -set_reconnect_when_lost => 1
                 argument in the file.

--user           collected login details for the Ensembl databases
--pass
--host
--port

--gene_file      defines the file to dump gene xrefs to
--trans_file     defines the file to dump transcript xrefs to

--ftp_user       required for upload to ENA FTP site
--ftp_pass       ditto

--db_version     for when the API version is not in sync with the database. Use with care.

--upload_only    Short-circuits the dump and only pushes existing files to the ENA FTP server.
--dump_only      Dumps the data to files but does not make the FTP transfer.

Outputs are dumped in the following tab-separated format:

<INSDC acc><separator><separator><gene/transcript id><separator><database name><separator><species>
HQ896422   ENSGALG00000011510    gallus_gallus_core_71_4   gallus_gallus

and

DQ453506   ENSTBEP00000005515   tupaia_belangeri_core_71_1   37347    


DOC

}
