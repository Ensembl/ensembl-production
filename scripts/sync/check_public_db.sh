#!/bin/sh

db=$1
if [ -z "$db" ]; then
    echo "Usage: $0 <dbname>" 1>&2;
    exit 1;
fi
for srv in mysql-publicsql-anonymous mysql-eg-mirror-anonymous; do
    check_db.sh -s $srv -d $db
done

