#!/bin/sh --
# Copyright [2009-2019] EMBL-European Bioinformatics Institute
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


db=$1
method=$2
if [ -z "$method" ]; then
    method="--checksum"
fi
echo "Syncing $db from st2"
if [[ "$db" =~ .*_mart_.* ]]; then
    sync_db.sh -s admin-mysql-staging-2 -t admin-mysql-mart -d $db -f -- $method || {
        echo "Could not sync $db from st2 to mart" 1>&2
        exit 1;
    }
else
    sync_db.sh -s admin-mysql-staging-2 -t admin-mysql-rel -d $db -f -- $method || {
        echo "Could not sync $db from st2 to live" 1>&2
        exit 1;
    }
    sync_db.sh -s admin-mysql-staging-2 -t admin-mysql-rest -d $db -f -- $method --no-dump || {
        echo "Could not sync $db from st2 to live" 1>&2
        exit 1;
    }
#    sync_db.sh -s admin-mysql-staging-2 -t admin-mysql-staging-2-ro -d $db -f -- $method --no-dump || {
#        echo "Could not sync $db from st2 to st2-ro" 1>&2
#        exit 1;
#    }
fi
#sync_db.sh -s admin-mysql-staging-2 -t admin-mysql-eg-mirror -d $db -f -- $method --no-dump || {
#    echo "Could not sync $db from st1 to mirror" 1>&2
#    exit 1;
#}

