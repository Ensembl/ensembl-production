#!/usr/bin/env nextflow

nextflow.enable.dsl=2

def required_params = ['initial_directory', 'final_directory']

// Function to check if required parameters are provided
def checkRequiredParams(params, required_params) {
    def missing_params = required_params.findAll { !params[it] }
    if (missing_params) {
        println "ERROR: Missing required parameters: ${missing_params.join(', ')}"
        exit 1
    }
}

// Check for required parameters
checkRequiredParams(params, required_params)

params.dataset_uuid = params.dataset_uuid ?: ''
params.email = params.email ?: 'ensembl-production@ebi.ac.uk'
params.email_notification = params.email_notification ?: false
params.slack_email = params.slack_email ?: 'production-crontab-aaaaabe5bbubk2tjx324orx6ke@ebi.org.slack.com'
params.slack_notification = params.slack_notification ?: false
params.datacheck = params.datacheck ?: ''
params.debug = params.debug ?: false

def workflow_name = workflow.scriptName

println """\
         F I L E   T R A N S F E R   P I P E L I N E
         ===================================
         initial_directory     : ${params.initial_directory}
         final_directory       : ${params.final_directory}
         email                 : ${params.email}
         email_notification    : ${params.email_notification}
         slack_email           : ${params.slack_email}
         slack_notification    : ${params.slack_notification}
         datacheck             : ${params.datacheck}
         """
         .stripIndent()

workflow {
    if (params.help) {
        helpMessage()
        exit 1
    }

    // Step 2: Rsync files to final directory
    process RsyncFiles {
        label 'mem2GB_DM'
        input:
        def initial_dir = params.initial_directory
        def final_dir = params.final_directory

        script:
        """
        echo "Rsyncing from ${initial_dir} to ${final_dir}"
        rsync -av ${initial_dir}/ ${final_dir}/ > rsync_output.txt
        asdfsadf
        """
    }

    RsyncFiles()
}

// Handle the errors and notifications
workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${workflow.success ? 'OK' : 'FAILED'}"

    def status = workflow.success ? 'PASSED' : 'FAILED'
    def subject = "${workflow_name} ${status}"
    def duration = workflow.duration
    def log_file = "${workflow.workDir}/.nextflow.log"
    def params_list = params.collect { k, v -> "${k}: ${v}" }.join("\n")

    def msg = """\
        ${workflow_name} Execution Summary
        ---------------------------
        Status    : ${status}
        Duration  : ${duration}
        Log file  : ${log_file}
        Parameters:
        ${params_list}
        """
        .stripIndent()

    if (params.slack_notification) {
        sendMail(
            to: params.slack_email,
            subject: subject,
            body: msg
        )
        println "Delivered Slack Notification"
    }
    if (params.email_notification) {
        sendMail(
            to: params.email,
            subject: subject,
            body: msg
        )
        println "Delivered Email Notification"
    }
}
