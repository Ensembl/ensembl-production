#!/bin/bash

srv=$1
file=$(mktemp)
$srv --column-names=false -e "show databases" > $file
for db_type in otherfeatures cdna rnaseq; do
    echo "Looking for $db_type dbs"
    for db in $(grep $db_type $file); do 
        core=${db/$db_type/core}
        echo "Syncing assembly from $core to $db"
        ./sync_tables.sh $srv $core $db assembly assembly_exception coord_system seq_region seq_region_synonym seq_region_attrib karyotype mapping_set seq_region_mapping
    done
done
rm -f $file