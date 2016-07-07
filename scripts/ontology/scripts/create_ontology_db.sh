#!/bin/bash --

function msg {
    d=$(date +"[%Y/%m/%d %H:%M:%S]")
    echo "$d $@"
}

srv=$1
dbname=$2
dir=$3
mart=$4

if [ -z "$srv" ] || [ -z "$dbname" ] || [ -z "$dir" ]; then
    echo "Usage: $0 <mysql_server> <dbname> <obo_dir>" 1>&2
    exit 1
fi

if [ -z "$BASE_DIR" ] || ! [ -e "$BASE_DIR" ]; then
    echo "BASE_DIR must be set and exists" 1>&2
    exit 2
fi

if ! [ -d "$dir" ]; then
    echo "Cannot find obo directory $dir" 1>&2
    exit 3
fi

msg "Creating $srv:$dbname"
$srv -e "drop database if exists $dbname"
$srv -e "create database $dbname"
$srv $dbname< $BASE_DIR/ensembl/misc-scripts/ontology/sql/tables.sql

cd $dir
msg "Reading OBO files from $dir"
for file in *.obo; do 
    ontology=${file/.obo/}
    msg "Loading $file as $ontology"
    perl $BASE_DIR/ensembl-production/scripts/ontology/scripts/load_OBO_file.pl $($srv details script) --name $dbname --file $file --ontology $ontology    
done
cd -

msg "Computing closures"
perl $BASE_DIR/ensembl-production/scripts/ontology/scripts/compute_closure.pl $($srv details script) --name $dbname --config $BASE_DIR/ensembl-production/scripts/ontology/scripts/closure_config.ini
msg "Adding subset maps"
perl $BASE_DIR/ensembl-production/scripts/ontology/scripts/add_subset_maps.pl $($srv details script) --name $dbname
msg "Building database $dbname complete"

if ! [ -z "$mart" ]; then
    msg "Creating mart $srv:$mart"
    $srv -e "drop database if exists $mart"
    $srv -e "create database $mart"   
    msg "Building mart database $mart"
    TMP_SQL=/tmp/mart.sql
    sed -e "s/%MART_NAME%/$mart/g" build_ontology_mart.sql | sed -e "s/%ONTOLOGY_DB%/$dbname/g" > $TMP_SQL
    $srv $mart < $TMP_SQL
    #rm -f $TMP_SQL
    msg "Cleaning excess rows in $mart"
    for table in $($srv $mart -e "show tables like \"closure%\""); do
	msg "Cleaning excess rows in $mart $table"
	$srv $mart -e "delete from $table where name_302 is null";
	cnt=$($srv $mart -e "select count(*) from $table")
	if [ "$cnt" == "0" ]; then
	    msg "Dropping table $table from $mart"
	    $srv $mart -e "drop table $table";
	else 
	    msg "Optimizing table $table on $mart"
	    $srv $mart -e "optimize table $table";
	fi
    done

    msg "Populating meta tables for mart database $mart"
    $srv $mart < build_ontology_mart_meta.sql
    msg "Building mart database $mart complete"
fi 
