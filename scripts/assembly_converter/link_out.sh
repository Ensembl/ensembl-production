#!/usr/bin/env bash

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




