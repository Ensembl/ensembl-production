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
# limitations under the License.

# Check tmux sessions accross all our login-nodes!
function usage () {
  echo "Usage: $0 -v [virtual_user] -u [ssh_user]"
  exit 0
}

while getopts "v:u:h" opt; do
    case "$opt" in
    v) virtual_user=$OPTARG ;;
    u) ssh_user=$OPTARG ;;
    h) usage;;
    esac
done

if [ -z "$ssh_user" ] ; then
  ssh_user=$USER
fi

if [ -z "$virtual_user" ] ; then
  virtual_user=${ssh_user}
fi

for cod in codon-login-01 codon-login-02 codon-login-03 codon-login-04 codon-login-05 codon-login-06; do
  if [[ "${virtual_user}" != "${ssh_user}" ]]; then
    echo "On $cod for $virtual_user"
    ssh ${ssh_user}@${cod} "bash -s " < $(dirname $0)/tmux_ls.sh "$virtual_user"
  else
    echo "On $cod for $ssh_user"
    ssh ${ssh_user}@${cod} "tmux ls"
  fi
done
