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
#  values (315,'NoEvidence','Evidence for projected transcript removed','Supporting evidence for this projected transcript has been removed')

use warnings;
use strict;

use Getopt::Long;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Attribute;
use Bio::EnsEMBL::Transcript;
use Bio::EnsEMBL::Translation;


use constant META_KEY    => 'removed_evidence_flag.ensembl_dbversion';
use constant ATTRIB_CODE => 'NoEvidence';
use constant ATTRIB_NAME => 'Evidence for transcript removed';
use constant ATTRIB_DESC => 'Supporting evidence for this projected transcript has been removed';
use constant LSF_QUEUE   => 'normal';
use constant ATTRIB_NUM  => 315;
use constant PREFIX_KEY  => 'species.stable_id_prefix';

# Connection to the target DB
my $host          = '';
my $port          = '';
my $user          = '';
my $pass          = '';
# Connection to the Human DB
my $dbname_human  = '';
my $dbhost_human  = '';
my $human_port    = '';
my $human_user    = '';

my $lsf_params = '';
my @a_2x_dbs;
my $log_file_name;
my $write;
my $parallel;
my $dblist;
my $test;
my $overwrite;
my $queue = &LSF_QUEUE;

&GetOptions (
            'host=s'       => \$host,
            'port=s'       => \$port,
            'user=s'       => \$user,
            'pass=s'       => \$pass,
            'dblist=s'     => \$dblist,
            'dbname_ref=s' => \$dbname_human,
            'dbhost_ref=s' => \$dbhost_human,
            'dbuser_ref=s' => \$human_user,
            'dbport_ref=s' => \$human_port,
            'log_file=s'   => \$log_file_name,
            'queue=s'      => \$queue,
            'lsf_params=s' => \$lsf_params,
            'write!'       => \$write,
            'parallel!'    => \$parallel,
            'test!'        => \$test,
            'overwrite!'   => \$overwrite,
        );

unless ( $host ne '' and $dbname_human ne '') {
    &Usage();
    exit(255);
}

my $dsn = 'DBI:mysql:host='.$host;
$dsn .= ';port='.$port if ($port);

my $db = DBI->connect( $dsn, $user, $pass );
my @a_dbnames = map { $_->[0] } @{ $db->selectall_arrayref('show databases') };

if ($dblist) {
    @a_2x_dbs = split(/,/, $dblist);
}
else {
    @a_2x_dbs = grep {/_core_/} @a_dbnames;
}

if ($parallel) {
    my $exit_term = 0;
    for my $dbname (@a_2x_dbs) {
        ($dbname) = grep { /$dbname/ } @a_dbnames;
        next unless ($dbname);
        my $cmd = 'bsub -q '.$queue
                    .' -oo '.$log_file_name.'.'.$dbname.'.log'
                    .' perl '.$0.' --host '.$host.' --port '.$port.' --user '.$user.' --dblist '.$dbname
                    .' --dbhost_ref '.$dbhost_human.' --port '.$human_port.' --dbname_ref '.$dbname_human;
        $cmd .= ' --pass '.$pass if ($pass ne '');
        $cmd .= ' --log_file '.$log_file_name.'.'.$dbname if defined $log_file_name;
        $cmd .= ' --write' if defined $write;
        $cmd .= ' --overwrite' if defined $overwrite;
        if ($test) {
            print '[',$dbname,"]\n";
            print $cmd, "\n";
            next;
        }
        eval {
            my $output = `$cmd`;
            my ($jobid) = $output =~ /<(\d+)>/so;
            print STDOUT 'Created job ',$jobid,' for ',$dbname,' in queue ',$queue,"\n";
        };
        if ($@) {
            print STDERR 'Creation of job for ',$dbname,' has failed!',"\n";
            print STDERR $@;
            ++$exit_term;
        }
    }
    exit($exit_term);
}

# Retrieving the human genes stable ids

my $human_db = new Bio::EnsEMBL::DBSQL::DBAdaptor(
    -species => 'species1',
    -host    => $dbhost_human,
    -user    => $human_user,
    -pass    => '',
    -port    => $human_port,
    -dbname  => $dbname_human
);

my $human_meta_adaptor  = $human_db->get_MetaContainer;
my ($prefix)            = @{$human_meta_adaptor->list_value_by_key(&PREFIX_KEY)};
my $translation_adaptor = $human_db->get_TranslationAdaptor;
my %h_human_stable_ids  = map { $_ => 1 } @{$translation_adaptor->list_stable_ids()};

for my $dbname (@a_2x_dbs) {
    ($dbname) = grep { /$dbname/ } @a_dbnames;
    next unless ($dbname);
    if ($test) {
        print $dbname, "\n";
        next;
    }
# Retrieving the target protein feature
    my $target_db = new Bio::EnsEMBL::DBSQL::DBAdaptor(
      -species => 'species2',
      -host    => $host,
      -user    => $user,
      -pass    => $pass,
      -port    => $port,
      -dbname  => $dbname
    );

    my $meta_adaptor      = $target_db->get_MetaContainer;
    my ($ensemblflagging) = @{$meta_adaptor->list_value_by_key(&META_KEY)};
    my $attrib_adaptor    = $target_db->get_AttributeAdaptor;

    if (defined $ensemblflagging and $ensemblflagging eq $dbname_human) {
        print STDERR 'This species have already been flagged with this database (',$dbname_human,")!\n";
        exit(9) if $write;
    }
    if ($overwrite) {
        $attrib_adaptor->dbc->do('DELETE FROM transcript_attrib WHERE attrib_type_id = '.&ATTRIB_NUM.' AND value LIKE "'.$prefix.'P%"');
    }
        
    my $log_file           = "$dbname\n====\n";
    my %h_written          = ();
    my %h_protein_count    = ();
    my $count              = 0;
    my $write_count        = 0;
    my $transcript_adaptor = $target_db->get_TranscriptAdaptor;
    my $attribute_adaptor  = $target_db->get_AttributeAdaptor;
    my $gene_adaptor       = $target_db->get_GeneAdaptor;

    print STDERR 'prefix: ', $prefix, "\n";
    my $sth = $target_db->dbc->prepare('SELECT distinct(hit_name) FROM protein_align_feature WHERE hit_name LIKE "'.$prefix.'P%"');
    $sth->execute;
    while( my $hit_name = $sth->fetchrow) {
        if (!exists $h_human_stable_ids{$hit_name}) {
            foreach my $transcript (@{$transcript_adaptor->fetch_all_by_transcript_supporting_evidence($hit_name,'protein_align_feature')}) {
                next unless ($gene_adaptor->fetch_by_transcript_id($transcript->dbID)->biotype eq 'protein_coding');
                ++$count;
                if (defined $write) {
                    if ($overwrite or !check_if_exists($attribute_adaptor->fetch_all_by_Transcript($transcript, &ATTRIB_CODE), $hit_name)) {
                        my $lowcoverage_attrib = Bio::EnsEMBL::Attribute->new (
                            -CODE        => &ATTRIB_CODE,
                            -NAME        => &ATTRIB_NAME,
                            -DESCRIPTION => &ATTRIB_DESC,
                            -VALUE       => $hit_name
                            );
                        ++$write_count;
                        $attribute_adaptor->store_on_Transcript($transcript, [$lowcoverage_attrib]); 
                        $h_written{$hit_name.$transcript->dbID} = 1;
                    }
                    $h_protein_count{$hit_name} = 1;
                }
                $log_file .= "T\t".$transcript->display_id."\t".$hit_name."\n";
            }
            foreach my $transcript (@{$transcript_adaptor->fetch_all_by_exon_supporting_evidence($hit_name,'protein_align_feature')}) {
                next unless ($gene_adaptor->fetch_by_transcript_id($transcript->dbID)->biotype eq 'protein_coding');
                ++$count;
                next if exists $h_written{$hit_name.$transcript->dbID};
                if (defined $write) {
                    if ($overwrite or !check_if_exists($attribute_adaptor->fetch_all_by_Transcript($transcript, &ATTRIB_CODE), $hit_name)) {
                        my $lowcoverage_attrib = Bio::EnsEMBL::Attribute->new (
                            -CODE        => &ATTRIB_CODE,
                            -NAME        => &ATTRIB_NAME,
                            -DESCRIPTION => &ATTRIB_DESC,
                            -VALUE       => $hit_name
                            );
                        ++$write_count;
                        $attribute_adaptor->store_on_Transcript($transcript, [$lowcoverage_attrib]); 
                        $h_written{$hit_name.$transcript->dbID} = 1;
                    }
                    $h_protein_count{$hit_name} = 1;
                }
                $log_file .= "E\t".$transcript->display_id."\t".$hit_name."\n";
            }
        }
    }

    if (defined $write) {
        if (defined $ensemblflagging) {
            $meta_adaptor->update_key_value(&META_KEY, $dbname_human);
        }
        else {
            $meta_adaptor->store_key_value(&META_KEY, $dbname_human);
        }
    }


# Statistics
    my $stats = "\n\n";
    $stats .= $count." protein evidences that should be shown as removed\n";
    $stats .= (scalar(keys %h_protein_count)).' protein that do not exist in '.$dbname_human."\n";
    $stats .= $write_count." entries written.\n" if defined $write;

# Write log file or print to the screen
    if ($log_file_name) {
        open WLF, ">>$log_file_name" || die('Could not write the log file for the curation of '.$dbname);
        print WLF $log_file.$stats;
        close (WLF);
    }
    else {
        print STDOUT $log_file;
    }
}

## Subs ##
sub check_if_exists {
    my ($ra_attributes, $hit_name) = @_;

    foreach my $attribute (@{$ra_attributes}) {
        return 1 if ($attribute->value eq $hit_name);
    }
    return 0;
}

sub Usage {
    print <<EOF
 $0 --host <host name> --dbname_ref <DB name> [--dblist <DB name>] [--write] [--dbhost_ref <host name for the human db>] [--dbport_ref <port number for the human db>] [--dbuser_ref <user name for the human db>] [--port <int>] [--user <user name>] [--pass <passwd>] [--log_file <path to file>] [--parallel]
        
        Mandatory
            --host       Name of the host of the target database
            --dbname_ref Name of the human database

        Optionnal
            --write      Write the attributes in the translation_attrib and transcription_attrib tables
            --dblist     Comma separated list of databases
            --dbhost_ref Host of the human database
            --dbport_ref Port number of the human database
            --log_file   Name of the log file, all human protein name with their linked element
                          would be written here
            --port       Port number, default 3306
            --user       User name, must be an admin.
            --pass       Password, default password...
            --parallel  Run one job per database
EOF
}
