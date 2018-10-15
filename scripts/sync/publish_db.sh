#!/bin/sh

db=$1
if [ -z "$db" ]; then
    echo "Usage: $0 <dbname>" 1>&2;
    exit 1;
fi
sql='grant select, show view on `'$db'`.* to `anonymous`@`%`';
echo "database: " $db
echo "sql: " $sql
admin-mysql-eg-publicsql -e "$sql"
sql2='grant select, show view on `'$db'`.* to `ensro`@`%.ebi.ac.uk`';
echo "sql: " $sql2
admin-mysql-eg-publicsql -e "$sql2"
