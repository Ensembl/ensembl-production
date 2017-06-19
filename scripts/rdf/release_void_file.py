#!/usr/bin/env python
"""Script to generate a new VOID file describing the RDF dataset
for either Ensembl or EnsemblGenomes."""
from __future__ import print_function

import sys
import getopt
import datetime
# import logging

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
    print("create_void_file.py\n[options]\n\t-p <project> [ensembl|ensemblgenomes] (default: ensembl)\n\t-r <release> (e.g. 89, default: 'current')\n\t-d <release date> (format: DD-MM-YYYY)\n")

def main(argv):
    (project, release, releaseDate) = ('ensembl','','')
    try:                                
        opts, args = getopt.getopt(argv, "hp:r:d:")
    except getopt.GetoptError:          
        usage()                         
        sys.exit(2)                     
    for opt, arg in opts:
        if opt == '-h':
            usage()     
            sys.exit()
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

    # retrieve species info (name, core/xref rdf paths)
    # for each species with RDF in the project FTP area
    speciesInfo = ProjectFTP(project).parseSpecies()

    # create Void RDF graph
    voidFile = "%s_void.ttl" % project
    voidRdf = VoidRDF(project, release, releaseDate, speciesInfo)
    voidRdf.generate()

    # QC of the VOID file
    # raise AttributeError if it does not pass, do not handle
    voidRdf.qc()

    # Dump VOID RDF to file
    voidRdf.write(voidFile)

    # # push to the project specific branch of the RDF platform github repo
    # branch = project
    # token = '' # TODO: how to get a valid one? Read from conf file e! or eg! one
    # push_to_branch_repo(branch, token)
        
if __name__ == "__main__":
    main(sys.argv[1:])
