#!/bin/bash
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
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
    lftp -e "put -O xref $1; bye" -u enaftp,submit1 ftp-private.ebi.ac.uk
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
