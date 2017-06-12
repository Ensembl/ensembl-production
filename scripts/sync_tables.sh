#!/bin/bash

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
    src_chk=$($srv --column-name=false $src -e "checksum table $table")
    tgt_chk=$($srv --column-name=false $tgt -e "checksum table $table")
    if [ "$src_chk" != "$tgt_chk" ]; then
        echo "Running sync $src $table -> $tgt $table"
        $srv mysqldump $src $table | $srv $tgt
    fi
done