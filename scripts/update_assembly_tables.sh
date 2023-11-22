#!/bin/bash
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2023] EMBL-European Bioinformatics Institute
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

srv=$1
file=$(mktemp)
$srv --column-names=false -e "show databases" > $file
for db_type in otherfeatures cdna rnaseq; do
    echo "Looking for $db_type dbs"
    for db in $(grep $db_type $file); do 
        core=${db/$db_type/core}
        echo "Syncing assembly from $core to $db"
        ./sync_tables.sh $srv $core $db assembly assembly_exception coord_system seq_region seq_region_synonym seq_region_attrib karyotype mapping_set seq_region_mapping
    done
done
rm -f $file