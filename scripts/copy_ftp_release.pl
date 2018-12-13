#!/bin/env perl
use warnings;
use strict;
use File::Find;
use File::Basename;
use File::Path;
use File::Copy;
use PerlIO::gzip;
use Getopt::Long;
use Pod::Usage;
use Log::Log4perl qw/:easy/;


my $opts = {};
my @flags = qw(
    src_dir=s tgt_dir=s old_rel=s new_rel=s old_ens=s new_ens=s verbose
  );
GetOptions($opts, @flags) or pod2usage(1);

if ($opts->{verbose}) {
    Log::Log4perl->easy_init($DEBUG);
} else {
    Log::Log4perl->easy_init($INFO);
}

my $log = get_logger();

my $old_rel = $opts->{old_rel} or pod2usage(1);
my $new_rel = $opts->{new_rel};
$new_rel ||= $old_rel+1;

my $old_ens_rel = $opts->{old_ens} or pod2usage(1);
my $new_ens_rel = $opts->{new_ens};
$new_ens_rel ||= $old_ens_rel+1;

my $src_dir = $opts->{src_dir};
my $target_dir = $opts->{tgt_dir};
my $src_len = length($src_dir);

$log->info("Copying $src_dir to $target_dir");
$log->info("EG $old_rel -> $new_rel, Ensembl $old_ens_rel -> $new_ens_rel");

sub rename_file {
    my $file = shift;
    my $newfile = $target_dir.substr($file,$src_len);
    mkpath(dirname($newfile));
    return $newfile;
}

my $gzip_files = [
    qr/.*\.(${old_rel})\..*\.fa\.gz/,
    qr/.*\.(${old_rel})\..*\.gff3\.gz/,
    qr/.*\.(${old_rel})\.gtf\.gz/,
    qr/.*\.(${old_rel})\.emf\.gz/,
    qr/.*\.(${old_rel})\.[a-z]+\.tsv\.gz/,
    qr/.*\.(${old_rel})\.dat\.gz/,
    qr/.*\.gz/
];

sub process_file {
    my $file = $File::Find::name;
    # skip if mysql
    return if -d $file || -l $file;
    return if $file =~ m/mysql/ || $file =~ /CHECKSUMS/;
    $log->info("Processing $file");
    if($file=~m/\.vcf\.gz/ || $file =~ m/\.gvf\.gz/) {	
	my $newfile = rename_file($file);
	$log->debug("VCF: $file -> $newfile");
	# read and replace header
	open my $in, "<:gzip", $file or die $!;
	open my $out, ">:gzip", $newfile or die $!;
	while(<$in>) {
	    s/version=${old_ens_rel}/version=${new_ens_rel}/;
	    s/e${old_ens_rel}/e${new_ens_rel}/;
	    print $out $_;
	}
	close $in;
	close $out;
    } elsif($file=~m/Compara\..*_trees\.([0-9]+)\.tar\.gz/) {
	my $newfile = rename_file(substr($file,0,$-[1]).$new_rel.substr($file,$+[1]));	
	my $newtar = basename($newfile);
	my $newdir = dirname($newfile);
	my $oldtar = basename($file);
	$oldtar =~ s/.tar.gz$//;
	$newtar =~ s/.tar.gz$//;
	my $com = "cd $newdir; tar xvzf $file; mv $oldtar $newtar; tar cvzf ${newtar}.tar.gz $newtar; rm -rf $newtar; cd -";
	$log->debug("Compara: ".$com);
	`$com`;
	} elsif($file=~m/Compara\.([0-9]+)\..*\.gz/) {
		my $newfile = rename_file(substr($file,0,$-[1]).${new_ens_rel}.substr($file,$+[1]));
		my $newdir = dirname($newfile);
		my $com = "cd $newdir; cp $file $newfile";
		$log->debug("Compara: ".$com);
		`$com`;
    } elsif($file=~m/_vep_([0-9]+)_.*\.tar\.gz/) {
	my $newfile = rename_file(substr($file,0,$-[1]).$new_rel.substr($file,$+[1]));	
	my $newtar = basename($newfile);
	my $newdir = dirname($newfile);
	my $oldtar = basename($file);
	$oldtar =~ s/.tar.gz$//;
	$newtar =~ s/.tar.gz$//;
	my $subdir = $oldtar;
	$subdir =~ s/(.*)_vep.*/$1/;
	# unpack old directory and rename
	my $com = "cd $newdir; tar xvzf $file";
	$log->debug("VEP: ".$com);
	`$com`;
	# rename subdirs
	$com = "cd $newdir/$subdir; for file in ${old_rel}_*; do newfile=\${file/$old_rel/$new_rel}; mv \$file \$newfile; done";
	$log->debug($com);
	`$com`;		
	# repack
	$com = "cd $newdir; tar cvzf ${newtar}.tar.gz $subdir; rm -rf $subdir; cd -";
	$log->debug($com);
	`$com`;	
    } elsif($file=~m/.gz$/) {
	for my $regexp (@$gzip_files) {
	    if($file =~ $regexp) {
                if(defined $1) {
                    my $newfile = substr($file,0,$-[1]).$new_rel.substr($file,$+[1]);
                    $newfile = rename_file($newfile);
                    $log->debug("CP rel.gz: $file -> $newfile");
                    copy($file,$newfile);
                } else {
                    my $newfile = rename_file($file);
                    $log->debug("CP gz: $file -> $newfile");
                    copy($file,$newfile);
                }
                last;
	    }
	}
    } else {
	my $newfile = rename_file($file);
	$log->debug("$file -> $newfile");
	copy($file,$newfile);
    }
    return;
}
find(\&process_file,  $src_dir);
