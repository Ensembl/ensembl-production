#!/bin/bash --
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

if [[ "$USER" == "ensgen" ]]
then
    release=$(mysql-ens-meta-prod-1 ensembl_metadata --column-names=false -e "select ensembl_genomes_version from data_release where is_current=1")
else
    release=$(mysql-ens-meta-prod-1 ensembl_metadata --column-names=false -e "select ensembl_version from data_release where is_current=1")
fi

echo $release