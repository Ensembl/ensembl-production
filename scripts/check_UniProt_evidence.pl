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
use Bio::EnsEMBL::Attribute;
use PerlIO::gzip; 

use constant META_KEY    => 'removed_evidence_flag.uniprot_dbversion';
use constant ATTRIB_CODE => 'NoEvidence';
use constant ATTRIB_NUM  => 315;
use constant ATTRIB_NAME => 'Evidence for transcript removed';
use constant ATTRIB_DESC => 'Supporting evidence for this projected transcript has been removed';
use constant LSF_QUEUE   => 'normal';

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
my $uniprot_release;
my $deleted_files_directory;

my @a_dbIds = qw( 2000 2001 2200 2201 2202 2250 );
my @a_deletedIds = qw(delac_sp.txt
                      delac_tr.txt.gz);

my $uniprot_ftp="ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/";

# Check that the biotype list below is up to date by running the following MySQL query on the human database:
#select count(*),t.biotype from protein_align_feature paf,supporting_feature sf,exon e,exon_transcript et,transcript t,analysis a where paf.protein_align_feature_id=sf.feature_id and sf.feature_type='protein_align_feature' and sf.exon_id=e.exon_id and e.exon_id=et.exon_id and et.transcript_id=t.transcript_id and a.analysis_id = paf.analysis_id AND (a.logic_name LIKE "uniprot%havana" OR paf.external_db_id IN (2000,2001,2200,2201,2202,2250) AND a.logic_name NOT LIKE "uniprot%") group by t.biotype;
my %h_biotypes = ( 
                   antisense => 1,
                   IG_C_gene => 1,
                   IG_C_pseudogene =>1,
                   IG_V_gene => 1,
                   IG_V_pseudogene => 1,
                   lincRNA => 1,
                   nonsense_mediated_decay => 1,
                   non_stop_decay => 1,
                   polymorphic_pseudogene => 1,
                   processed_pseudogene => 1,
                   processed_transcript => 1,
                   protein_coding => 1,
                   pseudogene => 1,
                   retained_intron => 1,
                   sense_intronic => 1,
                   sense_overlapping => 1,
                   TEC => 1,
                   transcribed_processed_pseudogene => 1,
                   transcribed_unitary_pseudogene => 1, 
                   transcribed_unprocessed_pseudogene => 1,
                   translated_unprocessed_pseudogene => 1,
                   TR_C_gene => 1,
                   TR_D_gene => 1,
                   TR_J_gene => 1,
                   TR_V_gene => 1,
                   TR_V_pseudogene => 1,
                   unitary_pseudogene => 1,
                   unprocessed_pseudogene => 1,
                 );

&GetOptions (
        'host=s'         => \$host,
        'port=s'         => \$port,
        'user=s'         => \$user,
        'pass=s'         => \$pass,
        'dbpattern=s'    => \$dbpattern,
        'log_file=s'     => \$log_file_name,
        'params=s'       => \$params,
        'queue=s'        => \$queue,
        'deleted_file!' => \$deleted_file,
        'write!'         => \$write,
        'parallel!'      => \$parallel,
        'overwrite!'     => \$overwrite,
        'test!'          => \$test,
        'uniprot_release=s' => \$uniprot_release,
        'deleted_files_directory=s' => \$deleted_files_directory,
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

if (!$deleted_file or !$uniprot_release) {
    for my $wget_cmd (@a_deletedIds) {
        if (!$deleted_file){
          # Get the Uniprot retired id files
          system("wget -O $deleted_files_directory"."$wget_cmd $uniprot_ftp"."$wget_cmd");
        }
        # For the small Swissprot file, parse the file to get the uniprot_release.
        if ($wget_cmd =~ "sp" and !$uniprot_release)
        {
            open(IF, "$deleted_files_directory"."$wget_cmd") || die('Could not open file $wget_cmd');
            while(<IF>) {
                my $line = $_;
                if ($line =~/([0-9]{4}_[0-9]{2})/)
                {
                    $uniprot_release = "uniprot_".$1;
                    last;
                }
            }
            close(IF);
        }
    }
    $deleted_file=1;
}

if ($parallel) {
    my $exit_term = 0;
    foreach my $dbname (@dbnames) {
        next if ( $dbname !~ /$dbpattern/ );
        my $cmd = 'bsub -q '.$queue;
        $cmd .= ' '.$params if defined $params;
        $cmd .=" -M5000 -R'select[mem>5000] rusage[mem=5000]'";
        $cmd .= ' -oo '.$log_file_name.'.'.$dbname.'.log'
            .' perl '.$0.' --host '.$host.' --port '.$port.' --user '.$user.' --dbpattern '.$dbname;
        $cmd .= ' --pass '.$pass if ($pass ne '');
        $cmd .= ' --log_file '.$log_file_name.'.'.$dbname;
        $cmd .= ' --deleted_file' if defined $deleted_file;
        $cmd .= ' --write' if defined $write;
        $cmd .= ' --overwrite' if defined $overwrite;
        $cmd .= ' --uniprot_release '.$uniprot_release;
        $cmd .= ' --deleted_files_directory '.$deleted_files_directory;
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

#Using perlIO library to Get the list of deleted proteins
foreach my $Uniprot_deleted_files (@a_deletedIds) {
  my $final_Uniprot_deleted_files = $deleted_files_directory . $Uniprot_deleted_files;
  eval {
    eval {
      open(my $FILE, "<:gzip", $final_Uniprot_deleted_files) or die "Can't open '$final_Uniprot_deleted_files': $!";
        while (<$FILE>){
          chomp; 
          my $line = $_;
          $h_deleted{$1} = 1 if ($line =~ /^\s*([A-Z0-9]{6})\s*$/);
         }
        close($FILE);
    }
    or do {
      open(my $FILE, $final_Uniprot_deleted_files)or die "Can't open '$final_Uniprot_deleted_files': $!";
        while (<$FILE>){
         chomp; 
         my $line = $_;
         $h_deleted{$1} = 1 if ($line =~ /^\s*([A-Z0-9]{6})\s*$/);
        }
      close($FILE);
    };
  }
  or do {
    die "Can't process the $final_Uniprot_deleted_files file, check that the file exist and is not corrupted \n";
  };
}

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

    if (defined $ra_uniprotflagging->[0] and $uniprot_release eq $ra_uniprotflagging->[0]) {
        print STDERR "Your are using the same Uniprot database ($uniprot_release) than the last time...\n";
        exit(9) if defined $write;
    }

    my $log_file           = "$dbname\n====\n";
    my $count              = 0;
    my $write_count        = 0;
    my $gene_adaptor       = $target_db->get_GeneAdaptor();
    my $transcript_adaptor = $target_db->get_TranscriptAdaptor;
    my $attrib_adaptor     = $target_db->get_AttributeAdaptor;
    # the Overwrite option will remove all the transcript_attrib data linked to "Evidence for projected transcript removed" code
    if ($overwrite) {
        $attrib_adaptor->dbc->do('DELETE FROM transcript_attrib where attrib_type_id = '.&ATTRIB_NUM.' AND value NOT LIKE "ENS%"');
    }
    # Get all the hit name for external_db_id in (2000 2001 2200 2201 2202 2250) and logic name not like uniprot%havana
    my $sth = $target_db->dbc->prepare('SELECT distinct(paf.hit_name) FROM protein_align_feature paf, analysis a WHERE a.analysis_id = paf.analysis_id AND (a.logic_name LIKE "uniprot%havana" OR paf.external_db_id IN ('.(join(',', @a_dbIds)).') AND a.logic_name NOT LIKE "uniprot%")');
    $sth->execute;
    while( my $hit_name = $sth->fetchrow) {
        my %h_written;
        my $is_protein_obsolete = check_if_obsolete_protein($hit_name);
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
            $meta_adaptor->update_key_value(&META_KEY, $uniprot_release);
        }
        else {
            $meta_adaptor->store_key_value(&META_KEY, $uniprot_release);
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

#Check if a Uniprot accession has been retired in the delac_sp and delac_tr files.
sub check_if_obsolete_protein {
    my ($hit_name) = @_;
    my ($protein_id) = $hit_name =~ /^([[:alnum:]]+)/;
    return 1 if exists  $h_deleted{$protein_id};
    #The two regex above are used to catch Protein align features wrongly tagged as Uniprot. the line below will be removed as soon as the Genebuild team have resolve this issue.
    return 1 if $hit_name=~ /^[A-Z]{3}[0-9]{5}.[0-9]{1}$/;
    return 1 if $hit_name=~ /^[A-N,R-Z]{1}[0-9]{5}$/;
# Sometimes the hit name is an old one and have been replace in the current version of Uniprot.
    if ($hit_name =~ /_/) {
        return 1;
    }
    return 0;
}

sub Usage {
    print <<EOF
 $0 --host <host name> --dbpattern <DB name> [--log_file <path to file>] [--write] [--overwrite] [--dbhost_ref <host name>] [--dbport_ref <port number>] [--port <int>] [--user <user name>] [--pass <passwd>] [--parallel] [--queue <lsf queue>] [--test] [--deleted_files_directory <path>] [--deleted_file]
        
        Mandatory
            --host      Name of the host of the target database
            --dbname    Name of the target database, the one to be edited
                        
        Optionnal       
            --write     Write the attributes in the translation_attrib and transcription_attrib tables
            --overwrite Clean up the transcript_attrib table, remove all the tagged accession except "ENS%"
            --log_file  Name of the log file, all protein name with their linked element would be written here
            --port      Port number
            --user      User name, must be an admin
            --pass      Password
            --parallel  Run one job per database
            --queue     LSF queue, default normal
            --test      Test the LSF command and which databases will be checked, it won't run the script 
            --deleted_files_directory   Path to store the Uniprot retired IDs files
            --deleted_file   Flag to re-use UniProt retired IDs files   
EOF
;
    exit(1);
}
