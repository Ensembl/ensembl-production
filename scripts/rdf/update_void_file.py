#!/usr/bin/env python
"""Script to generate a new VOID file describing the RDF dataset
for either Ensembl or EnsemblGenomes."""
from __future__ import print_function

import sys
import getopt
import datetime
from ftplib import FTP

import rdflib
from rdflib import Graph
from rdflib import Namespace
from rdflib import URIRef, BNode, Literal, XSD
from rdflib.namespace import RDF, FOAF, VOID

import qc_void

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

    if project == 'ensembl':
        generate_ensembl_void(release, releaseDate)
    else:
        raise 'ensemblgenomes not yet supported'

if __name__ == "__main__":
    main(sys.argv[1:])
