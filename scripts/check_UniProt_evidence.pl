#!/usr/bin/env perl
# Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


# $Source$
# $Revision$

#insert into master_attrib_type (attrib_type_id,code,name,description) \
#  values (315,'RemovedProteinEvidence','Evidence for projected transcript removed','Supporting evidence for this projected transcript has been removed from Uniprot database')

use warnings;
use strict;

use Getopt::Long;
use DBI;
use Data::Dumper;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Mole::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Attribute;

use constant META_KEY    => 'removed_evidence_flag.uniprot_dbversion';
use constant ATTRIB_CODE => 'NoEvidence';
use constant ATTRIB_NUM  => 315;
use constant ATTRIB_NAME => 'Evidence for transcript removed';
use constant ATTRIB_DESC => 'Supporting evidence for this projected transcript has been removed';
use constant LSF_QUEUE   => 'normal';
use constant MOLEDB      => 'cbi5d';

# Connection to the target DB
my $host      = '';
my $port      = '';
my $user      = '';
my $pass      = '';
my $dbname    = '';
my $dbpattern = '';
my $queue     = &LSF_QUEUE;

my $log_file_name = 'checkUniprotlog';
my $params;
my $write;
my $parallel;
my $overwrite;
my $test;
my $deleted_file;

my @a_dbIds = qw( 2000 2001 2200 2201 2202 2250 );
my @a_deletedIds = qw(ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/docs/delac_sp.txt
                      ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/docs/delac_tr.txt);
my %h_biotypes = ( protein_coding => 1,
                   processed_pseudogene => 1,
                   pseudogene => 1,
                   transcribed_processed_pseudogene => 1,
                   transcribed_unprocessed_pseudogene => 1,
                   unitary_pseudogene => 1,
                   unprocessed_pseudogene => 1,
                 );
# These proteins were renammed before version 7.0 so the DB does not know them but they still exist!!!
# We don't need this white list anymore as the assembly has been rebuild
#my %h_whitelist = ( "ALC_XENLA"   => 1,
#                    "REQU1_XENLA" => 1,
#                    "APG4B_XENLA" => 1,
#                    "CATE2_XENLA" => 1,
#                    "MPIP0_XENLA" => 1,
#                    "ARGI3_XENLA" => 1,
#                    "XCAPD_XENLA" => 1,
#                    "DRD21_XENLA" => 1,
#                    "DRD22_XENLA" => 1,
#                    "HNFA2_XENLA" => 1,
#                    "HNFA1_XENLA" => 1,
#                    "CLEC1_XENLA" => 1,
#                    "PPAS_XENLA"  => 1,
#                    "AG2R_XENLA"  => 1,
#                    "MYPR1_XENLA" => 1,
#                    "CBFA_XENLA"  => 1,
#                    "RX2_XENLA"   => 1,
#                    "DPOA_XENLA"  => 1,
#                    "INVS2_XENLA" => 1,
#                    "PPAR_XENLA"  => 1,
#                    "XFOG_XENLA"  => 1,
#                    "LAMA_XENLA"  => 1,
#                    "PR6A1_XENLA" => 1,
#                    );

&GetOptions (
        'host=s'         => \$host,
        'port=s'         => \$port,
        'user=s'         => \$user,
        'pass=s'         => \$pass,
        'dbpattern=s'    => \$dbpattern,
        'log_file=s'     => \$log_file_name,
        'params=s'       => \$params,
        'queue=s'        => \$queue,
        'deleted_file=s' => \$deleted_file,
        'write!'         => \$write,
        'parallel!'      => \$parallel,
        'overwrite!'     => \$overwrite,
        'test!'          => \$test,
        );

&Usage if ($host eq '' or $dbpattern eq '');

my $dsn = "DBI:mysql:host=$host";
$dsn .= ";port=$port" if ($port);

my $db = DBI->connect( $dsn, $user, $pass );
my @dbnames = map { $_->[0] } @{ $db->selectall_arrayref("show databases") };

my $output = '';
if (-d $log_file_name) {
    $output = $log_file_name;
}
else {
    ($output) = $log_file_name =~ /^(.*\/)[^\/]+$/;
}
$deleted_file = $output.'delac_all.txt' unless defined $deleted_file;

if (!-e $deleted_file) {
    open(WF, '>>'.$deleted_file) || die('Could not open deleted file');
    for my $wget_cmd (@a_deletedIds) {
        open(IF, "wget $wget_cmd -O - |") || die('Could not get internet file!');
        while(<IF>) {
            my $line = $_;
            print WF $line if ($line =~ /^\s*([A-Z0-9]{6})\s*$/);
        }
        close(IF);
    }
    close (WF);
}

if ($parallel) {
    my $exit_term = 0;
    foreach my $dbname (@dbnames) {
        next if ( $dbname !~ /$dbpattern/ );
        my $cmd = 'bsub -q '.$queue;
        $cmd .= ' '.$params if defined $params;
        $cmd .=" -M2000 -R'select[mem>2000] rusage[mem=2000]'";
        $cmd .= ' -oo '.$log_file_name.'.'.$dbname.'.log'
            .' perl '.$0.' --host '.$host.' --port '.$port.' --user '.$user.' --dbpattern '.$dbname;
        $cmd .= ' --pass '.$pass if ($pass ne '');
        $cmd .= ' --log_file '.$log_file_name.'.'.$dbname;
        $cmd .= ' --deleted_file '.$deleted_file;
        $cmd .= ' --write' if defined $write;
        $cmd .= ' --overwrite' if defined $overwrite;
        if ($test) {
            print STDOUT $dbname, "\n";
            print STDOUT $cmd, "\n";
            next;
        }
        eval {
            my $output = `$cmd`;
            my ($jobid) = $output =~ /<(\d+)>/so;
            print STDOUT 'Created job ', $jobid, ' for ', $dbname, ' in queue ', $queue, "\n";
        };
        if ($@) {
            print STDERR 'Creation of job for ', $dbname, ' has failed!', "\n";
            ++$exit_term;
        }
    }
    exit($exit_term);
}

my %h_deleted;
# Getting the list of deleted proteins
#for my $wget_cmd (@a_deletedIds) {
#    open(IF, "wget $wget_cmd -O - |") || die('Could not get internet file!');
#    while(<IF>) {
#        chomp;
#        my $line = $_;
#        $h_deleted{$1} = 1 if ($line =~ /^\s*([A-Z0-9]{6})\s*$/);
#    }
#    close(IF);
#}
open(DF, $deleted_file) || die('Could not get internet file!');
while(<DF>) {
    chomp;
    my $line = $_;
    $h_deleted{$1} = 1 if ($line =~ /^\s*([A-Z0-9]{6})\s*$/);
}
close(DF);

# Getting the name of the latest Uniprot DB
my $uniprot_dbname = connect_and_retrieve_from_db('mm_ini', 3306, "SELECT database_name FROM ini WHERE current = 'yes' AND available = 'yes' AND database_category = 'uniprot'");
my $UA_port = connect_and_retrieve_from_db('mm_ini', 3306, "SELECT port FROM connections WHERE is_active = 'yes' AND db_name = 'uniprot_archive'");

# Retrieving the target protein feature
my $uniprot_db = new Bio::EnsEMBL::ExternalData::Mole::DBSQL::DBAdaptor(
        -host    => &MOLEDB,
        -user    => 'genero',
        -port    => 3306,
        -dbname  => $uniprot_dbname
        );

my $Uentry_adaptator  = $uniprot_db->get_EntryAdaptor;
my $UDBxref_adaptator = $uniprot_db->get_DBXrefAdaptor;


my $attribute = Bio::EnsEMBL::Attribute->new (
        -CODE => &ATTRIB_CODE,
        -NAME => &ATTRIB_NAME,
        -DESCRIPTION => &ATTRIB_DESC,
        );
my %h_countids         = ();
for my $dbname (@dbnames) {
    next if ( $dbname !~ /$dbpattern/ );
    if ($test) {
        print STDOUT $dbname, "\n";
        next;
    }
# Retrieving the target protein feature
    my $target_db = new Bio::EnsEMBL::DBSQL::DBAdaptor(
            -host    => $host,
            -user    => $user,
            -pass    => $pass,
            -port    => $port,
            -dbname  => $dbname
            );

    my $meta_adaptor       = $target_db->get_MetaContainer;
    my $ra_uniprotflagging = $meta_adaptor->list_value_by_key(&META_KEY);

    if (defined $ra_uniprotflagging->[0] and $uniprot_dbname eq $ra_uniprotflagging->[0]) {
        print STDERR "Your are using the same Uniprot database ($uniprot_dbname) than the last time...\n";
        exit(9) if defined $write;
    }

    my $log_file           = "$dbname\n====\n";
    my $count              = 0;
    my $write_count        = 0;
    my $gene_adaptor       = $target_db->get_GeneAdaptor();
    my $transcript_adaptor = $target_db->get_TranscriptAdaptor;
    my $attrib_adaptor     = $target_db->get_AttributeAdaptor;

    if ($overwrite) {
        $attrib_adaptor->dbc->do('DELETE FROM transcript_attrib where attrib_type_id = '.&ATTRIB_NUM.' AND value NOT LIKE "ENS%"');
    }
    my $sth = $target_db->dbc->prepare('SELECT distinct(hit_name) FROM protein_align_feature WHERE external_db_id IN ('.(join(',', @a_dbIds)).')');
    $sth->execute;
    while( my $hit_name = $sth->fetchrow) {
        my %h_written;
        my $is_protein_obsolete = check_if_obsolete_protein($hit_name, $Uentry_adaptator, $UDBxref_adaptator, $UA_port);
        if ($is_protein_obsolete == 1) {
            foreach my $transcript (@{$transcript_adaptor->fetch_all_by_transcript_supporting_evidence($hit_name,'protein_align_feature')}) {
                next unless (exists $h_biotypes{$gene_adaptor->fetch_by_transcript_id($transcript->dbID)->biotype});
                if (defined $write) {
                    if ($overwrite or !check_if_exists($attrib_adaptor->fetch_all_by_Transcript($transcript, &ATTRIB_CODE), $hit_name)) {
                        $attribute->value($hit_name);
                        $attrib_adaptor->store_on_Transcript($transcript, [$attribute]); 
                        ++$write_count;
                        $h_written{$transcript->dbID} = 1;
                    }
                }
                $log_file .= "T\t".$hit_name."\t".$transcript->display_id."\n";
                ++$count;
                $h_countids{$hit_name} = 1;
            }
            foreach my $transcript (@{$transcript_adaptor->fetch_all_by_exon_supporting_evidence($hit_name,'protein_align_feature')}) {
                next unless (exists $h_biotypes{$gene_adaptor->fetch_by_transcript_id($transcript->dbID)->biotype});
                if (defined $write and !exists $h_written{$transcript->dbID}) {
                    if ($overwrite or !check_if_exists($attrib_adaptor->fetch_all_by_Transcript($transcript, &ATTRIB_CODE), $hit_name)) {
                        $attribute->value($hit_name);
                        $attrib_adaptor->store_on_Transcript($transcript, [$attribute]); 
                        ++$write_count;
                        $h_written{$transcript->dbID} = 1;
                    }
                }
                $log_file .= "E\t".$hit_name."\t".$transcript->display_id."\n";
                ++$count;
                $h_countids{$hit_name} = 1;
            }
        }
    }


# Statistics
    my $stats = "\n\n";
    $stats .= $count." protein references were tagged\n";
    $stats .= scalar(keys %h_countids)." proteins that do not exist in Uniprot\n";
    $stats .= $write_count." entries written.\n" if defined $write;

    if (defined $write) {
        if (defined $ra_uniprotflagging->[0]) {
            $meta_adaptor->update_key_value(&META_KEY, $uniprot_dbname);
        }
        else {
            $meta_adaptor->store_key_value(&META_KEY, $uniprot_dbname);
        }
    }

# Write log file or print to the screen
    if ($log_file_name) {
        open WLF, ">>$log_file_name" || die("Could not write the log file for the curation of ".$dbname);
        print WLF $log_file.$stats."\n";
        close (WLF);
    }
    else {
        print STDOUT $log_file;
    }
}


### SUBS ###

sub check_if_exists {
    my ($ra_attributes, $hit_name) = @_;

    foreach my $attribute (@{$ra_attributes}) {
        return 1 if ($attribute->value eq $hit_name);
    }
    return 0;
}

sub connect_and_retrieve_from_db {
    my ($db, $port, $query) = @_;
    my $dbh = DBI->connect('DBI:mysql:database='.$db.';host='.&MOLEDB.';port='.$port, 'genero', undef, {RaiseError => 1, AutoCommit => 0}) || die("Could not connect to the $db on ".&MOLEDB." with port $port!!\n");
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my ($result) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    return $result;
}

sub check_if_obsolete_protein {
    my ($hit_name, $Uentry_adaptator, $UDBxref_adaptator, $UA_port) = @_;
    my ($protein_id) = $hit_name =~ /^([[:alnum:]]+)/;
    return 1 if exists  $h_deleted{$protein_id};
    return 0 if defined $Uentry_adaptator->fetch_by_accession($protein_id);
    return 0 if defined $Uentry_adaptator->fetch_by_name($hit_name);
    return 0 if defined $UDBxref_adaptator->fetch_by_secondary_id($hit_name);
#    return 0 if exists $h_whitelist{$hit_name};
# Sometimes the hit name is an old one and have been replace in the current version of Uniprot, so we need to look for the correspondance in the archive
    if ($hit_name =~ /_/) {
        my $archive_prot = connect_and_retrieve_from_db('uniprot_archive', $UA_port, "SELECT accession_version FROM entry WHERE name = '".$hit_name."'");
        if (! defined $archive_prot) {
            print STDERR "#".$hit_name." was changed before release 7.0 of Uniprot, check if it still exists\n";
            return -1;
        }
        $archive_prot =~ s/\.\d+//;
        return 0 if defined $Uentry_adaptator->fetch_by_accession($archive_prot);
    }
    return 1;
}

sub Usage {
    print <<EOF
 $0 --host <host name> --dbpattern <DB name> [--log_file <path to file>] [--write] [--dbhost_ref <host name>] [--dbport_ref <port number>] [--port <int>] [--user <user name>] [--pass <passwd>] [--parallel] [--queue <lsf queue>] [--test]
        
        Mandatory
            --host      Name of the host of the target database
            --dbname    Name of the target database, the one to be edited
                        
        Optionnal       
            --write     Write the attributes in the translation_attrib and transcription_attrib tables
            --log_file  Name of the log file, all protein name with their linked element would be written here
            --port      Port number
            --user      User name, must be an admin
            --pass      Password
            --parallel  Run one job per database
            --queue     LSF queue, default normal
            --test      Test the LSF command and which databases will be checked, it won't run the script
EOF
;
    exit(1);
}
