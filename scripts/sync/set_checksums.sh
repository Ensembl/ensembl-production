#!/bin/bash --
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


srv=$(get_staging_server.sh)
for division in EPl EPr EF EG EM; do
    process_division.sh $division echo | while read db; do
        set_table_checksums.sh $srv $db
    done
done
process_division.sh EB echo | while read db; do
    set_table_checksums.sh ${srv}b $db
done
