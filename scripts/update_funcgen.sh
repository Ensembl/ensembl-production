#!/bin/bash

SRV=$1

cd $BASE_DIR/ensembl-funcgen
$SRV -e "show databases" | grep funcgen | grep -v master_schema | while read db; do
    echo "Checking $db";
    schema_build=$(echo $db | sed -e 's/.*_\([0-9]*_[0-9]*\)$/\1/')
    cnt=$($SRV --column-names=false $db -e "select count(*) from seq_region where schema_build<>\"$schema_build\"")
    echo "$schema_build = $cnt"
    if [ "$cnt" == "0" ]; then
	echo "Updating funcgen database"
	perl -I modules ./scripts/release/update_DB_for_release.pl $($SRV details script) $($SRV details script_dnadb_) -dbname $db -check_displayable -skip_analyse -skip_xref_cleanup
    fi
done
