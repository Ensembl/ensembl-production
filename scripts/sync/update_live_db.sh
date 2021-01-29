#!/bin/bash --
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
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

