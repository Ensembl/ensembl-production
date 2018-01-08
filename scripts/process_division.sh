#!/bin/bash
# Copyright [2009-2014] EMBL-European Bioinformatics Institute
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


division=$1
shift
server=$1
shift
production_db_name=$1
shift
release=$1
shift
script="$@"

if [ -z "$division" ] || [ -z "$server" ] || [ -z "$production_db_name" ]; then
    echo "Usage: $0 <division> <server> <production_db_name> <release>" 1>&2
    exit 1
fi
if [ -z "$script" ]; then
    script="echo"
fi
if [ -z "$release" ]; then
    for dbname in $($server $production_db_name --column-names=false -e "select concat(species.db_name,\"_\",db.db_type,\"_\",db.db_release,\"_\",db.db_assembly) from division join division_species using (division_id) join species using (species_id) join db using (species_id) where division.shortname=\"$division\" and db.is_current=1"); do
        $script $dbname || {
            echo "Could not process $dbname with $script" 1>&2;
            exit 1;
        }
    done
    for dbname in $($server $production_db_name --column-names=false -e "select db_name from division join division_db using (division_id) where shortname=\"$division\" and is_current=1"); do
        $script $dbname  || {
            echo "Could not process $dbname with $script" 1>&2;
            exit 1;
        }
    done
else
    for dbname in $($server $production_db_name --column-names=false -e "select concat(species.db_name,\"_\",db.db_type,\"_\",db.db_release,\"_\",db.db_assembly) from division join division_species using (division_id) join species using (species_id) join db using (species_id) where division.shortname=\"$division\" and db.db_release=$release"); do
        $script $dbname || {
            echo "Could not process $dbname with $script" 1>&2;
            exit 1;
        }
    done
    for dbname in $($server $production_db_name --column-names=false -e "select db_name from division join division_db using (division_id) where shortname=\"$division\" and db_name like \"%$release%\""); do
        $script $dbname  || {
            echo "Could not process $dbname with $script" 1>&2;
            exit 1;
        }
    done
fi
