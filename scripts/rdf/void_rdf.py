#!/usr/bin/env python
"""Class whose instances take information from project species RDF files,
construct an RDF graph representing the dataset (VOID), and dump it to file."""

import datetime
import rdflib
from rdflib import Graph
from rdflib import Namespace
from rdflib import URIRef, BNode, Literal, XSD
from rdflib.namespace import RDF, FOAF, VOID

##### Namespaces #####
dataset = Namespace("http://rdf.ebi.ac.uk/dataset/")
dct = Namespace("http://purl.org/dc/terms/")
pav = Namespace("http://purl.org/pav/")
idot = Namespace("http://identifiers.org/idot/")
dcat = Namespace("http://www.w3.org/ns/dcat#")
dcmi = Namespace("http://purl.org/dc/dcmitype/")
ebi = Namespace("http://www.ebi.ac.uk/")
ensembl = Namespace("http://www.ensembl.org")
ensemblgenomes = Namespace("http://www.ensemblgenomes.org")

class VoidRDF(object):
    projectInfo = {
        "ensembl": {
            "name": "Ensembl",
            "url": "http://www.ensembl.org",
            "license": "/info/about/legal/code_licence.html",
        },
        "ensemblgenomes": {
            "name": "EnsemblGenomes",
            "url": "http://www.ensemblgenomes.org",
            "license": "/info/about/legal/code_licence"
        }
    }

    """Build new VoidRDF(project, speciesInfo)"""
    def __init__(self, project, release, releaseDate, speciesInfo):
        self.speciesInfo = speciesInfo

        self.project = VoidRDF.projectInfo[project]["name"]
        self.release = release
        self.releaseDate = releaseDate
        self.url = VoidRDF.projectInfo[project]["url"]
        if project == "ensembl":
            self.uri = URIRef(ensembl+"/")
        else:
            self.uri = URIRef(ensemblgenomes+"/")
        self.license = "%s%s" % (self.url, VoidRDF.projectInfo[project]["license"])
        
        self.void = None
        self.init_rdf()
        self.add_species_datasets()
        
    def init_rdf(self):
        """Initialise VOID RDF graph for project."""
        g = Graph()
    
        # Bind prefixes of the namespaces
        # rdflib Namespaces
        g.bind('void', VOID)
        g.bind('foaf', FOAF)
        g.bind('rdf',RDF)
        # own namespaces
        g.bind('dataset', dataset)
        g.bind('dct', dct)
        g.bind('dcmi', dcmi)
        g.bind('pav', pav)
        g.bind('idot', idot)
        g.bind('dcat', dcat)
        g.bind('ebi', ebi)
        if "Genomes" not in self.project:
            g.bind('ensembl', ensembl)
            self.ds = dataset.ensembl
        else:
            g.bind('ensemblgenomes', ensemblgenomes)
            self.ds = dataset.ensemblgenomes

        date = str(self.releaseDate)

        ensemblVersion = self.ds + "/" + date
        ensemblDist = ensemblVersion + ".rdf"
    
        # Summary
        g.add( (self.ds, RDF.type, dcmi.Dataset) )
        g.add( (self.ds, dct.title, Literal(self.project)) ) # As in the doc
        g.add( (self.ds, dct.description, Literal("%s genes and external references in RDF" % self.project)) ) # As in the doc
        g.add( (self.ds, FOAF.page, Literal("http://www.ebi.ac.uk/rdf/services/"))) # As in the doc
        g.add( (self.ds, dct.publisher, Literal("http://www.ebi.ac.uk/")) ) # As in the doc. From Specs? But could make sense to add license
        g.add( (self.ds, pav.hasCurrentVersion, ensemblVersion) ) # Version date uri
        g.add( (self.ds, dct.publisher, Literal(ebi)) )

        # Version Level
        g.add( (ensemblVersion, RDF.type, dcmi.Dataset) )
        g.add( (ensemblVersion, dct.title, Literal("%s v%d genes and external references in RDF" % (self.project, self.release))) )           #As in the doc
        g.add( (ensemblVersion, dct.issued, Literal(date, datatype=XSD.date)) ) 
        g.add( (ensemblVersion, dct.isVersionOf, self.ds) )
        g.add( (ensemblVersion, pav.version, Literal(self.release)) )
        g.add( (ensemblVersion, dct.hasDistribution, ensemblDist) )
        g.add( (ensemblVersion, dct.creator, ebi.ENSEMBL) )
        g.add( (ensemblVersion, dct.publisher, Literal(ebi)) )                                                 #As in the doc
        g.add( (ensemblVersion, dct.license, Literal("http://www.ebi.ac.uk/about/terms-of-use")) )             #As in the doc
        g.add( (ensemblVersion, dct.rights, Literal("Apache version 2.0")) )
        g.add( (ensemblVersion, dct.description, Literal("%s release %d" % (self.project, self.release))) )
        
        # Distribution
        g.add( (ensemblDist, RDF.type, VOID.Dataset) )              #As in the doc
        g.add( (ensemblDist, RDF.type, dcat.Distribution) )         #As in the doc################    g.add( (ol.ols,idt.preferredPrefix, Literal("ols") )    ### INTRODUCE prefix? Maybe not on version level but here for NAMED GRAPHS? OR come up with an own NamedGraph/ IRI tag
        g.add( (ensemblDist, dct.title, Literal("%s RDF data (release %d)" % (self.project, self.release))) )
        g.add( (ensemblDist, dct.description, Literal("%s genes and external references in RDF (release %d)" % (self.project, self.release))) )   #As in the doc
        g.add( (ensemblDist, dct.creator, ebi.ENSEMBL) )                                                 #As in the doc (but group is missing at the moment)
        g.add( (ensemblDist, dct.publisher, Literal(ebi)) )                                                      #As in the doc
        g.add( (ensemblDist, dct.license, Literal("http://www.ebi.ac.uk/about/terms-of-use")) )
        g.add( (ensemblDist, URIRef(dct + 'format'), Literal("text/turtle")) )
        g.add( (ensemblDist, FOAF.page, ebi.rdf+"/services/ensembl") ) # As in the doc
        g.add( (ensemblDist, VOID.dataDump, Literal('unknown') ) ) # As in the doc
        g.add( (ensemblDist, pav.version, Literal(date, datatype=XSD.date)) )

        self.void = g

    def add_species_datasets(self):
        if self.void is None:
            raise ValueError("Can't add species datasets, graph not initialised")

        for species in self.speciesInfo:
            # species name is assumed to be in production format, e.g. homo_sapiens
            if not species["name"]:
                raise ValueError("Species data with no name")
            speciesName = species["name"]
            
            speciesId = URIRef(dataset + speciesName)
            title = " ".join(speciesName.split('_')).capitalize()
            description = "Empty for this"

            speciesVersion = speciesId + "/" + str(self.release) # Version number of current release
            speciesDist = speciesVersion + ".rdf"
            self.void.add( (self.ds, dct.hasPart, speciesId))

            # Summary
            self.void.add( (speciesId, RDF.type, dct.Dataset))
            self.void.add( (speciesId, dct.title, Literal(title)) )
            self.void.add( (speciesId, dct.description, Literal("%s Ensembl RDF" % title)) )
            self.void.add( (speciesId, dct.publisher, self.uri) )
            self.void.add( (speciesId, pav.hasCurrentVersion, speciesVersion) )

            # Version
            self.void.add( (speciesVersion, RDF.type, dct.Dataset) )
            self.void.add( (speciesVersion, dct.title, Literal("Release %d" % self.release)) )
            self.void.add( (speciesVersion, dct.issued, Literal(self.releaseDate, datatype=XSD.date)) )
            self.void.add( (speciesVersion, dct.isVersionOf, speciesId) )
            self.void.add( (speciesVersion, dct.hasDistribution, speciesDist) )
            self.void.add( (speciesVersion, pav.version, Literal(self.release) ) )
            self.void.add( (speciesVersion, dct.creator, self.uri) )
            self.void.add( (speciesVersion, dct.publisher, self.uri) )
            self.void.add( (speciesVersion, dct.description, Literal("Released on %s" % str(self.releaseDate))) )

            # DistributionLevel
            self.void.add( (speciesDist, RDF.type, VOID.Dataset) ) # It is a void dataset
            self.void.add( (speciesDist, RDF.type, dcat.Distribution) )
            self.void.add( (speciesDist, dct.title, Literal("%s %s" % (self.project, title))))
            self.void.add( (speciesDist, dct.description, Literal("%s %s specific RDF" % (self.project, title)) ) )
            self.void.add( (speciesDist, dct.creator, self.uri) )
            self.void.add( (speciesDist, dct.publisher, self.uri) )
            self.void.add( (speciesDist, dct.license, Literal(self.license)) )
            self.void.add( (speciesDist, URIRef(dct + 'format'), Literal("text/turtle")) )
            self.void.add( (speciesDist, FOAF.page, Literal("unknown")) ) # This would be now the homepage of the ontology, but not OLS, which might be something to change
            self.void.add( (speciesDist, pav.version, Literal(self.release)) ) # Version can be null sometimes! So need a check for that replace with something else in case

            # Here we add species subset to the distribution level
            self.void.add( (speciesDist, VOID.subset, speciesVersion + "/" + speciesName + "_core") )
            self.void.add( (speciesDist, VOID.subset, speciesVersion + "/" + speciesName + "_xref") )
            
            # Information about the subsets, namely data and xrefs per resource
            speciesPart1 = speciesVersion + "/" + speciesName + "_core"
            self.void.add( (speciesPart1, RDF.type, dct.Dataset) ) # Include the ftp folder release strategy whatever
            self.void.add( (speciesPart1, VOID.dataDump, Literal(species["rdf"]["core"])) ) #Include the ftp folder release strategy whatever
            self.void.add( (speciesPart1, dct.title, Literal(title)) )
            self.void.add( (speciesPart1, dct.description, Literal("Core gene models and orthologies for %s" % title)) )
        
            speciesPart2 = speciesVersion + "/" + speciesName + "_xref"
            self.void.add( (speciesPart1, RDF.type, dct.Dataset) )
            self.void.add( (speciesPart2, VOID.dataDump, Literal(species["rdf"]["xrefs"])) ) # Include the ftp folder release strategy whatever
            self.void.add( (speciesPart2, dct.title, Literal(title)) )
            self.void.add( (speciesPart2, dct.description, Literal("External references for %s" % title)) )

    def write(self, fileName):
        """Dump VOID RDF graph to file."""
        voidOutput = self.void.serialize(format = 'turtle')
        voidFile = open(fileName, 'w')
        voidFile.write(voidOutput)
        voidFile.close()

