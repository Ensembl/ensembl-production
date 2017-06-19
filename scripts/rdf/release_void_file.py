#!/usr/bin/env python
"""Script to generate a new VOID file describing the RDF dataset
for either Ensembl or EnsemblGenomes."""
from __future__ import print_function

import sys
import os.path
import getopt
import datetime
# import logging
from ConfigParser import RawConfigParser

import rdflib
from rdflib import Graph
from rdflib import Namespace
from rdflib import URIRef, BNode, Literal, XSD
from rdflib.namespace import RDF, FOAF, VOID

from project_ftp import ProjectFTP
from void_rdf import VoidRDF
from qc_void import qc
# from github import push_to_branch_repo

def usage():
    print("release_void_file.py\n[options]\n\t-c <config file> (default: void_rdf.cfg)\n\t-p <project> [ensembl|ensemblgenomes] (default: ensembl)\n\t-r <release> (e.g. 89, default: 'current')\n\t-d <release date> (format: DD-MM-YYYY)\n")

def main(argv):
    (project, release, releaseDate) = ('ensembl','','')
    configFile = 'void_rdf.cfg'
    
    try:                                
        opts, args = getopt.getopt(argv, "hc:p:r:d:")
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

    if not project or not release or not releaseDate:
        usage()
        sys.exit(2)
    if project not in ('ensembl', 'ensemblgenomes'):
        print("Error: project must be either 'ensembl' or 'ensemblgenomes'", sys.stderr)
        sys.exit(2)

    if not os.path.isfile(configFile):
        print("Error: config file %s does not exist\n" % configFile, sys.stderr)
        usage()
        sys.exit()

    ### Retrieve species info (name, core/xref rdf paths)
    # for each species with RDF in the project FTP area
    speciesInfo = ProjectFTP(project).parseSpecies()

    ### Create Void RDF graph
    voidFile = "%s_void.ttl.gz" % project
    voidRdf = VoidRDF(project, release, releaseDate, speciesInfo)
    voidRdf.generate()

    ### QC of the VOID file
    # raise AttributeError if it does not pass, do not handle
    voidRdf.qc()

    ### Dump VOID RDF to file and zip
    voidRdf.write(voidFile)
    

    ### Push to the project specific branch of the RDF platform github repo
    # read configuration to get necessary parameters, i.e. branch and token
    config = RawConfigParser()
    config.read(configFile)
    branch = config.get(project, 'branch')
    token = config.get(project, 'token')
    if not branch:
        raise AttributeError("Couldn\'t get branch name for %s from config file" % project)
    if not token:
        raise AttributeError("Couldn\'t get valid access token for %s from config file" % project)

    # push_to_branch_repo(branch, token)
        
if __name__ == "__main__":
    main(sys.argv[1:])
