#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Parameters
params.dataset_uuid = "${params.dataset_uuid}" ?: ''
params.email = params.email ?: "ensembl-production@ebi.ac.uk"
params.initial_directory = "${params.initial_directory}"
params.final_directory = "${params.final_directory}"
params.slack_email = "${params.slack_email}" ?: "production-crontab-aaaaabe5bbubk2tjx324orx6ke@ebi.org.slack.com"
params.slack_notification = "${params.slack_notification}" ?: true
params.email_notification = "${params.email_notification}" ?: true
params.datacheck = "${params.datacheck}"

println """\
         F I L E   T R A N S F E R   P I P E L I N E
         ===================================
         debug                 : ${params.debug}
         file                  : ${params.file}
         final_directory       : ${params.final_directory}
         initial_directory     : ${params.initial_directory}
         email                 : ${params.email}
         email_notification    : ${params.email_notification}
         slack_email           : ${params.slack_email}
         slack_notification    : ${params.slack_notification}
         datacheck             : ${params.datacheck}
         """
         .stripIndent()

// Help message
def helpMessage() {
    log.info """
    Usage:
    nextflow run your_pipeline.nf --initial_directory <path> --final_directory <path> --slack_notification <true|false> --email_notification <true|false> --datacheck <datacheck_name> --email <email_address>
    """.stripIndent()
}

process DataCheckInitial {
    label 'mem2GB_H'
    input:
    val file
    val initial_dir
    val datacheck

    output:
    path "initial_check_output.txt"
    val exit_code

    when:
    datacheck != null && datacheck != ''

    script:
    """
    ensembl-datacheck --file ${initial_dir}/${file} --test=${datacheck} > initial_check_output.txt
    exit_code=\$?
    """
}

process RsyncFiles {
    label 'mem2GB_DM'
    input:
    val initial_dir
    val final_dir
    val file

    output:
    path "rsync_output.txt"

    when:
    file != null

    script:
    """
    rsync -av ${initial_dir}/${file} ${final_dir}/${file} > rsync_output.txt
    """
}

process DataCheckFinal {
    label 'mem2GB_H'
    input:
    val final_dir
    val datacheck

    output:
    path "final_check_output.txt"
    val exit_code_final

    when:
    datacheck != null && datacheck != ''

    script:
    """
    ensembl-datacheck --file ${final_dir}/${dataset_uuid} --test=${datacheck} > final_check_output.txt
    exit_code_final=\$?
    """
}

workflow {
    if (params.help) {
        helpMessage()
        exit 1
    }

    if (params.datacheck) {
        // Data check in initial directory
        val checkInitial = DataCheckInitial(file: params.file, initial_dir: params.initial_directory, datacheck: params.datacheck)
        checkInitial.exit_code = 0

        // Rsync files to final directory
        val rsyncFiles = RsyncFiles(initial_dir: params.initial_directory, final_dir: params.final_directory, file: params.file)
        rsyncFiles.exit_code = 0

        // Data check in final directory
        val checkFinal = DataCheckFinal(final_dir: params.final_directory, datacheck: params.datacheck)
        checkFinal.exit_code_final = 0

        // Notifications for initial check
        checkInitial.onComplete {
            def message = file("initial_check_output.txt").text
            def subject = (workflow.success) ? "Initial Data Check Success" : "Initial Data Check Failed"

            if (!workflow.success) {
                if (params.email_notification.toBoolean()) {
                    sendMail(
                        to: params.email,
                        subject: subject,
                        body: message,
                        attach: "initial_check_output.txt"
                    )
                }
                if (params.slack_notification.toBoolean()) {
                    sendMail(
                        to: params.slack_email,
                        subject: subject,
                        body: message,
                        attach: "initial_check_output.txt"
                    )
                }
                exit 1
            }
        }

        // Notifications for final check
        checkFinal.onComplete {
            def message = file("final_check_output.txt").text
            def subject = (workflow.success) ? "Final Data Check Success" : "Final Data Check Failed"

            if (params.email_notification.toBoolean()) {
                sendMail(
                    to: params.email,
                    subject: subject,
                    body: message,
                    attach: "final_check_output.txt"
                )
            }
            if (params.slack_notification.toBoolean()) {
                sendMail(
                    to: params.slack_email,
                    subject: subject,
                    body: message,
                    attach: "final_check_output.txt"
                )
            }
            if (!workflow.success) {
                exit 1
            }
        }
    }

    // Workflow completion notifications
    onComplete {
        println "Pipeline completed at: $workflow.complete"
        println "Execution status: ${workflow.success ? 'OK' : 'FAILED'}"
    }
}
