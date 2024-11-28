import java.text.SimpleDateFormat

src_ch = Channel.fromPath("${params.source}/*${params.file_format}")
dest_ch = Channel.value(params.destination)

log.info """\
        R S Y N C - N F   P I P E L I N E
        ============================================================
        source     : ${params.source}
        destination: ${params.destination}
        """
        .stripIndent(true)

// Helper function to check if a directory exists
def checkIfExists(path, label) {
    if (!file(path).exists()) {
        error "${label} directory doesn't exist: ${path}"
    }
}

// Function to build and send email
def sendPipelineStatusEmail(String pipelineName, String status, String recipient) {
    def execution_date = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date())
    def subject = "File Copy Status - ${status}"
    def body = """
    Dear User,

    This is to inform you that ${pipelineName} pipeline has ${status.toLowerCase()}.

    Pipeline execution summary
    ---------------------------
    Completed at          : ${execution_date}
    Duration              : ${workflow.duration}
    Success               : ${workflow.success}
    Source Directory      : ${params.source}
    Destination Directory : ${params.destination}
    workDir               : ${workflow.workDir}
    exit status           : ${workflow.exitStatus}

    Best regards,
    Production Team
    """

    sendMail(to: recipient, subject: subject, body: body)
}

def helpMessage() {
    log.info """
Usage:
nextflow run copyFiles.nf <ARGUMENTS>

  --help                    Show this usage message

  --source                  Source directory path
                            Ex: /path/to/source

  --destination             Destination directory path
                            Ex: /path/to/destination

  --file_format             File format to filter source files (e.g., .txt, .csv)
                            default: all files (*)

  --send_email              Specify whether to send email notifications on pipeline status
                            default: no

  --email_recipient         Email address to receive pipeline status notifications
                            Ex: user@example.com

Example:
nextflow run copyFiles.nf -c ../filescopy.config --source /path/to/source/data --destination /path/to/destination --file_format .vcf --send_email yes --email_recipient user@example.com
""".stripIndent()
}

process COPY {
    input:
    val src_file
    val dest_dir

    """
    rsync -avz  --no-o --no-g --no-perms  $src_file $dest_dir
    """
}

workflow {

    if(params.help){
      helpMessage()
      exit 0;
    }

    checkIfExists(params.source, 'Source')
    checkIfExists(params.destination, 'Destination')

    COPY(src_ch, dest_ch)
}

if (params.send_email == "yes") {
    workflow.onComplete {
        sendPipelineStatusEmail('RSYNC', 'Completed Successfully', params.email_recipient)
    }

    workflow.onError {
        sendPipelineStatusEmail('RSYNC', 'Failed', params.email_recipient)
    }
}
