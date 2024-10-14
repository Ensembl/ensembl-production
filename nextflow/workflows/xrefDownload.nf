#!/usr/bin/env nextflow

// Parameter default values
params.pipeline_name = 'Xref Download Pipeline'
params.help = false

println """\
        XREF DOWNLOAD PIPELINE
        ======================
        source_db_url             : ${params.source_db_url}
        base_path                 : ${params.base_path}
        reuse_db                  : ${params.reuse_db}
        skip_download             : ${params.skip_download}
        skip_preparse             : ${params.skip_preparse}
        clean_files               : ${params.clean_files}
        split_files_by_species    : ${params.split_files_by_species}
        config_file               : ${params.config_file}
        sources_config_file       : ${params.sources_config_file}
        clean_dir                 : ${params.clean_dir}
        tax_ids_file              : ${params.tax_ids_file}
        update_mode               : ${params.update_mode}
        """
        .stripIndent()

def helpMessage() {
    log.info"""
    Usage:
    nextflow run ensembl-production/xrefDownload.nf <ARGUMENTS>
        --source_db_url             (mandatory)     Database URL to store information about xref sources.
                                                    Syntax: 'mysql://user:password@host:port/dbname'

        --base_path                 (mandatory)     Path where log and source files will be stored,
                                                    a scratch space with sufficient storage is recommended.

        --reuse_db                  (optional)      If set to 1, an existing source database (specified in --source_db_url) will be reused.
                                                    Default: 0

        --skip_download             (optional)      If set to 1, source files will only be downloaded if they don't already exist in --base_path.
                                                    Default: 0

        --skip_preparse             (optional)      If set to 1, the pre-parse step will be skipped (no central DB).
                                                    Default: 1

        --clean_files               (optional)      If set to 1, the Cleanup analysis will be run for RefSeq and UniProt files.
                                                    Default: 1

        --split_files_by_species    (optional)      If set to 1, UniProt and RefSeq file will be split according to taxonomy ID.
                                                    Default: 1

        --config_file               (optional)      Path to the json file containing information about xref sources to download.
                                                    Default: $BASE_DIR/ensembl_nf/src/python/ensembl/xrefs/config/xref_all_sources.json

        --sources_config_file       (optional)      Path to the ini file containing information about all xref sources and species/divisions.
                                                    Default: $BASE_DIR/ensembl_nf/src/python/ensembl/xrefs/config/xref_config.ini

        --clean_dir                 (optional)      Path where to save the cleaned up files.
                                                    Default: [--base_path]/clean_files

        --tax_ids_file              (optional)      Path to the file containing the taxonomy IDs of the species to extract data for.
                                                    Used to update the data for the provided species.

        --update_mode               (optional)      If set to 1, pipeline is in update mode, refreshing/updating its data for new taxonomy IDs.
                                                    Only used if --tax_ids_file is set. Default: 0
    """.stripIndent()
}

workflow {
    if (params.help || !params.source_db_url || !params.base_path) {
        helpMessage()

        if (!params.source_db_url) {
            println """
            Missing required param source_db_url
            """.stripIndent()
        }
        if (!params.base_path) {
            println """
            Missing required param base_path
            """.stripIndent()
        }

        exit 1
    }

    ScheduleDownload()
    timestamp = ScheduleDownload.out[0]

    DownloadSource(ScheduleDownload.out[1].splitText(), timestamp)

    CleanupTmpFiles(DownloadSource.out.collect())
    ScheduleCleanup(CleanupTmpFiles.out, timestamp)

    Checksum(ScheduleCleanup.out[0], timestamp)
    if (params.split_files_by_species) {
        CleanupSplitSource(ScheduleCleanup.out[1].ifEmpty([]).splitText(), timestamp)
        NotifyByEmail(Checksum.out.concat(CleanupSplitSource.out.collect()).collect(), timestamp)
    } else {
        CleanupSource(ScheduleCleanup.out[1].ifEmpty([]).splitText(), timestamp)
        NotifyByEmail(Checksum.out.concat(CleanupSource.out.collect()).collect(), timestamp)
    }
}

process ScheduleDownload {
    label 'small_process'

    output:
    val timestamp
    path 'dataflow_sources.json'

    script:
    timestamp = new java.util.Date().format("yyyyMMdd_HHmmss")

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ScheduleDownload --config_file ${params.config_file} --source_db_url ${params.source_db_url} --reuse_db ${params.reuse_db} --skip_preparse ${params.skip_preparse} --base_path ${params.base_path} --log_timestamp $timestamp
    """
}

process DownloadSource {
    label 'dm'
    tag "$src_name"

    input:
    val x
    val timestamp

    output:
    val 'DownloadSourceDone'

    shell:
    src_name = (x =~ /"name":\s*"([A-Za-z0-9_.-\/]+)"/)[0][1]

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.DownloadSource --dataflow '$x' --base_path ${params.base_path} --log_timestamp $timestamp --source_db_url ${params.source_db_url} --skip_download ${params.skip_download}
    """
}

process CleanupTmpFiles {
    label 'small_process'

    input:
    val x

    output:
    val 'TmpCleanupDone'

    """
    find ${params.base_path} -type f -name "*.tmp" -delete
    """
}

process ScheduleCleanup {
    label 'small_process'

    input:
    val x
    val timestamp

    output:
    val 'ScheduleCleanupDone'
    path 'dataflow_cleanup_sources.json'

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ScheduleCleanup --base_path ${params.base_path} --source_db_url ${params.source_db_url} --clean_files ${params.clean_files} --clean_dir ${params.clean_dir} --split_files_by_species ${params.split_files_by_species} --log_timestamp $timestamp
    """
}

process Checksum {
    label 'default_process'

    input:
    val x
    val timestamp

    output:
    val 'ChecksumDone'

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.Checksum --base_path ${params.base_path} --source_db_url ${params.source_db_url} --skip_download ${params.skip_download} --log_timestamp $timestamp
    """
}

process CleanupSplitSource {
    label 'mem4GB'
    tag "$src_name"

    input:
    each x
    val timestamp

    output:
    val 'CleanupDone'

    shell:
    cmd_params = ""
    src_name = (x =~ /"name":\s*"([A-Za-z0-9_.-\/]+)"/)[0][1]
    if (x =~ /"version_file":/) {
        version_file = (x =~ /"version_file":\s*"(.*?)"/)[0][1]
        cmd_params = "${cmd_params} --version_file '${version_file}'"
    }
    if (params.tax_ids_file) {
        cmd_params = "${cmd_params} --tax_ids_file ${params.tax_ids_file}"
    }

    """
    perl ${params.perl_scripts_dir}/cleanup_and_split_source.pl --base_path ${params.base_path} --log_timestamp $timestamp --source_db_url ${params.source_db_url} --name $src_name --clean_dir ${params.clean_dir} --clean_files ${params.clean_files} --update_mode ${params.update_mode} $cmd_params
    """
}

process CleanupSource {
    label 'mem4GB'
    tag "$src_name"

    input:
    val x
    val timestamp

    output:
    val 'CleanupDone'

    shell:
    cmd_params = ""
    src_name = (x =~ /"name":\s*"([A-Za-z0-9_.-\/]+)"/)[0][1]
    if (x =~ /"version_file":/) {
        version_file = (x =~ /"version_file":\s*"(.*?)"/)[0][1]
        cmd_params = "${cmd_params} --version_file '${version_file}'"
    }

    """
    perl ${params.perl_scripts_dir}/cleanup_source.pl --base_path ${params.base_path} --log_timestamp $timestamp --source_db_url ${params.source_db_url} --name $src_name --clean_dir ${params.clean_dir} --skip_download ${params.skip_download} --clean_files ${params.clean_files} $cmd_params
    """
}

process NotifyByEmail {
    label 'small_process'

    input:
    val x
    val timestamp

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.EmailNotification --pipeline_name '${params.pipeline_name}' --base_path ${params.base_path} --email ${params.email} --email_server ${params.email_server} --log_timestamp $timestamp
    """
}
