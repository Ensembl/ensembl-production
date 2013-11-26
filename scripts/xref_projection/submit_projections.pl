# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

use Data::Dumper;
use Getopt::Long;
use Bio::EnsEMBL::ApiVersion qw/software_version/;

$Data::Dumper::Useqq  = 1;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;

# Submits the display name and GO term projections as farm jobs
# Remember to check/set the various config optons

# ------------------------------ config -------------------------------
my $release = software_version();

my $host;
my $user = 'ensro';
my $pass;
my $port = 3306;
my $host1 = 'ens-staging';
my $user1 = 'ensro';
my $pass1;
my $port1 = 3306;
my $host2 = 'ens-staging2';
my $user2;
my $pass2;
my $port2 = 3306;
my $compara_host = 'ens-livemirror';
my $compara_user = 'ensro';
my $compara_pass;
my $compara_port = 3306;
my $compara_dbname;

my ($conf, $base_dir);

GetOptions('conf=s'            => \$conf,
           'release=s'         => \$release,
           'host=s'            => \$host,
           'user=s'            => \$user,
           'pass=s'            => \$pass,
           'port=s'            => \$port,
           'host1=s'           => \$host1,
           'user1=s'           => \$user1,
           'pass1=s'           => \$pass1,
           'port1=s'           => \$port1,
           'host2=s'           => \$host2,
           'user2=s'           => \$user2,
           'pass2=s'           => \$pass2,
           'port2=s'           => \$port2,
           'compara_host=s'    => \$compara_host,
           'compara_user=s'    => \$compara_user,
           'compara_pass=s'    => \$compara_pass,
           'compara_port=s'    => \$compara_port,
           'compara_dbname=s'  => \$compara_dbname,
           'base_dir=s'        => \$base_dir,
           'help'              => sub { usage(); exit(0); });

if (!$conf) { $conf = "release_${release}.ini"; } # registry config file, specifies Compara location
if (!$user2) { $user2 = $user1; }
if (!$pass2 && $pass1 && $user1 == $user2) { $pass2 = $pass1; }



# -------------------------- end of config ----------------------------

# check that base directory exists
die ("Cannot find base directory $base_dir") if (! -e $base_dir);

# create release subdir if necessary
my $dir = $base_dir. $release;
if (! -e $dir) {
  mkdir $dir;
  print "Created $dir\n";
} else {
  print "Cleaning and re-using $dir\n";
  unlink <$dir/*.out>, <$dir/*.err>, <$dir/*.sql.gz>;
}

# common options
my $script_opts =
    "-conf '$conf' "
  . "-release '$release' "
  . "-quiet -backup_dir '$dir'";

$script_opts .= "-host1 $host " if $host;
$script_opts .= "-user1 $user " if $user;
$script_opts .= "-pass1 $pass " if $pass;
$script_opts .= "-port1 $port " if $port;
$script_opts .= "-host1 $host1 " if $host1;
$script_opts .= "-user1 $user1 " if $user1;
$script_opts .= "-pass1 $pass1 " if $pass1;
$script_opts .= "-port1 $port1 " if $port1;
$script_opts .= "-host2 $host2 " if $host2;
$script_opts .= "-user2 $user2 " if $user2;
$script_opts .= "-pass2 $pass2 " if $pass2;
$script_opts .= "-port2 $port2 " if $port2;
$script_opts .= "-compara_host $compara_host " if $compara_host;
$script_opts .= "-compara_user $compara_user " if $compara_user;
$script_opts .= "-compara_pass $compara_pass " if $compara_pass;
$script_opts .= "-compara_port $compara_port " if $compara_port;


my $bsub_opts = "";
$bsub_opts .= "-M2000 -R'select[mem>2000] rusage[mem=2000]'";

my %names_1_1;

######
# When editing xref projection lists below, remember to check the
# species is in the execution order array that follows.
######
$names_1_1{'human'} =  [qw(
    alpaca
    anolis
    armadillo
    bushbaby
    cat
    chicken
    chimp
    coelacanth
    cow
    dog
    dolphin
    duck
    elephant
    flycatcher
    gibbon
    gorilla
    ground_shrew
    guinea_pig
    horse
    hyrax
    macaque
    marmoset
    megabat
    microbat
    mouse_lemur
    mustela_putorius_furo
    opossum
    orang_utan
    panda
    pig
    pika
    platypus
    psinensis
    rabbit
    sheep
    sloth
    squirrel
    tarsier
    tasmanian_devil
    tenrec
    tree_shrew
    turkey
    wallaby
    western_european_hedgehog
    xenopus
    zebrafinch
    )];

$names_1_1{'mouse'} = [qw(
    kangaroo_rat
    mustela_putorius_furo
    rat
)];

my %names_1_many;
$names_1_many{'zebrafish'} = [qw(
    astyanax_mexicanus
    cod
    fugu
    lamprey
    lepisosteus_oculatus
    medaka
    stickleback
    tetraodon
    tilapia
    coelacanth
    xiphophorus_maculatus
)];

$names_1_many{'human'} = [qw(
    astyanax_mexicanus
    cod
    fugu
    lamprey
    lepisosteus_oculatus
    medaka
    stickleback
    tetraodon
    tilapia
    xiphophorus_maculatus
    zebrafish
)];

my %go_terms;
$go_terms{'human'} = [qw(
    alpaca
    anolis
    armadillo
    bushbaby
    cat
    chicken
    chimp
    cow
    dog
    dolphin
    duck
    elephant
    flycatcher
    gibbon
    gorilla
    ground_shrew
    guinea_pig
    horse
    hyrax
    kangaroo_rat
    macaque
    marmoset
    megabat
    microbat
    mouse
    mouse_lemur
    mustela_putorius_furo
    opossum
    orang_utan
    panda
    pig
    pika
    platypus
    psinensis
    rabbit
    rat
    sheep
    sloth
    squirrel
    tarsier
    tasmanian_devil
    tenrec
    tree_shrew
    turkey
    wallaby
    western_european_hedgehog
    zebrafinch
)];
$go_terms{'mouse'} = [qw(
    alpaca
    anolis
    armadillo
    bushbaby
    cat
    chicken
    chimp
    cow
    dog
    dolphin
    duck
    elephant
    flycatcher
    gorilla
    ground_shrew
    guinea_pig
    horse
    human
    hyrax
    kangaroo_rat
    macaque
    marmoset
    megabat
    microbat
    mouse_lemur
    mustela_putorius_furo
    opossum
    orang_utan
    panda
    pig
    pika
    platypus
    psinensis
    rabbit
    rat
    sheep
    sloth
    squirrel
    tarsier
    tasmanian_devil
    tenrec
    tree_shrew
    turkey
    wallaby
    western_european_hedgehog
    zebrafinch
)];
$go_terms{'rat'} = [qw(
    human
    mouse
)];
$go_terms{'zebrafish'} = [qw(
    astyanax_mexicanus
    cod
    coelacanth
    fugu
    lamprey
    lepisosteus_oculatus
    stickleback
    tetraodon
    tilapia
    xenopus
    xiphophorus_maculatus
)];
$go_terms{'xenopus'} = [qw(zebrafish)];

# order to run projections in, just in case they are order-sensitive.
my @execution_order = qw/human mouse rat zebrafish xenopus/;
# except of course order is irrelevant to the job queue. See the -w
# command below in the bsub command to cause serial execution.
my @many_execution_order = qw/zebrafish human/;


# ----------------------------------------
# Display names

print "Deleting projected names (one to one)\n";
foreach my $species (keys %names_1_1) {
    foreach my $to (@{$names_1_1{$species}}) {
        system "perl project_display_xrefs.pl $script_opts "
             . "-to $to -delete_names -delete_only\n";
    };
}

# 1:1

my $last_name; # for waiting in queue

foreach my $from (@execution_order) {
    if (not exists($names_1_1{$from})) {next;}
    foreach my $to (@{$names_1_1{$from}}) {
        my $o = "$dir/names_${from}_$to.out";
        my $e = "$dir/names_${from}_$to.err";
        my $n = substr("n_${from}_$to", 0, 10); # job name display limited to 10 chars
        my $all;
        if ($from eq "human" || $from eq "mouse") { $all = "" ; }
        else { $all = "--all_sources"; }
        my $wait;
        if ($last_name) { $wait = "-w 'ended(${last_name}*)'";}
        print "Submitting name projection from $from to $to\n";
        system "bsub $bsub_opts -o $o -e $e -J $n $wait "
             . "perl project_display_xrefs.pl $script_opts "
             . "-from $from -to $to -names -no_database $all\n";
    }
    $last_name = substr("n_".$from, 0 ,10);
}
$last_name = "";

print "Deleting projected names (one to many)\n";
foreach my $from (keys %names_1_many) {
    foreach my $to (@{$names_1_many{$from}}) {
        system "perl project_display_xrefs.pl $script_opts "
             . "-to $to -delete_names -delete_only\n";
    }
}

# 1:many
foreach my $from (@many_execution_order) {
    if (not exists($names_1_many{$from})) {next;}
    foreach my $to ( @{ $names_1_many{$from} } ) {
      my $o = "$dir/names_${from}_$to.out";
      my $e = "$dir/names_${from}_$to.err";
      my $n = substr( "n_${from}_$to", 0, 10 );

      my $wait;
      if ($last_name) { $wait = "-w 'ended(${last_name}*)'"; }

      print "Submitting name projection from $from to $to (1:many)\n";
      system "bsub $bsub_opts -o $o -e $e -J $n $wait "
           . "perl project_display_xrefs.pl $script_opts "
           . "-from $from -to $to -names -no_database -one_to_many\n";
    }
    $last_name = substr("n_".$from, 0 ,10);
}

$last_name = "";

# ----------------------------------------
# GO terms

$script_opts .= " -nobackup";

print "Deleting projected GO terms\n";
foreach my $from (keys %go_terms) {
    foreach my $to (@{$go_terms{$from}}) {
        system "perl project_display_xrefs.pl $script_opts "
             . "-to $to -delete_go_terms -delete_only\n";
    }
}



foreach my $from (@execution_order) {
    if (not exists($go_terms{$from})) {next;}
    foreach my $to ( @{ $go_terms{$from} } ) {
      my $o = "$dir/go_${from}_$to.out";
      my $e = "$dir/go_${from}_$to.err";
      my $n = substr( "g_${from}_$to", 0, 10 );

      my $wait;
      if ($last_name) { $wait = "-w 'ended(${last_name}*)'"; }

      print "Submitting GO term projection from $from to $to\n";
      system "bsub $bsub_opts -q long -o $o -e $e -J $n $wait "
           . "perl project_display_xrefs.pl $script_opts "
           . "-from $from -to $to -go_terms\n";
    }
    $last_name = substr("g_".$from, 0 ,10);
}
# ----------------------------------------
