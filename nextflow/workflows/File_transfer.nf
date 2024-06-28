#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Parameters
params.dataset_uuid = params.dataset_uuid ?: ''
params.email = params.email ?: "ensembl-production@ebi.ac.uk"
params.initial_directory = params.initial_directory ?: ''
params.final_directory = params.final_directory ?: ''
params.slack_email = params.slack_email ?: "production-crontab-aaaaabe5bbubk2tjx324orx6ke@ebi.org.slack.com"
params.slack_notification = params.slack_notification ?: false
params.email_notification = params.email_notification ?: false
params.datacheck = params.datacheck ?: ''

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
        def dataset_uuid = params.dataset_uuid
        def initial_dir = params.initial_directory
        def datacheck = params.datacheck

        output:
        path "initial_check_output.txt"
        val exit_code

        when:
        datacheck

        script:
        """
        ensembl-datacheck --file ${initial_dir}/${dataset_uuid} --test=${datacheck} > initial_check_output.txt || exit 1
        exit_code=\$?
        """
    }

    // Step 2: Rsync files to final directory
    process RsyncFiles {
        label 'mem2GB_DM'
        input:
        def initial_dir = params.initial_directory
        def final_dir = params.final_directory
        def exit_code = DataCheckInitial.out.exit_code

        output:
        path "rsync_output.txt"

        when:
        exit_code == 0

        script:
        """
        rsync -av ${initial_dir}/ ${final_dir}/ > rsync_output.txt
        """
    }

    // Step 3: Data Check in final directory if datacheck is specified
    process DataCheckFinal {
        label 'mem2GB_H'
        input:
        def dataset_uuid = params.dataset_uuid
        def final_dir = params.final_directory
        def datacheck = params.datacheck
        def exit_code = DataCheckInitial.out.exit_code

        output:
        path "final_check_output.txt"
        val exit_code_final

        when:
        exit_code == 0 && datacheck

        script:
        """
        ensembl-datacheck --file ${final_dir}/${dataset_uuid} --test=${datacheck} > final_check_output.txt || exit 1
        exit_code_final=\$?
        """
    }

    // Step 4: Send notifications
    process SendNotifications {
        input:
        def exit_code = DataCheckInitial.out.exit_code.optional()
        def exit_code_final = DataCheckFinal.out.exit_code_final.optional()
        path initial_check_output = DataCheckInitial.out.path("initial_check_output.txt").optional()
        path final_check_output = DataCheckFinal.out.path("final_check_output.txt").optional()
        path rsync_output = RsyncFiles.out.path("rsync_output.txt").optional()

        script:
        def datacheck_provided = params.datacheck != ''
        def initial_check_success = !datacheck_provided || (initial_check_output.exists() && initial_check_output.text.contains('No failures'))
        def final_check_success = !datacheck_provided || (final_check_output.exists() && final_check_output.text.contains('No failures'))
        def email = params.email
        def slack = params.slack_email
        if (!datacheck_provided) {
            def message = "No datacheck was run. Rsync completed successfully.\nRsync Output:\n${rsync_output.text}"
            if (params.slack_notification.toBoolean()) {
                """
                curl -X POST -H 'Content-type: application/json' --data '{"text":"${message}"}' ${slack}
                """
            }
            if (params.email_notification.toBoolean()) {
                """
                echo "${message}" | mail -s "Pipeline Notification: No Datacheck Run" ${email}
                """
            }
        } else if (exit_code != 0) {
            def message = "Initial data check failed.\nInitial Check:\n${initial_check_output.text}"
            if (params.slack_notification.toBoolean()) {
                """
                curl -X POST -H 'Content-type: application/json' --data '{"text":"${message}"}' ${slack}
                """
            }
            if (params.email_notification.toBoolean()) {
                """
                echo "${message}" | mail -s "Initial Data Check Failed" ${email}
                """
            }
        } else if (exit_code_final != null && exit_code_final != 0) {
            def message = "Final data check failed.\nInitial Check:\n${initial_check_output.text}\nFinal Check:\n${final_check_output.text}"
            if (params.slack_notification.toBoolean()) {
                """
                curl -X POST -H 'Content-type: application/json' --data '{"text":"${message}"}' ${slack}
                """
            }
            if (params.email_notification.toBoolean()) {
                """
                echo "${message}" | mail -s "Final Data Check Failed" ${email}
                """
            }
        } else {
            def success_message = "Pipeline completed successfully.\nRsync Output:\n${rsync_output.text}"
            if (params.slack_notification.toBoolean()) {
                """
                curl -X POST -H 'Content-type: application/json' --data '{"text":"${success_message}"}' ${slack}
                """
            }
            if (params.email_notification.toBoolean()) {
                """
                echo "${success_message}" | mail -s "Pipeline Success" ${email}
                """
            }
        }
    }
}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${workflow.success ? 'OK' : 'FAILED'}"
}
