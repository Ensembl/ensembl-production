#!/bin/bash --
# Copyright [2009-2018] EMBL-European Bioinformatics Institute
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
# limitations under the License.


dir=$2
if [ -z "$dir" ]; then
    dir="$PWD/mysql"
fi

if [ -z "$1" ]; then
    echo "Usage: $0 db [ftp_dir]"
    exit 1
fi
db=$1
shift
shift
output_dir=$dir/$db
echo "Dumping $db to $output_dir"
echo "Gzipping .txt files"
cd $db
if [ "$#" -ne 0 ]; then
    for table in $@; do
        file="${table}.txt"
        gzip -c "$file" > "$output_dir/$file.gz"
    done
else
    rm -rf $output_dir
    mkdir -p $output_dir
    ls -1 | grep .txt | grep -v LOADER-LOG | while read file; do
        gzip -c "$file" > "$output_dir/$file.gz"
    done
fi

if [ -e "$db.sql" ]; then
    echo "Gzipping existing $db.sql file"
    gzip -nc $db.sql > $output_dir/$db.sql.gz
elif [ -e "$db.sql.gz" ]; then
    echo "$db.sql.gz file exists"
    cp $db.sql.gz $output_dir
else
    echo "Creating $db.sql.gz file exists"
    ls -1 | grep .sql| while read file; do
      cat "$file" >> $output_dir/$db.sql
      echo ";"  >> $output_dir/$db.sql
    done
    gzip -n $output_dir/$db.sql
fi

if [ -e "$db.sql_40" ]; then
    echo "Gzipping existing $db.sql_40 file"
    gzip -c $db.sql_40 > $output_dir/$db.sql_40.gz
elif [ -e "$db.sql_40.gz" ]; then
    echo "$db.sql_40.gz file exists"
    cp $db.sql_40.gz $output_dir
fi

cd -
cd $output_dir
rm -f CHECKSUMS
ls -1 *.gz | while read file; do 
    sum=$(sum $file)
    echo -ne "$sum\t$file\n" >> CHECKSUMS
done


cd - 
