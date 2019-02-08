#!/usr/bin/env python
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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
# limitations under the License.
"""Script to generate a new VOID file describing the RDF dataset
for either Ensembl or EnsemblGenomes.
Additionally, the script validate the file and pushes it to the project
specific branch in the EBI SPOT GitHub repository."""

from __future__ import print_function

import sys
import os.path
import getopt
import datetime
# import logging
from ConfigParser import RawConfigParser

from project_ftp import ProjectFTP
from void_rdf import VoidRDF
from github import push_to_repo_branch

def usage():
    print("release_void_file.py\n[options]\n\t-c <config file> (default: void_rdf.cfg)\n\t-p <project> [ensembl|ensemblgenomes] (default: ensembl)\n\t-r <release> (e.g. 89, REQUIRED)\n\t-d <release date> (format: DD-MM-YYYY, REQUIRED)\n\t--skip-file\tDo not generate VOID file (default: FALSE)\n\t--skip-qc\tDo not perform QC (default: FALSE)\n\t--skip-push\tDo not push file to EBI SPOT github repo (default: FALSE)\n")

def main(argv):
    (project, release, releaseDate) = ('ensembl', '', '')
    configFile = 'void_rdf.cfg'
    (skip_file, skip_qc, skip_push) = (False, False, False)
    
    try:                                
        opts, args = getopt.getopt(argv, "hc:p:r:d:", ['skip-file', 'skip-qc', 'skip-push'])
    except getopt.GetoptError:          
        usage()                         
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            usage()     
            sys.exit()
        elif opt == '-c':
            configFile = arg
        elif opt == '-p':
            project = arg
        elif opt == '-r':
            release = int(arg)
        elif opt == '-d':
            releaseDate = datetime.datetime.strptime(arg, "%d-%m-%Y").date()
        elif opt == '--skip-file':
            skip_file = True
        elif opt == '--skip-qc':
            skip_qc = True
        elif opt == '--skip-push':
            skip_push = True
    
    if not project or not release or not releaseDate:
        usage()
        sys.exit(2)
    if project not in ('ensembl', 'ensemblgenomes'):
        print("Error: project must be either 'ensembl' or 'ensemblgenomes'", file = sys.stderr)
        sys.exit(2)
    if not os.path.isfile(configFile):
        print("Error: config file %s does not exist\n" % configFile, file = sys.stderr)
        usage()
        sys.exit(2)

    voidFile = 'void.ttl'
    zipped = False
    if project == 'ensemblgenomes':
        voidFile = 'ensemblgenomes_' + voidFile + '.gz'
        zipped = True
    voidRdf = None
    
    if not skip_file:
        ### Retrieve species info (name, core/xref rdf paths)
        # for each species with RDF in the project FTP area
        print("Retrieving species RDF info from %s FTP site ..." % project)
        speciesInfo = ProjectFTP(project).parseSpecies()

        ### Create Void RDF graph
        print('Generating %s VOID RDF ...' % project)
        voidRdf = VoidRDF(project, release, releaseDate, speciesInfo)
        voidRdf.generate()

        ### Dump VOID RDF to file
        print('Serialising to turtle file %s ...' % voidFile)
        voidRdf.write(voidFile, zipped)
    else:
        print('Skipping VOID file generation')
        
    if not skip_qc:
        ### QC of the VOID file
        # raise AttributeError if it does not pass, do not handle
        if skip_file:
            print('Cannot QC VOID file with --skip-file option', file = sys.stderr)
            sys.exit(2)
        if not voidRdf:
            print("Could not generate VOID RDF. Abort QC ...")
            sys.exit(2)

        print('Doing QC ...')
        voidRdf.qc()
    else:
        print('Skipping VOID file QC')
        
    if not skip_push:
        ### Push to the project specific branch of the RDF platform github repo
        # read configuration to get necessary parameters, i.e. branch and token
        if not os.path.isfile(voidFile):
            print('Cannot push %s: no such file' % voidFile, file = sys.stderr)
            sys.exit(2)
        
        config = RawConfigParser()
        config.read(configFile)
        branch = config.get(project, 'branch')
        user = config.get(project, 'user')
        token = config.get(project, 'token')
        if not branch:
            raise AttributeError("Couldn\'t get github branch name for %s from config file" % project)
        if not user:
            raise AttributeError("Couldn\'t get github user name for %s from config file" % project)
        if not token:
            raise AttributeError("Couldn\'t get github valid access token for %s from config file" % project)

        print('Pushing %s to EBI SPOT GitHub repo (branch: %s)' % (voidFile, branch))
        push_to_repo_branch(voidFile, voidFile, branch, user, token)
        print("Done.")
    else:
        print('Skipping pushing the file to EBI SPOT repo')
        
if __name__ == "__main__":
    main(sys.argv[1:])
