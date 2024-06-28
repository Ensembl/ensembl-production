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

workflow {
    if (params.help) {
        helpMessage()
        exit 1
    }

    // Step 1: Data Check in initial directory if datacheck is specified
    process DataCheckInitial {
        label 'mem2GB_H'
        input:
        val file from params.file
        val initial_dir from params.initial_directory
        val datacheck from params.datacheck

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

    // Step 2: Rsync files to final directory
    process RsyncFiles {
        label 'mem2GB_DM'
        input:
        val initial_dir from params.initial_directory
        val final_dir from params.final_directory
        val file from params.file

        output:
        path "rsync_output.txt"

        when:
        file != null

        script:
        """
        rsync -av ${initial_dir}/${file} ${final_dir}/${file} > rsync_output.txt
        """
    }

    // Step 3: Data Check in final directory if datacheck is specified
    process DataCheckFinal {
        label 'mem2GB_H'
        input:
        val final_dir from params.final_directory
        val datacheck from params.datacheck

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

    if (params.datacheck) {
        DataCheckInitial {
            exit_code = 0
        }

        RsyncFiles {
            exit_code = 0
        }

        DataCheckFinal {
            exit_code_final = 0
        }

        // Notifications
        DataCheckInitial.onComplete {
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

        DataCheckFinal.onComplete {
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
