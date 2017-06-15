#!/usr/bin/env python
"""qc_void - Module ensuring that void files fulfill certain standards.
These rules are done by SPARQL statements and corresponding python error msg in case of
faulty query results. And outline of the rules that shall be enfored here can be found 
in the pdf at github https://github.com/EBISPOT/RDF-platform."""
import rdflib
from rfc3987 import parse

def startUp(path):
    """Load a file from a certain path into a rdflib Graph and start the check_void function with for that rdf graph."""

    g=rdflib.Graph()
    result = g.parse(str(path), format='n3')
    check_void(result)
    print "Check Completed for " + path

def recursive_subset_check(entity, graph):
    """A helper function to check recursivly if the last level of a subset has a dataDump link."""
    
    #Check for subset
    qres=graph.query('SELECT ?c WHERE {'+entity+' <http://rdfs.org/ns/void#subset> ?c }')
    #Does a subset Exist? If not, it has to have a dataDump!
    if len(qres)==0:
        subtest=graph.query('SELECT ?a WHERE {'+entity+' <http://rdfs.org/ns/void#dataDump> ?x}')
        if len(subtest)==0:
            raise AttributeError('Could not find dataDump of type http://rdfs.org/ns/void#dataDump or no subset of type <http://rdfs.org/ns/void#subset> in '+entity)
        elif len(subtest)>1:
            raise AttributeError('More than one dataDump found in '+entity+' - this is not allowed!')
        elif len(subtest)==1:
            return True
    #A subset exists so we call the function recursivly for ever subset until we find a dataDump
    else:
        for row in qres:
            subentity="<"+row.c+">"
            recursive_subset_check(subentity, graph)

def check_void(rdf_graph):
    """Quality control. This is basically a combination of SPARQL queries and python error msg in case the results is not what we expect."""
    
    ######################################################## Summary Level###########################################################################
    ## Get all summary levels
    listOfSummaryLevelNodes=[]
    qres=rdf_graph.query('''SELECT ?a ?b ?c WHERE { ?a ?b <http://purl.org/dc/dcmitype/Dataset>. ?a <http://purl.org/pav/hasCurrentVersion> ?c }''')
    if len(qres)==0:
        raise AttributeError('No Summary Level found! Summary level is defined through the attributes <http://purl.org/dc/dcmitype/Dataset> and <http://purl.org/pav/hasCurrentVersion>')

    #Turn all the summary level subjects into string and add them to a list
    for row in qres:
        listOfSummaryLevelNodes.append("<"+str(row.a)+">")

    #Let's run through the list of summary level subjects and do some test
    for entity in listOfSummaryLevelNodes:
        #First check: connectivity: Check for every summary node if there is a Version level and if this version level has a distribution level
            query='SELECT ?d ?x ?z WHERE {'+entity+' <http://purl.org/pav/hasCurrentVersion> ?d . ?d <http://purl.org/dc/terms/hasDistribution> ?x. ?x <http://rdfs.org/ns/void#dataDump> ?z }'
            qres=rdf_graph.query(query)
            #If result is empty, that means connectivity is not given!
            if (len(qres)==0):
                print "No data Dump found through first run, now looking for a Subsets!"
                query='SELECT ?a ?b ?c WHERE {'+entity+' <http://purl.org/pav/hasCurrentVersion> ?d . ?d <http://purl.org/dc/terms/hasDistribution> ?x. ?x <http://rdfs.org/ns/void#subset> ?z  }'
                check2=rdf_graph.query(query)
                if (len(check2)==0):
                    #If I am nice guy, you could investigate further where it failed exactly
                    raise AttributeError('Connectivity between Summary, Version and Distribution level is not given! '+entity+" has to have the attribute <http://purl.org/pav/hasCurrentVersion>, its version level <http://purl.org/dc/terms/hasDistribution> and the distribution level is idendified by <http://rdfs.org/ns/void#dataDump> or has to have a subset <http://rdfs.org/ns/void#subset> with a dataDump!")


        #Second Check, Necessary attributes - Check if the necessary attributes for the summary level are given (title, publish, description besides the things checked above)
            listOfPredicats=[]
            listOfObjects=[]
            query='Select ?b ?c {'+entity+'?b ?c}'
            qres=rdf_graph.query(query)
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
            ###Negative Check
            if "http://rdfs.org/ns/void#dataDump" in listOfPredicats:
                raise AttributeError('dataDump of type http://rdfs.org/ns/void#dataDump MUST NOT be present on summary level - '+entity)
            if "http://purl.org/dc/terms/creator" in listOfPredicats:
                raise AttributeError('Creator of type http://purl.org/dc/terms/creator MUST NOT be present on summary level '+entity)

            parse(listOfObjects[listOfPredicats.index("http://purl.org/dc/terms/publisher")], rule='IRI')


    #Third Check: Check all summary level with a hasPart relationship if these references sub summary level exist!
    #1: Get all Summary Levels(TopLevel) with a hasPart relationship
    qres=rdf_graph.query('''SELECT DISTINCT ?a WHERE { ?a <http://purl.org/dc/terms/hasPart> ?x. ?a ?b <http://purl.org/dc/dcmitype/Dataset>. ?a <http://purl.org/pav/hasCurrentVersion> ?y}''')
    listOfAllTopLevels=[]
    for row in qres:
        listOfAllTopLevels.append("<"+row.a+">")

    listOfAllHasParts=[]
    #2:Go Through the hasPart References for every toplevel
    for topLevel in listOfAllTopLevels:
        listOfAllHasParts=[]
        #Get a list of the has part summary levels the top level is referencing to
        qres=rdf_graph.query('SELECT DISTINCT ?x WHERE {'+topLevel+'<http://purl.org/dc/terms/hasPart> ?x}')
        for row in qres:
            listOfAllHasParts.append("<"+row.x+">")

    #3:Check for connectivity - do the referenced summarylevels exist?
    for subTopLevel in listOfAllHasParts:
        #Get the summary level that was reference via hasPart for the toplevel. If I can not find it, something is wrong
        qres=rdf_graph.query('SELECT DISTINCT ?b WHERE {'+subTopLevel+' <http://purl.org/pav/hasCurrentVersion> ?b}')
        if len(qres)==0:
            raise AttributeError('Toplevel references via hasPart to '+subTopLevel+' but it does not exist')


######################################################## Version Level (ID: is dct:dataset, dct:isVersionOf) ##########################################################################
    listOfVersionNodes=[]
    qres=rdf_graph.query('''SELECT ?a  WHERE {?a ?b <http://purl.org/dc/dcmitype/Dataset>. ?a <http://purl.org/dc/terms/isVersionOf> ?c}''')

    if (len(qres)==0):
        #If I am nice guy, you could investigate further where it failed exactly
        raise AttributeError('Could not find any version level - it is defined through <http://purl.org/dc/dcmitype/Dataset> and <http://purl.org/dc/terms/isVersionOf>')

        #Maybe something out of the code below whatever - friday 17.00 o clock is all I say
    #    if "http://purl.org/dc/terms/isVersionOf" not in listOfPredicats:
    #            raise AttributeError('isVersionOf of type http://purl.org/dc/terms/isVersionOf is missing in '+entity)

    for row in qres:
        listOfVersionNodes.append("<"+str(row.a)+">")

    for entity in listOfVersionNodes:
            listOfPredicats=[]
            listOfObjects=[]
            query='Select ?b ?c {'+entity+'?b ?c}'
            qres=rdf_graph.query(query)
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


######################################################## Distribution Level (ID: is void:dataset, dcatDistribution) ##########################################################################
    #
    #   has to have for my programm
    #       void:dataDump
    #       idot:preferredPrefix
    #

    #   has to have
    #       dct:creator
    #       dct:title
    #       void:dataDump


###List of ALL Distribution levels
    ListOfallDistributionLevels=[]
    #qres=rdf_graph.query('''SELECT ?a WHERE {?a ?b <http://rdfs.org/ns/void#Dataset>}''')
    qres=rdf_graph.query('''SELECT ?a WHERE {  ?a ?b <http://rdfs.org/ns/void#Dataset>. ?a ?b <http://www.w3.org/ns/dcat#Distribution> FILTER(      NOT EXISTS{  ?x <http://rdfs.org/ns/void#subset> ?a}      )   }''')
    if len(qres)==0:
        raise AttributeError("No distribution level found! It is defined through the attribute <http://rdfs.org/ns/void#Dataset> and <http://www.w3.org/ns/dcat#Distribution>")

    for row in qres:
        ListOfallDistributionLevels.append("<"+str(row.a)+">")

    listOfPredicats=[]
    for entity in ListOfallDistributionLevels:
        listOfPredicats=[]
        listOfObjects=[]
        query='Select ?b ?c {'+entity+'?b ?c}'
        qres=rdf_graph.query(query)
        for row in qres:
            listOfPredicats.append(row.b.encode("utf-8"))
            listOfObjects.append(row.c.encode("utf-8"))
#            listOfPredicats.append(str(row.b))
#            listOfObjects.append(str(row.c))

        #Subset/DataDump Test I handle in an own function because it needs more logic!
        recursive_subset_check(entity, rdf_graph)

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

##Negative test
        if "http://purl.org/dc/terms/isVersionOf" in listOfPredicats:
            raise AttributeError("isVersionOf of type <http://purl.org/dc/terms/isVersionOf> MUST NOT be present on distribution level! "+entity)
        ###In a way DATE is missing

        parse(listOfObjects[listOfPredicats.index("http://purl.org/dc/terms/publisher")], rule='IRI')
        parse(listOfObjects[listOfPredicats.index("http://purl.org/dc/terms/creator")], rule='IRI')
        parse(listOfObjects[listOfPredicats.index("http://purl.org/dc/terms/license")], rule='IRI')

    ########################################################


#### List of ALL LinkedSets

    #Check for dataDump Link (and potentially other predicates in the future)
    ListOfAllLinkSets=[]
    qres=rdf_graph.query('''SELECT ?a WHERE {?a ?b <http://rdfs.org/ns/void#Linkset>}''' )
    for row in qres:
        ListOfAllLinkSets.append("<"+str(row.a)+">")

    for entity in ListOfAllLinkSets:
        #First check for connectivity: Is the subset connected to a void:Dataset?
        qres=rdf_graph.query('SELECT ?a WHERE {?a ?x <http://rdfs.org/ns/void#Dataset>. ?a ?b '+entity+'}')
        if len(qres)!=1:
            raise AttributeError('Linkset is missing connection to a distribution level (which is defined through <http://rdfs.org/ns/void#Dataset>')

        #Check Numer two: Check predicated of the subset. At the moment, we only check for dataDump
        listOfPredicats=[]
        query='Select ?b ?c {'+entity+'?b ?c}'
        qres=rdf_graph.query(query)
        for row in qres:
            listOfPredicats.append(str(row.b))
        if "http://rdfs.org/ns/void#dataDump" not in listOfPredicats:
            raise AttributeError("dataDump of type http://rdfs.org/ns/void#dataDump is missing in "+entity)



#Uncomment the last line to start the script with the file 'chembl_void.ttl'
# startUp(sys.argv[1])
