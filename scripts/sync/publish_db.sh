#!/bin/sh

db=$1
if [ -z "$db" ]; then
    echo "Usage: $0 <dbname>" 1>&2;
    exit 1;
fi
sql='grant select, show view on `'$db'`.* to `anonymous`@`%`';
echo "database: " $db
echo "sql: " $sql
mysql-publicsql-admin -e "$sql"
mysql-eg-mirror-admin -e "$sql"
