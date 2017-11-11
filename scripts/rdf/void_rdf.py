#!/usr/bin/env python
"""Class whose instances take information from project species RDF files,
construct an RDF graph representing the dataset (VOID), and dump it to file."""

import gzip
import datetime
import rdflib
from rdflib import Graph
from rdflib import Namespace
from rdflib import URIRef, BNode, Literal, XSD
from rdflib.namespace import RDF, FOAF, VOID

from rfc3987 import parse

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

    def generate(self):
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
        g.add( (self.ds, FOAF.page, ebi.rdf+"/services/sparql")) # As in the doc
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
        g.add( (ensemblDist, FOAF.page, ebi.rdf+"/services/sparql") ) # As in the doc
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
            self.void.add( (speciesId, RDF.type, dcmi.Dataset))
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
            self.void.add( (speciesPart2, RDF.type, dct.Dataset) )
            self.void.add( (speciesPart2, VOID.dataDump, Literal(species["rdf"]["xrefs"])) ) # Include the ftp folder release strategy whatever
            self.void.add( (speciesPart2, dct.title, Literal(title)) )
            self.void.add( (speciesPart2, dct.description, Literal("External references for %s" % title)) )

    def write(self, fileName, zipped):
        """Dump VOID RDF graph to file."""
        voidOutput = self.void.serialize(format = 'turtle')
        if zipped:
            with gzip.open(fileName, 'wb') as f:
                f.write(voidOutput)
        else:
            voidFile = open(fileName, 'w')
            voidFile.write(voidOutput)
            voidFile.close()

    def qc(self):
        """Quality control. This is basically a combination of SPARQL queries and python error msg in case the results is not what we expect.
        These rules are done by SPARQL statements and corresponding python error msg in case of
        faulty query results. And outline of the rules that shall be enfored here can be found 
        in the pdf at github https://github.com/EBISPOT/RDF-platform."""

        if self.void is None:
            raise ValueError("Cannot check VOID, graph not created")
        
        ### Summary Level ###
        # Get all summary levels
        listOfSummaryLevelNodes=[]
        qres=self.void.query('''SELECT ?a ?b ?c WHERE { ?a ?b <http://purl.org/dc/dcmitype/Dataset>. ?a <http://purl.org/pav/hasCurrentVersion> ?c }''')
        if len(qres)==0:
            raise AttributeError('No Summary Level found! Summary level is defined through the attributes <http://purl.org/dc/dcmitype/Dataset> and <http://purl.org/pav/hasCurrentVersion>')

        #Turn all the summary level subjects into string and add them to a list
        for row in qres:
            listOfSummaryLevelNodes.append("<"+str(row.a)+">")

            #Let's run through the list of summary level subjects and do some test
            for entity in listOfSummaryLevelNodes:
                # First check: connectivity: Check for every summary node if there is a Version level and if this version level has a distribution level
                query='SELECT ?d ?x ?z WHERE {'+entity+' <http://purl.org/pav/hasCurrentVersion> ?d . ?d <http://purl.org/dc/terms/hasDistribution> ?x. ?x <http://rdfs.org/ns/void#dataDump> ?z }'
                qres=self.void.query(query)
                # If result is empty, that means connectivity is not given!
                if (len(qres)==0):
                    # print "No data Dump found through first run, now looking for a Subsets!"
                    query='SELECT ?a ?b ?c WHERE {'+entity+' <http://purl.org/pav/hasCurrentVersion> ?d . ?d <http://purl.org/dc/terms/hasDistribution> ?x. ?x <http://rdfs.org/ns/void#subset> ?z  }'
                    check2=self.void.query(query)
                    if (len(check2)==0):
                        # If I am nice guy, you could investigate further where it failed exactly
                        raise AttributeError('Connectivity between Summary, Version and Distribution level is not given! '+entity+" has to have the attribute <http://purl.org/pav/hasCurrentVersion>, its version level <http://purl.org/dc/terms/hasDistribution> and the distribution level is idendified by <http://rdfs.org/ns/void#dataDump> or has to have a subset <http://rdfs.org/ns/void#subset> with a dataDump!")


                # Second Check, Necessary attributes - Check if the necessary attributes for the summary level are given (title, publish, description besides the things checked above)
                listOfPredicats=[]
                listOfObjects=[]
                query='Select ?b ?c {'+entity+'?b ?c}'
                qres=self.void.query(query)
                for row in qres:
                    #listOfPredicats.append(str(row.b))
                    #listOfObjects.append(str(row.c))
                    listOfPredicats.append(row.b.encode("utf-8"))
                    listOfObjects.append(row.c.encode("utf-8"))
            

                if "http://purl.org/dc/terms/title" not in listOfPredicats:
                    raise AttributeError('Title of type http://purl.org/dc/terms/title is missing in '+entity)
                if "http://purl.org/dc/terms/publisher" not in listOfPredicats:
                    raise AttributeError('Publisher of type http://purl.org/dc/terms/publisher is missing in '+entity)
                if "http://purl.org/dc/terms/description" not in listOfPredicats:
                    raise AttributeError('Description of type http://purl.org/dc/terms/description is missing in '+entity)
                ### Negative Check
                if "http://rdfs.org/ns/void#dataDump" in listOfPredicats:
                    raise AttributeError('dataDump of type http://rdfs.org/ns/void#dataDump MUST NOT be present on summary level - '+entity)
                if "http://purl.org/dc/terms/creator" in listOfPredicats:
                    raise AttributeError('Creator of type http://purl.org/dc/terms/creator MUST NOT be present on summary level '+entity)

                parse(listOfObjects[listOfPredicats.index("http://purl.org/dc/terms/publisher")], rule='IRI')


        # Third Check: Check all summary level with a hasPart relationship if these references sub summary level exist!
        # 1: Get all Summary Levels(TopLevel) with a hasPart relationship
        qres=self.void.query('''SELECT DISTINCT ?a WHERE { ?a <http://purl.org/dc/terms/hasPart> ?x. ?a ?b <http://purl.org/dc/dcmitype/Dataset>. ?a <http://purl.org/pav/hasCurrentVersion> ?y}''')
        listOfAllTopLevels=[]
        for row in qres:
            listOfAllTopLevels.append("<"+row.a+">")

        listOfAllHasParts=[]
        # 2:Go Through the hasPart References for every toplevel
        for topLevel in listOfAllTopLevels:
            listOfAllHasParts=[]
            #Get a list of the has part summary levels the top level is referencing to
            qres=self.void.query('SELECT DISTINCT ?x WHERE {'+topLevel+'<http://purl.org/dc/terms/hasPart> ?x}')
            for row in qres:
                listOfAllHasParts.append("<"+row.x+">")

        # 3:Check for connectivity - do the referenced summarylevels exist?
        for subTopLevel in listOfAllHasParts:
            # Get the summary level that was reference via hasPart for the toplevel. If I can not find it, something is wrong
            qres=self.void.query('SELECT DISTINCT ?b WHERE {'+subTopLevel+' <http://purl.org/pav/hasCurrentVersion> ?b}')
            if len(qres)==0:
                raise AttributeError('Toplevel references via hasPart to '+subTopLevel+' but it does not exist')


        ### Version Level (ID: is dct:dataset, dct:isVersionOf) ###
        listOfVersionNodes=[]
        qres=self.void.query('''SELECT ?a  WHERE {?a ?b <http://purl.org/dc/dcmitype/Dataset>. ?a <http://purl.org/dc/terms/isVersionOf> ?c}''')

        if (len(qres)==0):
            #If I am nice guy, you could investigate further where it failed exactly
            raise AttributeError('Could not find any version level - it is defined through <http://purl.org/dc/dcmitype/Dataset> and <http://purl.org/dc/terms/isVersionOf>')

        for row in qres:
            listOfVersionNodes.append("<"+str(row.a)+">")

        for entity in listOfVersionNodes:
            listOfPredicats=[]
            listOfObjects=[]
            query='Select ?b ?c {'+entity+'?b ?c}'
            qres=self.void.query(query)
            for row in qres:
                listOfPredicats.append(row.b.encode("utf-8"))
                listOfObjects.append(row.c.encode("utf-8"))

            if "http://purl.org/dc/terms/title" not in listOfPredicats:
                raise AttributeError('Title of type http://purl.org/dc/terms/title is missing in '+entity)
            if "http://purl.org/dc/terms/description" not in listOfPredicats:
                raise AttributeError('Description of type http://purl.org/dc/terms/description is missing in '+entity)
            if "http://purl.org/dc/terms/creator" not in listOfPredicats:
                raise AttributeError('Creator of type http://purl.org/dc/terms/creator is missing in '+entity)
            if "http://purl.org/dc/terms/publisher" not in listOfPredicats:
                raise AttributeError('Publisher of type http://purl.org/dc/terms/publisher is missing in '+entity)
            if "http://purl.org/pav/version" not in listOfPredicats:
                raise AttributeError('Version of type http://purl.org/pav/version is missing in '+entity)

            ###Negative test
            if "http://rdfs.org/ns/void#dataDump" in listOfPredicats:
                raise AttributeError('dataDump of type http://rdfs.org/ns/void#dataDump MUST NOT be present on version level - '+entity)

            parse(listOfObjects[listOfPredicats.index("http://purl.org/dc/terms/publisher")], rule='IRI')
            parse(listOfObjects[listOfPredicats.index("http://purl.org/dc/terms/creator")], rule='IRI')


        ### Distribution Level (ID: is void:dataset, dcatDistribution) ###
        #
        #   has to have for my programm
        #       void:dataDump
        #       idot:preferredPrefix
        #

        #   has to have
        #       dct:creator
        #       dct:title
        #       void:dataDump


        ### List of ALL Distribution levels
        ListOfallDistributionLevels=[]
        #qres=self.void.query('''SELECT ?a WHERE {?a ?b <http://rdfs.org/ns/void#Dataset>}''')
        qres=self.void.query('''SELECT ?a WHERE {  ?a ?b <http://rdfs.org/ns/void#Dataset>. ?a ?b <http://www.w3.org/ns/dcat#Distribution> FILTER(      NOT EXISTS{  ?x <http://rdfs.org/ns/void#subset> ?a}      )   }''')
        if len(qres)==0:
            raise AttributeError("No distribution level found! It is defined through the attribute <http://rdfs.org/ns/void#Dataset> and <http://www.w3.org/ns/dcat#Distribution>")

        for row in qres:
            ListOfallDistributionLevels.append("<"+str(row.a)+">")

        listOfPredicats=[]
        for entity in ListOfallDistributionLevels:
            listOfPredicats=[]
            listOfObjects=[]
            query='Select ?b ?c {'+entity+'?b ?c}'
            qres=self.void.query(query)
            for row in qres:
                listOfPredicats.append(row.b.encode("utf-8"))
                listOfObjects.append(row.c.encode("utf-8"))
                #            listOfPredicats.append(str(row.b))
                #            listOfObjects.append(str(row.c))

            #Subset/DataDump Test I handle in an own function because it needs more logic!
            self.recursive_subset_check(entity)

            if "http://purl.org/dc/terms/title" not in listOfPredicats:
                raise AttributeError('Title of type http://purl.org/dc/terms/title is missing in '+entity)
            if "http://purl.org/dc/terms/description" not in listOfPredicats:
                raise AttributeError('Description of type http://purl.org/dc/terms/description is missing in '+entity)
            if "http://purl.org/dc/terms/creator" not in listOfPredicats:
                raise AttributeError('Creator of type http://purl.org/dc/terms/creator is missing in '+entity)
            if "http://purl.org/dc/terms/publisher" not in listOfPredicats:
                raise AttributeError('Publisher of type http://purl.org/dc/terms/publisher is missing in '+entity)
            if "http://purl.org/dc/terms/license" not in listOfPredicats:
                raise AttributeError('Licence of type http://purl.org/dc/terms/license is missing in '+entity)
            if "http://purl.org/dc/terms/format" not in listOfPredicats:
                raise AttributeError('Format of type http://purl.org/dc/terms/format is missing in '+entity)

            # Negative test
            if "http://purl.org/dc/terms/isVersionOf" in listOfPredicats:
                raise AttributeError("isVersionOf of type <http://purl.org/dc/terms/isVersionOf> MUST NOT be present on distribution level! "+entity)
            # In a way DATE is missing

            parse(listOfObjects[listOfPredicats.index("http://purl.org/dc/terms/publisher")], rule='IRI')
            parse(listOfObjects[listOfPredicats.index("http://purl.org/dc/terms/creator")], rule='IRI')
            parse(listOfObjects[listOfPredicats.index("http://purl.org/dc/terms/license")], rule='IRI')

            ########################################################


        #### List of ALL LinkedSets

        #Check for dataDump Link (and potentially other predicates in the future)
        ListOfAllLinkSets=[]
        qres=self.void.query('''SELECT ?a WHERE {?a ?b <http://rdfs.org/ns/void#Linkset>}''' )
        for row in qres:
            ListOfAllLinkSets.append("<"+str(row.a)+">")

        for entity in ListOfAllLinkSets:
            # First check for connectivity: Is the subset connected to a void:Dataset?
            qres=self.void.query('SELECT ?a WHERE {?a ?x <http://rdfs.org/ns/void#Dataset>. ?a ?b '+entity+'}')
            if len(qres)!=1:
                raise AttributeError('Linkset is missing connection to a distribution level (which is defined through <http://rdfs.org/ns/void#Dataset>')

            # Check Numer two: Check predicated of the subset. At the moment, we only check for dataDump
            listOfPredicats=[]
            query='Select ?b ?c {'+entity+'?b ?c}'
            qres=self.void.query(query)
            for row in qres:
                listOfPredicats.append(str(row.b))
            if "http://rdfs.org/ns/void#dataDump" not in listOfPredicats:
                raise AttributeError("dataDump of type http://rdfs.org/ns/void#dataDump is missing in "+entity)

        print("Looks good")

    def recursive_subset_check(self, entity):
        """A helper function to check recursivly if the last level of a subset has a dataDump link."""
    
        # Check for subset
        qres=self.void.query('SELECT ?c WHERE {'+entity+' <http://rdfs.org/ns/void#subset> ?c }')
        # Does a subset Exist? If not, it has to have a dataDump!
        if len(qres)==0:
            subtest=self.void.query('SELECT ?a WHERE {'+entity+' <http://rdfs.org/ns/void#dataDump> ?x}')
            if len(subtest)==0:
                raise AttributeError('Could not find dataDump of type http://rdfs.org/ns/void#dataDump or no subset of type <http://rdfs.org/ns/void#subset> in '+entity)
            elif len(subtest)>1:
                raise AttributeError('More than one dataDump found in '+entity+' - this is not allowed!')
            elif len(subtest)==1:
                return True
        # A subset exists so we call the function recursivly for ever subset until we find a dataDump
        else:
            for row in qres:
                subentity="<"+row.c+">"
                self.recursive_subset_check(subentity)

