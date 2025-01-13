#!/usr/bin/env nextflow

// Parameter default values
params.pipeline_name = 'Xref Process Pipeline'
params.help = false

println """\
        XREF PROCESS PIPELINE
        ======================
        release                   : ${params.release}
        source_db_url             : ${params.source_db_url}
        base_path                 : ${params.base_path}
        registry_url              : ${params.registry_url}
        xref_db_url               : ${params.xref_db_url}
        run_all                   : ${params.run_all}
        species                   : ${params.species}
        antispecies               : ${params.antispecies}
        division                  : ${params.division}
        sources_config_file       : ${params.sources_config_file}
        registry_file             : ${params.registry_file}
        dc_config_file            : ${params.dc_config_file}
        """
        .stripIndent()

def helpMessage() {
  log.info"""
  Usage:
  nextflow run ensembl-production/xrefProcess.nf <ARGUMENTS>
    --release                   (mandatory)     The Ensembl release.

    --source_db_url             (mandatory)     Database URL where information about xref sources is stored (created during xrefDownload pipeline).
                                                Syntax: 'mysql://user:password@host:port/dbname'

    --base_path                 (mandatory)     Path where log and species files will be stored,
                                                a scratch space with sufficient storage is recommended.

    --registry_url              (mandatory)     Database URL on which the registry metaSearch API will be run.
                                                Syntax: 'mysql://user:password@host:port/dbname'

    --xref_db_url               (mandatory)     Database URL where the species intermediate DBs will be created.
                                                Syntax: 'mysql://user:password@host:port/

    --run_all                   (optional)      If set to 1, the pipeline will run on ALL species in registry.
                                                Default: 0

    --species                   (optional)      Comma-separated list of species to run pipeline on.
                                                Will be disregarded if --run_all is set to 1. Takes precedence over --division.

    --antispecies               (optional)      Comma-separated list of species to disregard in the run.

    --division                  (optional)      Comma-separated list of divisions to run pipeline on.
                                                Will be disregarded if --run_all is set to 1.

    --sources_config_file       (optional)      Path to the ini file containing information about all xref sources and species/divisions.
                                                Default: $BASE_DIR/ensembl_nf/src/python/ensembl/xrefs/config/xref_config.ini

    --registry_file             (mandatory)     Path to the registry config file (used in perl scripts).

    --dc_config_file            (mandatory)     Path to the datachecks configuration file.
  """.stripIndent()
}

workflow {
    // Check mandatory paremeters
    if (params.help || !params.release || !params.source_db_url || !params.base_path || !params.registry_url || !params.xref_db_url || !params.registry_file || !params.dc_config_file) {
        helpMessage()

        def required_params = [
            'release'        : params.release,
            'source_db_url'  : params.source_db_url,
            'base_path'      : params.base_path,
            'registry_url'   : params.registry_url,
            'xref_db_url'    : params.xref_db_url,
            'registry_file'  : params.registry_file,
            'dc_config_file' : params.dc_config_file
        ]

        required_params.each { param_name, param_value ->
            if (!param_value) {
                println """
                Missing required param '${param_name}'
                """.stripIndent()
            }
        }

        exit 1
    }

    // Find the species in the registry
    ScheduleSpecies()
    timestamp    = ScheduleSpecies.out[0]
    species_info = ScheduleSpecies.out[1].splitText().map{it -> it.trim()}

    // Run the species flow for each species
    species_flow(species_info, timestamp)

    // Send emails
    EmailAdvisoryXrefReport(species_flow.out.collect(), timestamp)
    NotifyByEmail(EmailAdvisoryXrefReport.out, timestamp)
}

workflow species_flow {
    take:
        species_dataflow
        timestamp
    main:
        // Extract the species name to create tuples
        GetSpeciesName(species_dataflow)

        // Schedule primary sources to parse
        ScheduleParse(GetSpeciesName.out, timestamp)
        primary_sources_ch = process_output(ScheduleParse.out[0])
        schedule_secondary_ch = process_output(ScheduleParse.out[1])

        // Parse primary sources
        ParseSource(primary_sources_ch, timestamp)

        // Schedule secondary sources to parse
        ScheduleSecondaryParse(schedule_secondary_ch, ParseSource.out.collect().count(), timestamp)
        secondary_sources_ch = process_output(ScheduleSecondaryParse.out[0])
        schedule_tertiary_ch = process_output(ScheduleSecondaryParse.out[1])

        // Parse secondary sources
        ParseSecondarySource(secondary_sources_ch, timestamp)

        // Schedule tertiary sources to parse
        ScheduleTertiaryParse(schedule_tertiary_ch, ParseSecondarySource.out.collect().count(), timestamp)
        tertiary_sources_ch = process_output(ScheduleTertiaryParse.out[0])
        dump_enembl_ch = process_output(ScheduleTertiaryParse.out[1])

        // Parse tertiary sources
        ParseTertiarySource(tertiary_sources_ch, timestamp)

        // Dump ensembl sequences
        DumpEnsembl(dump_enembl_ch, ParseTertiarySource.out.collect().count(), timestamp)
        dump_xref_ch = process_output(DumpEnsembl.out[0])
        schedule_mapping_ch = process_output(DumpEnsembl.out[1])

        // Dump xref sequences
        DumpXref(dump_xref_ch, timestamp)
        schedule_alignment_ch = process_output(DumpXref.out)

        // Schedule alignments
        ScheduleAlignment(schedule_alignment_ch, timestamp)
        alignment_ch = process_output(ScheduleAlignment.out)

        // Align dumps
        Alignment(alignment_ch, timestamp)

        // Schedule mapping
        ScheduleMapping(schedule_mapping_ch, Alignment.out.collect().count(), timestamp)
        pre_mapping_ch = process_output(ScheduleMapping.out[0])
        mapping_ch = process_output(ScheduleMapping.out[1])

        // Start pre-mapping steps
        DirectXrefs(pre_mapping_ch, timestamp)
        ProcessAlignment(DirectXrefs.out, timestamp)

        RnaCentralMapping(pre_mapping_ch, timestamp)
        UniParcMapping(RnaCentralMapping.out, timestamp)
        CoordinateMapping(UniParcMapping.out, timestamp)

        // Start mapping
        Mapping(mapping_ch, ProcessAlignment.out.concat(CoordinateMapping.out).count(), timestamp)

        // Run datachecks
        RunXrefCriticalDatacheck(Mapping.out)
        RunXrefAdvisoryDatacheck(RunXrefCriticalDatacheck.out)

	    dataflow_combined = RunXrefAdvisoryDatacheck.out.dataflow_success
            .mix(RunXrefAdvisoryDatacheck.out.dataflow_fail)
        advisory_report_ch = process_output(dataflow_combined)

        // Collect advisory datacheck outputs
        AdvisoryXrefReport(advisory_report_ch, timestamp)
    emit:
        AdvisoryXrefReport.out
}

def process_output(output_channel) {
    return output_channel.flatMap { species_name, dataflow_file ->
        def result = []
        for (line in dataflow_file.readLines()) {
            result << tuple(species_name, line)
        }
        return result
    }
}

process ScheduleSpecies {
    label 'small_process'

    output:
    val timestamp
    path 'dataflow_species.json'

    script:
    timestamp = new java.util.Date().format("yyyyMMdd_HHmmss")

    shell:
    cmd_params = ""
    if (params.species) {
        cmd_params = "${cmd_params} --species '${params.species}'"
    }
    if (params.antispecies) {
        cmd_params = "${cmd_params} --antispecies '${params.antispecies}'"
    }
    if (params.division) {
        cmd_params = "${cmd_params} --division '${params.division}'"
    }

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ScheduleSpecies --registry_url ${params.registry_url} --run_all ${params.run_all} --release ${params.release} --base_path ${params.base_path} --log_timestamp $timestamp $cmd_params
    """
}

process GetSpeciesName {
    label 'small_process'

    input:
    val dataflow

    output:
    tuple val(species_name), val(dataflow)

    shell:
    species_name = (dataflow =~ /"species_name":\s*"([A-Za-z0-9_.-]+)"/)[0][1]

    """
    """
}

process ScheduleParse {
    label 'small_process'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    tuple val(species_name), path('dataflow_primary_sources.json')
    tuple val(species_name), path('dataflow_schedule_secondary.json')

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ScheduleParse --dataflow '$dataflow' --release ${params.release} --registry_url ${params.registry_url} --priority 1 --sources_config_file ${params.sources_config_file} --source_db_url ${params.source_db_url} --xref_db_url ${params.xref_db_url} --base_path ${params.base_path} --log_timestamp $timestamp
    """
}

process ParseSource {
    label 'mem1GB'
    tag "$species_name - $source_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    val 'ParseSourceDone'

    shell:
    source_name = (dataflow =~ /"source_name":\s*"([A-Za-z0-9_.-\/]+)"/)[0][1]

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ParseSource --dataflow '$dataflow' --release ${params.release} --registry_url ${params.registry_url} --base_path ${params.base_path} --perl_scripts_dir ${params.perl_scripts_dir} --log_timestamp $timestamp
    """
}

process ScheduleSecondaryParse {
    label 'small_process'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val wait
    val timestamp

    output:
    tuple val(species_name), path('dataflow_secondary_sources.json')
    tuple val(species_name), path('dataflow_schedule_tertiary.json')

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ScheduleParse --dataflow '$dataflow' --release ${params.release} --registry_url ${params.registry_url} --priority 2 --source_db_url ${params.source_db_url} --base_path ${params.base_path} --log_timestamp $timestamp
    """
}

process ParseSecondarySource {
    label 'default_process'
    tag "$species_name - $source_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    val 'ParseSecondarySourceDone'

    shell:
    source_name = (dataflow =~ /"source_name":\s*"([A-Za-z0-9_.-\/]+)"/)[0][1]

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ParseSource --dataflow '$dataflow' --release ${params.release} --registry_url ${params.registry_url} --base_path ${params.base_path} --perl_scripts_dir ${params.perl_scripts_dir} --log_timestamp $timestamp
    """
}

process ScheduleTertiaryParse {
    label 'small_process'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val wait
    val timestamp

    output:
    tuple val(species_name), path('dataflow_tertiary_sources.json')
    tuple val(species_name), path('dataflow_dump_ensembl.json')

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ScheduleParse --dataflow '$dataflow' --release ${params.release} --registry_url ${params.registry_url} --priority 3 --source_db_url ${params.source_db_url} --base_path ${params.base_path} --log_timestamp $timestamp
    """
}

process ParseTertiarySource {
    label 'mem1GB'
    tag "$species_name - $source_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    val 'ParseTertiarySourceDone'

    shell:
    source_name = (dataflow =~ /"source_name":\s*"([A-Za-z0-9_.-\/]+)"/)[0][1]

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ParseSource --dataflow '$dataflow' --release ${params.release} --registry_url ${params.registry_url} --base_path ${params.base_path} --perl_scripts_dir ${params.perl_scripts_dir} --log_timestamp $timestamp
    """
}

process DumpEnsembl {
    label 'mem10GB'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val wait
    val timestamp

    output:
    tuple val(species_name), path('dataflow_dump_xref.json')
    tuple val(species_name), path('dataflow_schedule_mapping.json')

    script:
    def retry_flag = task.attempt > 1 ? "--retry 1" : ""

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.DumpEnsembl --dataflow '$dataflow' --release ${params.release} --base_path ${params.base_path} --perl_scripts_dir ${params.perl_scripts_dir} $retry_flag --log_timestamp $timestamp
    """
}

process DumpXref {
    label 'mem4GB'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    tuple val(species_name), path('dataflow_schedule_alignment.json')

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.DumpXref --dataflow '$dataflow' --release ${params.release} --base_path ${params.base_path} --config_file ${params.config_file} --log_timestamp $timestamp
    """
}

process ScheduleAlignment {
    label 'small_process'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    tuple val(species_name), path('dataflow_alignment.json')

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ScheduleAlignment --dataflow '$dataflow' --release ${params.release} --base_path ${params.base_path} --log_timestamp $timestamp
    """
}

process Alignment {
    label 'align_mem'
    tag "$species_name - $source_name ($source_id) - chunk $chunk"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    val 'AlignmentDone'

    shell:
    source_name = (dataflow =~ /"source_name":\s*"([A-Za-z0-9_.-\/]+)"/)[0][1]
    source_id = (dataflow =~ /"source_id":\s*([0-9]+)/)[0][1]
    chunk = (dataflow =~ /"chunk":\s*([0-9]+)/)[0][1]

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.Alignment --dataflow '$dataflow' --base_path ${params.base_path} --log_timestamp $timestamp
    """
}

process ScheduleMapping {
    label 'mem1GB'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val wait
    val timestamp

    output:
    tuple val(species_name), path('dataflow_pre_mapping.json')
    tuple val(species_name), path('dataflow_mapping.json')

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ScheduleMapping --dataflow '$dataflow' --release ${params.release} --base_path ${params.base_path} --registry_url ${params.registry_url} --log_timestamp $timestamp
    """
}

process DirectXrefs {
    label 'mem1GB'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    tuple val(species_name), val(dataflow)

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.DirectXrefs --dataflow '$dataflow' --release ${params.release} --base_path ${params.base_path} --registry_url ${params.registry_url} --log_timestamp $timestamp
    """
}

process ProcessAlignment {
    label 'mem1GB'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    val 'ProcessAlignmentDone'

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.ProcessAlignment --dataflow '$dataflow' --release ${params.release} --base_path ${params.base_path} --registry_url ${params.registry_url} --log_timestamp $timestamp
    """
}

process RnaCentralMapping {
    label 'mem1GB'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    tuple val(species_name), val(dataflow)

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.RNACentralMapping --dataflow '$dataflow' --release ${params.release} --base_path ${params.base_path} --registry_url ${params.registry_url} --source_db_url ${params.source_db_url} --log_timestamp $timestamp
    """
}

process UniParcMapping {
    label 'mem1GB'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    tuple val(species_name), val(dataflow)

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.UniParcMapping --dataflow '$dataflow' --release ${params.release} --base_path ${params.base_path} --registry_url ${params.registry_url} --source_db_url ${params.source_db_url} --log_timestamp $timestamp
    """
}

process CoordinateMapping {
    label 'mem1GB'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    val 'CoordinateMappingDone'

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.CoordinateMapping --dataflow '$dataflow' --release ${params.release} --base_path ${params.base_path} --registry_url ${params.registry_url} --source_db_url ${params.source_db_url} --perl_scripts_dir ${params.perl_scripts_dir} --log_timestamp $timestamp
    """
}

process Mapping {
    label 'mem4GB'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val wait
    val timestamp

    output:
    val species_name

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.Mapping --dataflow '$dataflow' --release ${params.release} --base_path ${params.base_path} --registry_url ${params.registry_url} --ignore_warnings ${params.ignore_warnings} --log_timestamp $timestamp
    """
}

process RunXrefCriticalDatacheck {
    label 'default_process'
    tag "$species_name"

    input:
    val species_name

    output:
    val species_name

    """
    perl ${params.perl_scripts_dir}/run_process.pl -class='Nextflow::RunDataChecks' -datacheck_names='ForeignKeys' -datacheck_groups='xref_mapping' -datacheck_types='critical' -registry_file=${params.registry_file} -config_file=${params.dc_config_file} -failures_fatal=1 -species=$species_name
    """
}

process RunXrefAdvisoryDatacheck {
    label 'default_process'
    tag "$species_name"

    input:
    val species_name

    output:
    tuple val(species_name), path('dataflow_3.json'), emit: dataflow_success, optional: true
    tuple val(species_name), path('dataflow_4.json'), emit: dataflow_fail, optional: true

    """
    perl ${params.perl_scripts_dir}/run_process.pl -class='Nextflow::RunDataChecks' -datacheck_groups='xref_mapping' -datacheck_types='advisory' -registry_file=${params.registry_file} -config_file=${params.dc_config_file} -failures_fatal=0 -species=$species_name
    """
}

process AdvisoryXrefReport {
    label 'default_process'
    tag "$species_name"

    input:
    tuple val(species_name), val(dataflow)
    val timestamp

    output:
    val species_name

    script:
    formatted_dataflow = dataflow.replace("'", '__')
    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.AdvisoryXrefReport --dataflow '$formatted_dataflow' --release ${params.release} --base_path ${params.base_path} --species_name $species_name --log_timestamp $timestamp
    """
}

process EmailAdvisoryXrefReport {
    label 'default_process'

    input:
    val wait
    val timestamp

    output:
    val 'done'

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.EmailAdvisoryXrefReport --release ${params.release} --base_path ${params.base_path} --pipeline_name '${params.pipeline_name}' --email ${params.email} --email_server ${params.email_server} --log_timestamp $timestamp
    """
}

process NotifyByEmail {
    label 'small_process'

    input:
    val wait
    val timestamp

    """
    python ${params.scripts_dir}/run_module.py --module ensembl.production.xrefs.EmailNotification --pipeline_name '${params.pipeline_name}' --base_path ${params.base_path} --email ${params.email} --email_server ${params.email_server} --log_timestamp $timestamp
    """
}
