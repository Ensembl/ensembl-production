#!/bin/bash --
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
dir=$1
ftp_dir=$2
if [ ! -d "$dir" ]; then
    mkdir $dir
fi
if [ ! -d "$ftp_dir" ]; then
    echo "Could not find FTP directory $ftp_dir" 1>&2 
    exit 1
fi
cd $dir
list="ensembl ensembl-io ensembl-tools ensembl-variation ensembl-funcgen ensembl-compara"
for repo in $list; do
    branch=$(curl -s https://api.github.com/repos/Ensembl/$repo | json_reformat | grep default_branch | sed -e 's/.*: "\(.*\)".*/\1/')
    if [ ! -d "$repo" ]; then
        git clone -b $branch https://github.com/Ensembl/$repo || {
            echo "Could not clone $repo" 1>&2 
            exit 2
        }
    else
        cd $repo
        git checkout $branch
        git fetch || {
            echo "Could not fetch $repo" 1>&2 
            exit 2
        }
        git checkout $branch || {
            echo "Could not checkout $repo $branch" 1>&2 
            exit 2
        }
        git pull || {
            echo "Could not pull $repo" 1>&2 
            exit 2
        }
        cd -
    fi    
done
tarball=ensembl-api.tar.gz
rm -f $tarball
tar cvzf $tarball --exclude="*/.*" $list
tgt_tarball="$ftp_dir/$tarball"
if ! cmp --silent $tarball $tgt_tarball; then
    echo "Updating $tgt_tarball"
    cp $tarball $tgt_tarball
fi

