#!/bin/sh
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

db=$1
if [ -z "$db" ]; then
    echo "Usage: $0 <dbname>" 1>&2;
    exit 1;
fi
sql='grant select, show view on `'$db'`.* to `anonymous`@`%`';
echo "database: " $db
echo "sql: " $sql
admin-mysql-eg-publicsql -e "$sql"
admin-mysql-eg-publicsql-hh -e "$sql"
sql2='grant select, show view on `'$db'`.* to `ensro`@`%.ebi.ac.uk`';
echo "sql: " $sql2
admin-mysql-eg-publicsql -e "$sql2"
admin-mysql-eg-publicsql-hh -e "$sql2"
