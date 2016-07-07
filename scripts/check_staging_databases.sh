#!/bin/bash --

function msg {
    echo "[ $(date +'%Y-%m-%d %H:%m:%S') ] : $@"
}

base_dir=$(dirname $0)/../../

staging_srv=$1
production_srv=$2

msg "Patching $staging_srv"

# apply patches
for db_type in core variation funcgen compara; do 
    msg "Patching $db_type databases on $production_srv"
    perl $base_dir/ensembl/misc-scripts/schema_patcher.pl $($staging_srv details script) --gitdir $base_dir --type $db_type --fixlast || {
        msg "Failed to patch type $db_type"
        exit 1
    }
done

# sync to production
msg "Updating core tables on $staging_srv from $production_srv"
perl $base_dir/ensembl-production/scripts/production_database/update_controlled_tables.pl $($staging_srv details script) $($production_srv details script_m) -mdbname ensembl_production -dbpattern .*_core_.* -no_backup  || {
    msg "Failed to update cores"
    exit 2
}

msg "Updating variation tables on $staging_srv from $production_srv"
perl $base_dir/ensembl-production/scripts/production_database/update_controlled_tables.pl $($staging_srv details script) $($production_srv details script_m) -mdbname ensembl_production -dbpattern .*_variation_.* -no_backup   || {
    msg "Failed to update cores"
    exit 3
}

msg "Completed update of $staging_srv"
