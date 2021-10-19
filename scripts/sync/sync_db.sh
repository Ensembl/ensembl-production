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

src=""
tgt=""
db=""
f=""

usage() {
    echo "Usage: $0 -s <src> -t <tgt> -d <db> [-m date|checksum|count]" 1>&2
}


while getopts ":s:t:d:f" opt; do
    case $opt in
        s)
        src=$OPTARG
        ;;
        t)
        tgt=$OPTARG
        ;;
        d)
        db=$OPTARG
        ;;
        f)
        f="1"
        ;;
        d)
        f=1
        ;;
        \?)
        echo "Invalid option: -$OPTARG" >&2
        usage
        exit 1
        ;;
        :)
        echo "Option -$OPTARG requires an argument." >&2
        usage
        exit 1
        ;;
        esac
done
shift $(($OPTIND-1))
if [ -z "$src" ] || [ -z "$tgt" ] || [ -z "$db" ]; then
    usage;
    exit 1;
fi

if $src -e "show databases" | grep -q $db; then
    $tgt -e "create database if not exists $db"  || {
        echo "Could create $db on $tgt" 1>&2
        exit 1;
    }
    mkdir -p $db
    chmod a+rwx $db
    mysqlnaga-sync $($src details naga) $($tgt details naga | sed -e 's/--/--target/g') --database $db $@  || {
        echo "Could not sync $db from $src to $tgt" 1>&2
        exit 1;
    }
    $tgt mysqlcheck --auto-repair -c $db >/dev/null
    $tgt mysqlcheck --optimize $db >/dev/null
    dbfile=$db/$db.sql
    if [ ! -z "$f" ] || [ ! -e "$dbfile" ] || [ $(find $db -name "*.sql" -newer $dbfile | wc -l) -gt 0  ]; then
        $src mysqldump --lock-tables=false -d $db > $db/$db.sql || {
            echo "Could not dump $db SQL from $src" 1>&2
            exit 1;
        }
        $src mysqldump --lock-tables=false --compatible=mysql40 -d $db > $db/$db.sql_40 || {
            echo "Could not dump $db SQL from $src" 1>&2
            exit 1;
        }
    fi
fi

