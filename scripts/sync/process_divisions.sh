#!/bin/bash
script=$@
for division in $(mysql-pan-1 ensembl_production --column-names=false -e "select shortname from division"); do
    mkdir -p $division
    cd $division
    ../process_division.sh $division $script || {
        echo "Could not process division $division with $script" 1>&2
        exit 1;
    }
    cd ->/dev/null
done
