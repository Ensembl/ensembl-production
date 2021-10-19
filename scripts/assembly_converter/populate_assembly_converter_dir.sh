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

base_src=/hps/nobackup/flicek/ensembl/production/release_dumps
base_dest=/hps/nobackup/flicek/ensembl/production/release_dumps/assembly_converter
vert_ftp=/nfs/ensemblftp/PUBLIC/pub
non_vert_ftp=/nfs/ensemblgenomes/ftp/pub
testing=false


while getopts "n:v:s:d:T" opt; do
  case $opt in
    s) base_src="$OPTARG"
    ;;
    d) base_dest="$OPTARG"
    ;;
    v) vert_ftp="$OPTARG"
    ;;
    n) non_vert_ftp="$OPTARG"
    ;;
    T) testing=true
    ;;
    \?) echo "Invalid option -$OPTARG" 1>&2
    ;;
  esac
done

echo ""
echo "DELETE EXISTING DATA"
echo "----------------------"
rm -rf ${base_dest}/*

echo ""
echo "PROCESSING VERTEBRATES"
echo "----------------------"
for dir in `ls ${base_src}/release-${ENS_VERSION}/vertebrates/assembly_chain`
do
    echo "mkdir -p ${base_dest}/www/${dir} if not exists"
    if [ "$testing" = false ]; then
        mkdir -p ${base_dest}/www/${dir}
    fi

    echo "---------------------------"
    echo "Copying... ${dir} chain files"
    echo "---------------------------"

    for file in `ls ${base_src}/release-${ENS_VERSION}/vertebrates/assembly_chain/${dir}`
    do
        if test ${file} !=  "CHECKSUMS"
        then
            echo "cp ${base_src}/release-${ENS_VERSION}/vertebrates/assembly_chain/${dir}/${file} ${base_dest}/www/${dir}/"
            if [ "$testing" = false ]; then
                cp ${base_src}/release-${ENS_VERSION}/vertebrates/assembly_chain/${dir}/${file} ${base_dest}/www/${dir}/
            fi
        fi
    done

    echo "------------------------"
    echo "Copying, unzipping and renaming indexed current ${dir} dna.toplevel.fa"
    echo "------------------------"

    for file in `ls ${base_src}/release-${ENS_VERSION}/vertebrates/fasta/${dir}/dna_index/`
    do
        if test ${file} !=  "CHECKSUMS"
        then
            if [ "$testing" = false ]; then
                if [[ "${file}" = *".fa.gz.fai" ]]
                then
                    echo "cp ${base_src}/release-${ENS_VERSION}/vertebrates/fasta/${dir}/dna_index/${file} ${base_dest}/www/${dir}/"
                    cp ${base_src}/release-${ENS_VERSION}/vertebrates/fasta/${dir}/dna_index/${file} ${base_dest}/www/${dir}/
                    mv -f "${base_dest}/www/${dir}/${file}" "${base_dest}/www/${dir}/${file/.fa.gz.fai/.fa.fai}"
                elif [[ "${file}" = *".fa.gz" ]]
                then
                   echo "cp ${base_src}/release-${ENS_VERSION}/vertebrates/fasta/${dir}/dna_index/${file} ${base_dest}/www/${dir}/"
                   cp ${base_src}/release-${ENS_VERSION}/vertebrates/fasta/${dir}/dna_index/${file} ${base_dest}/www/${dir}/
                   echo "Unzipping files ${file}"
                   gunzip -f ${base_dest}/www/${dir}/${file}
                fi
            fi
        fi
    done

    echo "------------------------"
    echo "Copying, unzipping and indexing previous assembly ${dir} dna.toplevel.fa"
    echo "------------------------"

    for assembly in `ls ${base_src}/release-${ENS_VERSION}/vertebrates/assembly_chain/${dir} | xargs -n 1 basename | sed s/_to.*// | uniq`
    do
        if test ${assembly} !=  "CHECKSUMS"
        then
            if [ "$testing" = false ]; then
                if [[ "${assembly}" = 'GRCh37' && "${dir}" = 'homo_sapiens' ]]
                then
                    file_path=`find ${vert_ftp}/grch37/release-*/fasta/${dir}/dna/ -type f -name "${dir^}.${assembly}.*.dna.toplevel.fa.gz" -o -name "${dir^}.${assembly}.dna.toplevel.fa.gz" | sort -r | head -n1`
                elif [[ "${assembly}" = 'NCBI35' && "${dir}" = 'homo_sapiens' ]]
                then
                    file_path=`find ${vert_ftp}/release-*/homo_sapiens*/data/fasta/dna/ -type f -name "${dir^}.*.${assembly}.*.dna.contig.fa.gz" | sort -r | head -n1`
                elif [[ "${assembly}" = 'NCBI34' && "${dir}" = 'homo_sapiens' ]]
                then
                    file_path=`find ${vert_ftp}/release-*/human*/data/fasta/dna/ -type f -name "${dir^}.${assembly}.*.dna.contig.fa.gz" | sort -r | head -n1`
                elif [[ "${assembly}" = 'NCBIM36' && "${dir}" = 'mus_musculus' ]]
                then
                    file_path=`find ${vert_ftp}/release-*/mus_musculus*/data/fasta/dna/ -type f -name "${dir^}.${assembly}.*.dna.seqlevel.fa.gz" | sort -r | head -n1`
                else
                    file_path=`find ${vert_ftp}/release-*/fasta/${dir}/dna/ -type f -name "${dir^}.${assembly}.*.dna.toplevel.fa.gz" -o -name "${dir^}.${assembly}.dna.toplevel.fa.gz" | sort -r | head -n1`
                fi
                if [[ -n "$file_path" ]]
                then
                    file=`echo ${file_path} | xargs -n 1 basename | sed s/.gz//`
                else
                    echo "INFO: Cannot find file for assembly '$assembly'"
                    continue
                fi
                if [ ! -f "${base_dest}/www/${dir}/$file" ]
                then
                    echo "cp $file_path ${base_dest}/www/${dir}"
                    cp $file_path ${base_dest}/www/${dir}
                    echo "Unzipping file ${file}.gz"
                    gunzip -f ${base_dest}/www/${dir}/${file}.gz
                    echo "indexing ${file}"
                    samtools faidx ${base_dest}/www/${dir}/${file}
                fi
            fi
        fi
    done
done

echo ""
echo "PROCESSING NON-VERTEBRATES"
echo "--------------------"
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
            if [ "$testing" = false ]; then
                # Create dirs
                mkdir -p ${base_dest}/${division}/${dir}
            else
                echo "mkdir -p ${base_dest}/${division}/${dir}"
            fi

            echo "--------------------------------------"
            echo "Copying... $division  ${dir} chain files"
            echo "--------------------------------------"

            for file in `ls ${base_src}/release-${EG_VERSION}/${division}/assembly_chain/${dir}`
            do
                if test ${file} !=  "CHECKSUMS"
                then
                    echo "cp ${base_src}/release-${EG_VERSION}/${division}/assembly_chain/${dir}/${file} ${base_dest}/${division}/${dir}/"
                    if [ "$testing" = false ]; then
                        cp ${base_src}/release-${EG_VERSION}/${division}/assembly_chain/${dir}/${file} ${base_dest}/${division}/${dir}/
                    fi

                fi
            done
            echo "----------------------------------"
            echo "Copying, unzipping and renaming indexed $division ${dir} dna.toplevel.fa"
            echo "----------------------------------"

            for file in `ls ${base_src}/release-${EG_VERSION}/${division}/fasta/${dir}/dna_index/`
            do
                if test ${file} !=  "CHECKSUMS"
                then
                    if [ "$testing" = false ]; then
                        if [[ "${file}" = *".fa.gz.fai" ]]
                        then
                            echo "cp ${base_src}/release-${EG_VERSION}/${division}/fasta/${dir}/dna_index/${file} ${base_dest}/${division}/${dir}/"
                            cp ${base_src}/release-${EG_VERSION}/${division}/fasta/${dir}/dna_index/${file} ${base_dest}/${division}/${dir}/
                            mv -f "${base_dest}/${division}/${dir}/${file}" "${base_dest}/${division}/${dir}/${file/.fa.gz.fai/.fa.fai}"
                        elif [[ "${file}" = *".fa.gz" ]]
                        then
                            echo "cp ${base_src}/release-${EG_VERSION}/${division}/fasta/${dir}/dna_index/${file} ${base_dest}/${division}/${dir}/"
                            cp ${base_src}/release-${EG_VERSION}/${division}/fasta/${dir}/dna_index/${file} ${base_dest}/${division}/${dir}/
                            echo "Unzipping files ${file}"
                            gunzip -f ${base_dest}/${division}/${dir}/${file}
                        fi
                    fi
                fi
            done

            echo "------------------------"
            echo "Copying, unzipping and indexing previous assembly ${dir} dna.toplevel.fa"
            echo "------------------------"

            for assembly in `ls ${base_src}/release-${EG_VERSION}/${division}/assembly_chain/${dir}| xargs -n 1 basename | sed s/_to.*// | uniq`
            do
                if test ${assembly} !=  "CHECKSUMS"
                then
                    if [ "$testing" = false ]; then
                        file_path=`find ${non_vert_ftp}/release-*/${division}/fasta/${dir}/dna/ -type f -name "${dir^}.${assembly}.*.dna.toplevel.fa.gz" -o -name "${dir^}.${assembly}.dna.toplevel.fa.gz" | sort -r | head -n1`
                        if [[ -n "$file_path" ]]
                        then
                            file=`echo ${file_path} | xargs -n 1 basename | sed s/.gz//`
                        else
                            echo "INFO: Cannot find file for assembly '$assembly'"
                            continue
                        fi
                        if [ ! -f "${base_dest}/${division}/${dir}/$file" ]
                        then
                            echo "cp $file_path ${base_dest}/${division}/${dir}"
                            cp $file_path ${base_dest}/${division}/${dir}
                            echo "Unzipping file ${file}.gz"
                            gunzip -f ${base_dest}/${division}/${dir}/${file}.gz
                            echo "indexing ${file}"
                            samtools faidx ${base_dest}/${division}/${dir}/${file}
                        fi
                    fi
                fi
            done
        else
            echo "Skipping collection ${dir}"
        fi
    done
done

echo "All Done!!..."
