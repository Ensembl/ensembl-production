#!/bin/bash

srv=$1
file=$(mktemp)
$srv --column-names=false -e "show databases" > $file
for db_type in otherfeatures cdna rnaseq; do
    echo "Looking for $db_type dbs"
    for db in $(grep $db_type $file); do 
        core=${db/$db_type/core}
        echo "Syncing assembly from $core to $db"
        ./sync_tables.sh $srv $core $db seq_region coord_system seq_region_attrib assembly assembly_exception dna
    done
done
rm -f $file
