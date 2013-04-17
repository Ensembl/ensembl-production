use strict;

use Data::Dumper;
use Bio::EnsEMBL::ApiVersion qw/software_version/;

$Data::Dumper::Useqq=1;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 0;

# Submits the display name and GO term projections as farm jobs
# Remember to check/set the various config optons

# ------------------------------ config -------------------------------
my $release = software_version();


my $base_dir = "/lustre/scratch109/ensembl/tm6/projections_run2";

my $conf = "release_${release}.ini"; # registry config file, specifies Compara location

# location of other databases

my @config = ( {
    '-host'       => 'ens-staging1',
    '-port'       => '3306',
    '-user'       => 'ensadmin',
    '-pass'       => 'ensembl',
    '-db_version' => $release
  },
  {
    '-host'       => 'ens-staging2',
    '-port'       => '3306',
    '-user'       => 'ensadmin',
    '-pass'       => 'ensembl',
    '-db_version' => $release
  } );

my $registryconf = Dumper(\@config);

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
my $script_opts = "-conf '$conf' -registryconf '$registryconf' -version '$release' -release '$release' -quiet -backup_dir '$dir'";

my $bsub_opts = "";
$bsub_opts .= "-M2000000 -R'select[mem>2000] rusage[mem=2000]'";

my %names_1_1;

######
# When editing xref projection lists below, remember to check the species is in 
# the execution order array that follows.
######
$names_1_1{'human'} =  [qw(
    pig
    )];

my %go_terms;
$go_terms{'human'} = [qw(  
    pig

)];
$go_terms{'mouse'} = [qw(
    pig
)];

# order to run projections in, just in case they are order-sensitive.
my @execution_order = qw/human mouse rat zebrafish xenopus/;
# except of course order is irrelevant to the job queue. See the -w command below
# in the bsub command to cause serial execution.


# ----------------------------------------
# Display names

print "Deleting projected names (one to one)\n";
foreach my $species (keys %names_1_1) {
    foreach my $to (@{$names_1_1{$species}}) {
        system "perl project_display_xrefs.pl $script_opts -to $to -delete_names -delete_only\n";
    };
}

# 1:1

my $last_name; # for waiting in queue

foreach my $from (@execution_order) {
    my $last_name; # for waiting in queue
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
        system "bsub $bsub_opts -o $o -e $e -J $n $wait perl project_display_xrefs.pl $script_opts -from $from -to $to -names -no_database $all\n";
    }
    $last_name = substr("n_".$from, 0 ,10);
}
$last_name = "";

<<<<<<< submit_projections.pl
=======
print "Deleting projected names (one to many)\n";
foreach my $from (keys %names_1_many) {
    foreach my $to (@{$names_1_many{$from}}) {
        system "perl project_display_xrefs.pl $script_opts -to $to -delete_names -delete_only\n";
    }
}

# 1:many
foreach my $from (@execution_order) {
    if (not exists($names_1_many{$from})) {next;}
    foreach my $to (@{$names_1_many{$from}}) {
        my $o = "$dir/names_${from}_$to.out";        
        my $e = "$dir/names_${from}_$to.err";
        my $n = substr("n_${from}_$to", 0, 10);
        
        my $wait;
        if ($last_name) { $wait = "-w 'ended(${last_name}*)'";}
        
        print "Submitting name projection from $from to $to (1:many)\n";
        system "bsub $bsub_opts -o $o -e $e -J $n $wait perl project_display_xrefs.pl $script_opts -from $from -to $to -names -no_database -one_to_many\n";
    }
    $last_name = substr("n_".$from, 0 ,10);
}

$last_name = "";
>>>>>>> 1.69

# ----------------------------------------
# GO terms

$script_opts .= " -nobackup";

print "Deleting projected GO terms\n";
foreach my $from (keys %go_terms) {
    foreach my $to (@{$go_terms{$from}}) {
        system "perl project_display_xrefs.pl $script_opts -to $to -delete_go_terms -delete_only\n";
    }
}



foreach my $from (@execution_order) {
    if (not exists($go_terms{$from})) {next;}
    foreach my $to (@{$go_terms{$from}}) {
        my $o = "$dir/go_${from}_$to.out";
        my $e = "$dir/go_${from}_$to.err";
        my $n = substr("g_${from}_$to", 0, 10);
        
        my $wait;
        if ($last_name) { $wait = "-w 'ended(${last_name}*)'";}
        
        print "Submitting GO term projection from $from to $to\n";
        system "bsub $bsub_opts -q long -o $o -e $e -J $n $wait perl project_display_xrefs.pl $script_opts -from $from -to $to -go_terms\n";
    }
    $last_name = substr("g_".$from, 0 ,10);
     
}


# ----------------------------------------



