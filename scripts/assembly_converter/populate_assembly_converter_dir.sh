#!/usr/bin/env bash
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

base_src="/hps/nobackup/flicek/ensembl/production/release_dumps/release-${ENS_VERSION}/ftp_dumps"
base_dest="/hps/nobackup/flicek/ensembl/production/release_dumps/assembly_converter"
vert_ftp="/nfs/ftp/ensemblftp/ensembl/PUBLIC/pub"
non_vert_ftp="/nfs/ftp/ensemblftp/ensemblgenomes/pub"
divisions="vertebrates plants fungi metazoa protists"
testing=false

function usage() {
  echo "$0 -s source_base -t target_base -v vert_ftp_path -n nv_vert_path -d division -T (test mode)"
  exit 1
}

while getopts "n:v:s:d:Th" opt; do
  case $opt in
    s) base_src="$OPTARG" ;;
    t) base_dest="$OPTARG" ;;
    v) vert_ftp="$OPTARG" ;;
    n) non_vert_ftp="$OPTARG" ;;
    d) divisions="$OPTARG" ;;
    T) testing=true ;;
    h) usage ;;
    \?) echo "Invalid option -$OPTARG" 1>&2
    ;;
  esac
done

echo ""
echo "DELETE EXISTING DATA"
echo "----------------------"
if [ "$testing" == false ]; then
  rm -rf ${base_dest}/*
else
  echo "rm -rf ${base_dest}/*"
fi
echo ""
echo "PROCESSING Assembly Chain files"
echo "-------------------------------"
for division in $divisions
do
    echo ""
    echo "------------------"
    echo "Division $division"
    echo "------------------"
    for dir in `ls ${base_src}/${division}/assembly_chain`
    do
        if [[ "${dir}" != *"collection" ]]
        then
            dest_division_dir="${base_dest}/${division}/${dir}"
            if [ "$testing" == false ]; then
                # Create destination dir
                mkdir -p ${dest_division_dir}
            else
                echo "mkdir -p ${dest_division_dir}"
            fi

            echo "--------------------------------------"
            echo "Copying... ${division} ${dir} chain files"
            echo "--------------------------------------"

            for file in `ls ${base_src}/${division}/assembly_chain/${dir}`
            do
                if test ${file} !=  "CHECKSUMS"
                then
                      echo "cp ${base_src}/${division}/assembly_chain/${dir}/${file} ${dest_division_dir}/"
                    if [ "$testing" = false ]; then
                        cp ${base_src}/${division}/assembly_chain/${dir}/${file} ${dest_division_dir}/
                    fi

                fi
            done
            echo "----------------------------------"
            echo "Copying, unzipping and renaming indexed $division ${dir} dna.toplevel.fa"
            echo "----------------------------------"

            for file in `ls ${base_src}/${division}/fasta/${dir}/dna_index/`
            do
                if test ${file} !=  "CHECKSUMS"
                then
                    if [ "$testing" = false ]; then
                        if [[ "${file}" = *".fa.gz.fai" ]]
                        then
                            echo "cp ${base_src}/${division}/fasta/${dir}/dna_index/${file} ${dest_division_dir}/"
                            cp ${base_src}/${division}/fasta/${dir}/dna_index/${file} ${dest_division_dir}/
                            mv -f "${dest_division_dir}/${file}" "${dest_division_dir}/${file/.fa.gz.fai/.fa.fai}"
                        elif [[ "${file}" = *".fa.gz" ]]
                        then
                            echo "cp ${base_src}/${division}/fasta/${dir}/dna_index/${file} ${dest_division_dir}/"
                            cp ${base_src}/${division}/fasta/${dir}/dna_index/${file} ${dest_division_dir}/
                            echo "Unzipping files ${file}"
                            gunzip -f ${dest_division_dir}/${file}
                        fi
                    fi
                fi
            done

            echo "------------------------"
            echo "Copying, unzipping and indexing previous assembly ${dir} dna.toplevel.fa"
            echo "------------------------"
            if [[ $division == "vertebrates" ]]; then
              src_ftp=${vert_ftp}
            else
              src_ftp=${non_vert_ftp}
            fi
            for assembly in `ls ${base_src}/${division}/assembly_chain/${dir}| xargs -n 1 basename | sed s/_to.*// | uniq`
            do
                if test ${assembly} !=  "CHECKSUMS"
                then
                    if [ "$testing" = false ]; then
                        if [[ "${assembly}" = 'GRCh37' && "${dir}" = 'homo_sapiens' ]]
                        then
                            file_path=`find ${src_ftp}/grch37/release-*/fasta/${dir}/dna/ -type f -name "${dir^}.${assembly}.*.dna.toplevel.fa.gz" -o -name "${dir^}.${assembly}.dna.toplevel.fa.gz" | sort -r | head -n1`
                        elif [[ "${assembly}" = 'NCBI35' && "${dir}" = 'homo_sapiens' ]]
                        then
                            file_path=`find ${src_ftp}/release-*/homo_sapiens*/data/fasta/dna/ -type f -name "${dir^}.*.${assembly}.*.dna.contig.fa.gz" | sort -r | head -n1`
                        elif [[ "${assembly}" = 'NCBI34' && "${dir}" = 'homo_sapiens' ]]
                        then
                            file_path=`find ${src_ftp}/release-*/human*/data/fasta/dna/ -type f -name "${dir^}.${assembly}.*.dna.contig.fa.gz" | sort -r | head -n1`
                        elif [[ "${assembly}" = 'NCBIM36' && "${dir}" = 'mus_musculus' ]]
                        then
                            file_path=`find ${src_ftp}/release-*/mus_musculus*/data/fasta/dna/ -type f -name "${dir^}.${assembly}.*.dna.seqlevel.fa.gz" | sort -r | head -n1`
                        else
                            file_path=`find ${src_ftp}/release-*/${division}/fasta/${dir}/dna/ -type f -name "${dir^}.${assembly}.*.dna.toplevel.fa.gz" -o -name "${dir^}.${assembly}.dna.toplevel.fa.gz" | sort -r | head -n1`
                        fi
                        if [[ -n "$file_path" ]]
                        then
                            file=`echo ${file_path} | xargs -n 1 basename | sed s/.gz//`
                            echo "INFO: Found file for assembly '$file'"
                        else
                            echo "INFO: Cannot find file for assembly '$assembly'"
                            continue
                        fi
                        if [ ! -f "${dest_division_dir}/$file" ]
                        then
                          echo "INFO: cp $file_path ${dest_division_dir}"
                          cp $file_path ${dest_division_dir}
                          echo "--- Unzipping file ${file}.gz"
                          gunzip -f ${dest_division_dir}/${file}.gz
                          echo "--- Indexing ${file}"
                          samtools faidx ${dest_division_dir}/${file}
                        else
                           echo "INFO: File already present, no override ${dest_division_dir}/$file"
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
