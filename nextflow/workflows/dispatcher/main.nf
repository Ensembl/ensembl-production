// See the NOTICE file distributed with this work for additional information
// regarding copyright ownership.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
/*
Nextflow Hive Pipeline Dispatcher is a Nextflow-based workflow designed to manage and execute Hive Beekeeper processes.
It automates the initialization, execution, and monitoring of a Hive-based data pipeline.
 
How to run:
===========
nextflow run main.nf \
    --hive_init_cmd "init_pipeline.pl Bio::EnsEMBL::Production::Pipeline::PipeConfig::EnsemblBlastDumps_conf $(h1-w details hive) -pipeline_name blast_dump_\$ENS_VERSION  -registry \${REG_PROD_DIR}/st6.pm" \
    --hive_force_init 1
*/

include { validateParameters; paramsSummaryLog } from 'plugin/nf-schema' 

process init_pipeline {
    memory { 1.GB * task.attempt }
    time { 1.hour}
    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 0
    tag "Hive Init Step"
    label 'small_process'
    debug true
    cache true

    input:
    val hive_init_cmd

    output:
    stdout

    script:
    """
    ${hive_init_cmd}
    """
}

process run_beekeeper {
    memory { task.attempt > 1 ? task.previousTrace.memory * 2 : (1.GB) }
    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    time { 7.days }
    maxRetries 0
    label 'small_process'
    tag 'Run beekeeper'
    cache false
    debug true

    input:
    val  init_pipeline_out

    output:
    env hive_db_uri

    script:
    def commandContent = init_pipeline_out.trim()

    // Regex pattern to extract MySQL connection string and check for -reg_conf option
    def mysqlPattern = /-url "([^"]*)"/
    def regConfPattern = /-reg_conf\s+([^\s]+)/

    // Find MySQL string using regex
    def mysqlMatcher = (commandContent =~ mysqlPattern)
    def mysqlString = mysqlMatcher ? "${mysqlMatcher[0][1]}" : null

    // Find -reg_conf option and retrieve path next to it
    def regConfMatcher = (commandContent =~ regConfPattern)
    def regConfPath = regConfMatcher ? "-reg_conf ${regConfMatcher[0][1]}" : ''


    """
      #set hive db string
      hive_db_uri=${mysqlString}
      echo "beekeeper.pl -url ${mysqlString} ${regConfPath}"
      beekeeper.pl -url ${mysqlString} ${regConfPath} -dead
      beekeeper.pl -url ${mysqlString} ${regConfPath} -sync
      beekeeper.pl -url ${mysqlString} ${regConfPath} -reset_failed_jobs
      beekeeper.pl -url ${mysqlString} ${regConfPath} -loop_until ANALYSIS_FAILURE
    """
}

process check_status {
    memory { 1.GB * task.attempt }
    time { 1.hour * task.attempt }
    maxRetries 3
    label 'small_process'
    tag 'check pipeline status'
    cache false
    debug true

    input:
    val hive_mysql_db_uri

    script:
    """
    #!/usr/bin/env python

    from sqlalchemy import create_engine, func
    from sqlalchemy.orm import sessionmaker
    from ensembl.production.core.models.hive import Beekeeper, Job

    engine = create_engine('${hive_mysql_db_uri}', pool_recycle=3600, echo=False)
    hive_session = sessionmaker()
    hive_session.configure(bind=engine)
    s = hive_session()

    msg = f"Hive Pipeline ${hive_mysql_db_uri} Failed Or Not Completed ...!"

    #'SEMAPHORED','READY','CLAIMED','COMPILATION','PRE_CLEANUP','FETCH_INPUT','RUN','WRITE_OUTPUT','POST_HEALTHCHECK','POST_CLEANUP','DONE','FAILED','PASSED_ON'

    non_done_jobs_count = s.query(func.count(Job.job_id)).filter(Job.status.in_(['SEMAPHORED','READY','RUN','FAILED'])).scalar()
    
    if non_done_jobs_count:
        raise ValueError(msg)

    result = s.query(Beekeeper).order_by(Beekeeper.beekeeper_id.desc()).first()
    
    if (result is None) or (result.cause_of_death not in ['NO_WORK', 'LOOP_LIMIT']):
        raise ValueError(msg)
    """
}

workflow {

  //Param validation and help message 
  validateParameters()

  log.info """
      🐝 Hive Pipeline Dispatcher 🐝
      =================================
      🚀 Workflow Parameters Summary:
      ${paramsSummaryLog(workflow)}
      =================================
  """.stripIndent()

   init_pipeline(params.hive_init_cmd) | run_beekeeper | check_status

}
