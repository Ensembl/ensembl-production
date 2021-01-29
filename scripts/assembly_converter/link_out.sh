#!/usr/bin/env bash
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
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

base_src=/hps/nobackup2/production/ensembl/ensprod/release_dumps
base_dest=/hps/nobackup2/production/ensembl/ensprod/release_dumps/assembly_converter
test=false

while getopts ":s:d:t" opt; do
  case $opt in
    s) base_src="$OPTARG"
    ;;
    d) base_dest="$OPTARG"
    ;;
    t) test=true
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

echo ""
echo "PROCESSING VERTEBRATES"
echo "----------------------"
# FIRST vertebrates
for dir in `ls ${base_src}/release-${ENS_VERSION}/vertebrates/assembly_chain`
do
    # echo "mkdir -p ${base_dest}/vertebrates/${dir} if not exists"
    if test ${test} !=  "true"
    then
        mkdir -p ${base_dest}/vertebrates/${dir}
        echo "Cleaning dir..."
        rm -rf ${base_dest}/vertebrates/${dir}/*
    fi

    echo "---------------------------"
    echo "Linking... ${dir} chain files"
    echo "---------------------------"

    for file in `ls ${base_src}/release-${ENS_VERSION}/vertebrates/assembly_chain/${dir}`
    do
        if test ${file} !=  "CHECKSUMS"
        then
            echo "ln -s ${base_src}/release-${ENS_VERSION}/vertebrates/assembly_chain/${dir}/${file} ${base_dest}/vertebrates/${dir}/"
            if test ${test} !=  "true"
            then
                ln -s ${base_src}/release-${ENS_VERSION}/vertebrates/assembly_chain/${dir}/${file} ${base_dest}/vertebrates/${dir}/
            fi
        fi
    done

    echo "------------------------"
    echo "Linking ${dir} dna_seq fai"
    echo "------------------------"

    for file in `ls ${base_src}/release-${ENS_VERSION}/vertebrates/fasta/${dir}/dna_index/`
    do
        if test ${file} !=  "CHECKSUMS"
        then
            echo "ln -s ${base_src}/release-${ENS_VERSION}/vertebrates/fasta/${dir}/dna_index/${file} ${base_dest}/vertebrates/${dir}/"
            if test ${test} !=  "true"
            then
                ln -s ${base_src}/release-${ENS_VERSION}/vertebrates/fasta/${dir}/dna_index/${file} ${base_dest}/vertebrates/${dir}/
            fi
        fi
    done
done

echo ""
echo "PROCESSING DIVISIONS"
echo "--------------------"
# NV
for division in plants fungi metazoa protists
do
    echo ""
    echo "------------------"
    echo "Division $division"
    echo "------------------"
    for dir in `ls ${base_src}/release-${EG_VERSION}/${division}/assembly_chain`
    do
        if [[ "${dir}" != *"collection" ]]
        then
            if test ${test} !=  "true"
            # Create dirs
            then
                mkdir -p ${base_dest}/${division}/${dir}
                echo "Cleaning dir..."
                rm -rf ${base_dest}/${division}/${dir}/*
            else
                echo "mkdir -p ${base_dest}/${division}/${dir}"
            fi

            echo "--------------------------------------"
            echo "Linking... $division  ${dir} chain files"
            echo "--------------------------------------"

            for file in `ls ${base_src}/release-${EG_VERSION}/${division}/assembly_chain/${dir}`
            do
                if test ${file} !=  "CHECKSUMS"
                then
                    echo "ln -s ${base_src}/release-${EG_VERSION}/${division}/assembly_chain/${dir}/${file} ${base_dest}/${division}/${dir}/"
                    if test ${test} !=  "true"
                    then
                        ln -s ${base_src}/release-${EG_VERSION}/${division}/assembly_chain/${dir}/${file} ${base_dest}/${division}/${dir}/
                    fi

                fi
            done
            echo "----------------------------------"
            echo "Linking $division ${dir} dna_seq fai"
            echo "----------------------------------"

            for file in `ls ${base_src}/release-${EG_VERSION}/${division}/fasta/${dir}/dna_index/`
            do
                if test ${file} !=  "CHECKSUMS"
                then
                    echo "ln -s ${base_src}/release-${EG_VERSION}/${division}/fasta/${dir}/dna_index/${file} ${base_dest}/${division}/${dir}/"
                    if test ${test} !=  "true"
                    then
                        ln -s ${base_src}/release-${EG_VERSION}/${division}/fasta/${dir}/dna_index/${file} ${base_dest}/${division}/${dir}/
                    fi
                fi
            done
        else
            echo "Skipping collection ${dir}"
        fi
    done
done

echo "All Done!!..."




