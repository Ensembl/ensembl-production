#!/bin/bash --
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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
srv=""
db=""

usage() {
    echo "Usage: $0 -s <server> -d <db>" 1>&2
}

chk=0
while getopts ":s:d:" opt; do
    case $opt in
    s)
    srv=$OPTARG
    ;;
    d)
    db=$OPTARG
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
if [ -z "$srv" ] || [ -z "$db" ]; then
    usage;
    exit 1;
fi

mysql $($srv details mysql) $db -e "select 1" >& /dev/null || {
    echo "$db not found on $srv" 1>&2
    exit 1
};
exit 0
