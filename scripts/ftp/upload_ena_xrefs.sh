#!/bin/bash

base_dir=$1

if [ -z "$base_dir" ]; then                                                                                                                                                                                         
    echo "Usage: $0 <path to FTP directory>" 2>&1                                                                                                                                                                                 
    exit 1                                                                                                                                                                                                                                 
fi       

if [ ! -d "$base_dir" ]; then
    echo "Dump directory $base_dir not found" 2>&1
    exit 2
fi 

function upload_file {
    file=$(basename $1)
    dir=$(dirname $1)
    ftp -n -v ftp-private.ebi.ac.uk <<EOF
lcd $dir
user enaftp submit1
prompt
cd xref
binary
put $file
EOF
}

for division in bacteria plants fungi metazoa protists; do

    div_file="ensembl_${division}.tsv"
    echo "Creating $div_file"

    if [ ! -d "$base_dir/$division" ]; then
	echo "Dump directory $base_dir/$division not found" 2>&1
	exit 4
    fi

    rm -f $div_file ${div_file}.gz
    find $base_dir/$division -name "*.ena.tsv.gz" | while read f; do (zcat $f | tail -n +2) >> $div_file; done
    gzip $div_file
    echo "Uploading ${div_file}.gz"
    upload_file ${div_file}.gz
done

pombe_file=$(find $base_dir/fungi/tsv -name "Schizosaccharomyces_pombe*.ena.tsv.gz")
echo "Uploading PomBase file $pombe_file"
upload_file $pombe_file
