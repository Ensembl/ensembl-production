#!/bin/bash
release=$1
shift
script=$@
for division in $(mysql-eg-pan-prod ensembl_production --column-names=false -e "select shortname from division"); do
    mkdir -p $division
    cd $division
    process_division.sh $division mysql-eg-pan-prod ensembl_production $release $script || {
        echo "Could not process division $division with $script" 1>&2
        exit 1;
    }
    cd ->/dev/null
done
