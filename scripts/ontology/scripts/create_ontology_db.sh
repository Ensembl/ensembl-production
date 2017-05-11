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

#List order in which the ontologies need to be loaded
declare -a orders;
orders+=( "GO.obo" )
orders+=( "SO.obo" )
orders+=( "PATO.obo" )
orders+=( "HPO.obo")
orders+=( "EFO.obo" )
orders+=( "PO.obo" )
orders+=( "GR_TAX.obo" )
orders+=( "GRO.obo" )
orders+=( "EO.obo" )
orders+=( "TO.obo" )
orders+=( "chEBI.obo" )
orders+=( "PBO.obo" )
orders+=( "MBO.obo" )
orders+=( "MOD.obo" )
orders+=( "FYPO.obo" )
orders+=( "PECO.obo" )
orders+=( "PR.obo" )

msg "Reading OBO files from $dir"
#Getting list of obo files from $dir
list_obo_files=($(find *.obo -type f))
#Removing obo files already defined in order array
for obo in ${orders[@]}; do
  list_obo_files=("${list_obo_files[@]/#$obo}")
done

#Add remaining obo files to main orders array
orders+=("${list_obo_files[@]}")


for file in ${orders[@]}; do
  if test -f $file; then
    ontology=${file/.obo/}
    msg "Loading $file as $ontology"
    perl $BASE_DIR/ensembl-production/scripts/ontology/scripts/load_OBO_file.pl $($srv details script) --name $dbname --file $file --ontology $ontology || {
        msg "Failed to load OBO file $file"
        exit 1
    }
  else
    msg "$file not found"
  fi
done
cd -
msg "Delete unknown ontology"
perl $BASE_DIR/ensembl-production/scripts/ontology/scripts/load_OBO_file.pl $($srv details script) --name $dbname -delete_unknown || {
        msg "Failed to remove unknown ontology"
        exit 1
    }
msg "Computing closures"
perl $BASE_DIR/ensembl-production/scripts/ontology/scripts/compute_closure.pl $($srv details script) --name $dbname --config $BASE_DIR/ensembl-production/scripts/ontology/scripts/closure_config.ini || {
        msg "Failed to compute closure"
        exit 1
    }
msg "Adding subset maps"
perl $BASE_DIR/ensembl-production/scripts/ontology/scripts/add_subset_maps.pl $($srv details script) --name $dbname || {
        msg "Failed to add subset maps"
        exit 1
    }
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
    msg "Cleaning up and optimizing tables in $mart"
    for table in $($srv --skip-column-names $mart -e "show tables like \"closure%\""); do
	cnt=$($srv $mart -e "select count(*) from $table")
	if [ "$cnt" == "0" ]; then
	    msg "Dropping table $table from $mart"
	    $srv $mart -e "drop table $table";
	else 
	    msg "Optimizing table $table on $mart"
	    $srv $mart -e "optimize table $table";
	fi
    done
    msg "Creating the dataset_name table for mart database $mart"
    perl $BASE_DIR/ensembl-biomart/scripts/generate_names.pl $($srv details script) -mart $mart -div ensembl || {
        msg "Failed to create dataset_name table"
        exit 1
    }
    msg "Populating meta tables for mart database $mart"
    perl $BASE_DIR/ensembl-biomart/scripts/generate_meta.pl $($srv details script) -dbname $mart -template $BASE_DIR/ensembl-biomart/scripts/templates/ontology_template_template.xml -template_name ontology || {
        msg "Failed to populate meta table for mart database $mart"
        exit 1
    }
    msg "Populating meta tables for mart database $mart SO mini template"
    perl $BASE_DIR/ensembl-biomart/scripts/generate_meta.pl $($srv details script) -dbname $mart -template $BASE_DIR/ensembl-biomart/scripts/templates/ontology_mini_template_template.xml -template_name ontology_mini -ds_basename mini || {
        msg "Failed to populate meta table for mart database $mart"
        exit 1
    }
    msg "Populating meta tables for mart database $mart SO regulation template"
    perl $BASE_DIR/ensembl-biomart/scripts/generate_meta.pl $($srv details script) -dbname $mart -template $BASE_DIR/ensembl-biomart/scripts/templates/ontology_regulation_template_template.xml -template_name ontology_regulation -ds_basename regulation || {
        msg "Failed to populate meta table for mart database $mart"
        exit 1
    }
    msg "Populating meta tables for mart database $mart SO motif template"
    perl $BASE_DIR/ensembl-biomart/scripts/generate_meta.pl $($srv details script) -dbname $mart -template $BASE_DIR/ensembl-biomart/scripts/templates/ontology_motif_template_template.xml -template_name ontology_motif -ds_basename motif || {
        msg "Failed to populate meta table for mart database $mart"
        exit 1
    }
    msg "Building mart database $mart complete"
fi 
