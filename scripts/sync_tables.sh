#!/bin/bash
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
# limitations under the License

srv=$1
shift
src=$1
shift
tgt=$1
shift

if [ -z "$srv" ] || [ -z "$tgt" ] || [ -z "$src" ]; then
    echo "Usage: $0 <srv> <src_db> <tgt_db> [table_1, table_2...table_n]" 1>&2
    exit 1
fi

for table in $@; do 
    echo "Comparing $src.$table to $tgt.$table on $srv"
    src_chk=$($srv --column-names=false $src -e "checksum table $table" | cut -f 2)
    tgt_chk=$($srv --column-names=false $tgt -e "checksum table $table" | cut -f 2)
    if [ "$src_chk" != "$tgt_chk" ]; then
        echo "Running sync $src $table -> $tgt $table"
        $srv mysqldump $src $table | $srv $tgt
    fi
done
