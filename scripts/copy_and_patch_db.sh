#!/bin/sh

script_dir=$(dirname $0)
src=$1
tgt=$2
db=$3

if [ -z "$src" ] || [ -z "$tgt" ] || [ -z "$db" ]; then
    echo "Usage: $0 <src> <tgt> <db>" 1>&2
    exit 1;
fi

if [ -z "$ENSEMBL_ROOT_DIR" ]; then
    echo "ENSEMBL_ROOT_DIR not set - please set by sourcing the appropriate setup script e.g. /nfs/panda/ensemblgenomes/apis/ensembl/master/setup.sh" 2>&1 
    exit 2;
fi
patcher=$script_dir/apply_patches.pl
if ! [ -e "$patcher" ]; then
    echo "Patcher script $patcher not found" 2>&1
    exit 3;  
fi

echo "Copy/patching $src $db to $tgt $new_db"
new_db=$($script_dir/get_new_db_name.pl $db)
if [ -z "$new_db" ]; then
    echo "Could not find new name for $db" 2>&1 
    exit 4;
fi

echo "Dumping $src $db"
($src mysqldump --max_allowed_packet=512M --lock-tables=false $db | gzip -c > /tmp/$db.sql.gz) || {
    echo "Failed to dump $src $db" 2>&1
    exit 5;
}
echo "Creating $tgt $new_db"
$tgt -e "drop database if exists $new_db" || {
    echo "Failed to drop $tgt $new_db" 2>&1
    exit 6;
}
$tgt -e "create database if not exists $new_db" || {
    echo "Failed to create $tgt $new_db" 2>&1
    exit 6;
}
(zcat /tmp/$db.sql.gz| $tgt $new_db) ||  {
    echo "Failed to load $tgt $new_db" 2>&1
    exit 7;
}
rm -f /tmp/$db.sql.gz

if [[ "$new_db" =~ .*_mart_.* ]]; then
    echo "Skipping patching mart $tgt $new_db"
else
    echo "Patching $tgt $new_db"
    $patcher $($tgt details script) --dbname $new_db --basedir $ENSEMBL_ROOT_DIR || {
        echo "Failed to patch $tgt $new_db" 2>&1
        exit 8;
    }
    if [[ "$new_db" =~ .*_funcgen_* ]]; then
	cd $ENSEMBL_ROOT_DIR/ensembl-funcgen/scripts/release
	species=$(echo $new_db | sed -e 's/\(.*\)_funcgen.*/\1/')
	data_version=$(echo $new_db | sed -e 's/.*_funcgen_\([0-9]*_[0-9]*\)_[0-9]*/\1/')
	perl update_DB_for_release.pl \
	    $($tgt --details script) \
	    $($tgt --details script_dnadb_) \
	    -dbname $new_db \
	    -species $species \
	    -data_version $data_version \
	    -check_displayable
    fi
fi