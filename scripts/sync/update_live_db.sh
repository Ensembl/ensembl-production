#!/bin/bash --
sync=$1
db=$2
if [ -z "$sync" ]; then
    echo "Usage: $O <sync_command> <db> <table1 table2 .. tablen>" 2>&1
    exit 1
fi
shift
shift
ftpdir="./ftp/mysql/$db"
if [ ! -e "$ftpdir" ]; then
    echo "Target mysql FTP directory $ftpdir not found - please link FTP directory to this path" 2>&1
    exit 1
fi
echo "Syncing $db"
$sync $db
echo "Updating live $db";
admin-mysql-rel mysqldump $db $@ > /tmp/$db.sql
#for com in admin-pg-mysql-rel  admin-oy-mysql-rel admin-pg-mysql-rest admin-oy-mysql-rest admin-mysql-publicsql; do

for com in admin-mysql-publicsql; do
    echo "Updating $db on $com"
    $com $db < /tmp/$db.sql
    $com mysqlcheck --optimize --auto-repair $db
done
rm -f /tmp/$db.sql

echo "Building FTP dumps"
prepare_ftp_dump.sh $db $PWD/mysql $@
#echo "Copying FTP dumps"
#become ensemblftp /bin/bash;cp -r ./mysql/$db/* ./ftp/mysql/$db

