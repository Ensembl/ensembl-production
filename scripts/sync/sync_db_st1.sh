i#!/bin/sh

db=$1
method=$2
if [ -z "$method" ]; then
    method="--checksum"
fi
if [[ "$db" =~ .*_mart_.* ]]; then
    echo "Syncing $db from st1 to mart"
    sync_db.sh -s admin-mysql-staging-1 -t admin-mysql-mart -d $db -f -- $method || {
        echo "Could not sync $db from st1 to mart" 1>&2
        exit 1;
    }
else
    echo "Syncing $db from st1 to live"
    sync_db.sh -s admin-mysql-staging-1 -t admin-mysql-rel -d $db -f -- $method || {
        echo "Could not sync $db from st1 to live" 1>&2
        exit 1;
    }
    echo "Syncing $db from st1 to rest"
    sync_db.sh -s admin-mysql-staging-1 -t admin-mysql-rest -d $db -f -- $method --no-dump || {
        echo "Could not sync $db from st1 to rest" 1>&2
        exit 1;
    }
#    echo "Syncing $db from st1 to st1-ro"
#    sync_db.sh -s admin-mysql-staging-1 -t admin-mysql-staging-1-ro -d $db -f -- $method --no-dump || {
#        echo "Could not sync $db from st1 to st1-ro" 1>&2
#        exit 1;
#    }
fi
#echo "Syncing $db from st1 to mirror"
#sync_db.sh -s admin-mysql-staging-1 -t admin-mysql-eg-mirror -d $db -- $method --no-dump || {
#    echo "Could not sync $db from st1 to mirror" 1>&2
#    exit 1;
#}

