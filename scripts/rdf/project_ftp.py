#!/usr/bin/env python

from ftplib import FTP, error_perm

class ProjectFTP(object):
    """Class to represent either the Ensembl or EnsemblGenomes FTP directory.
    Provide methods to scan its content and return relevant information for
    producing the project VOID file."""

    projectInfo = {
        "ensembl": {
            "name": "Ensembl",
            "url": "ftp.ensembl.org",
            "www": "http://www.ensembl.org",
            "license": "/info/about/legal/code_licence.html",
            "rdfDir": "/pub/current_rdf"
        },
        "ensemblgenomes": {
            "name": "EnsemblGenomes",
            "url": "ftp.ensemblgenomes.org",
            "www": "http://www.ensemblgenomes.org",
            "license": "/info/about/legal/code_licence",
            "divisions": [ "bacteria", "fungi", "metazoa", "plants", "protists" ]
        }
    }
    
    def __init__(self, project):
        """Create a new ProjectFTP(project)"""
        if project not in ProjectFTP.projectInfo:
            raise ValueError("Unknown project %s" % project)

        self.project = project
        self.project_name = ProjectFTP.projectInfo[project]["name"]
        self.url = ProjectFTP.projectInfo[project]["url"]
        self.www = ProjectFTP.projectInfo[project]["www"]
        self.license = self.www + ProjectFTP.projectInfo[project]["license"]
        self.ftp = None
        
    def connect(self):
        self.ftp = FTP(self.url)
        self.ftp.login()

    def disconnect(self):
        self.ftp.quit()

    def parseSpecies(self):
        """Parse FTP directory structure to retrieve the set of species
        having RDF data.
        Returns a list of dictionaries where each element contain information
        about a species that can be used to dump the corresponding section of
        the VOID file."""
        self.connect()
        speciesData = []
        if "rdfDir" in ProjectFTP.projectInfo[self.project]:
            # this is Ensembl, with one single location for RDF independent of division
            rdfDir = ProjectFTP.projectInfo[self.project]["rdfDir"]
            self.ftp.cwd(rdfDir)
            try:
                speciesData = [
                    { "name": s,
                      "rdf": {
                          "core": "ftp://%s%s/%s/%s.ttl.gz" % (self.url, rdfDir, s, s),
                          "xrefs": "ftp://%s%s/%s/%s_xrefs.ttl.gz" % (self.url, rdfDir, s, s),
                      }
                    } for s in self.ftp.nlst() if s != 'rdf' ]
                
            except error_perm, resp:
                if str(resp) == "550 No files found":
                    print("No species directories in %s" % rdfDir)
                else:
                    raise
        else: # this is EnsemblGenomes, have to deal with divisions and possibly collections
            try:
                divisions = ProjectFTP.projectInfo[self.project]["divisions"]
                for division in sorted(divisions):
                    divisionRDFDir = "/pub/current/%s/rdf" % division
                    self.parseDivision(divisionRDFDir, speciesData)
                    
            except error_perm, resp:
                if str(resp) == "550 No files found":
                    print("No species/collections directories in %s" % divisionRDFDir)
                else:
                    raise
                            
        self.disconnect()
        
        return speciesData

    def parseDivision(self, rdfDir, speciesData):
        """Recursive method to parse EnsemblGenomes RDF data organised according to division
        and eventually collections.
        A division might have all data organised into collections, e.g. bactera (one sub 
        directory per collection, each containing one directory for each species in the collection),
        or it might have some species each one into its own directory and some collections
        as well, e.g. fungi.
        """

        self.ftp.cwd(rdfDir)
        subDirs = self.ftp.nlst()
        for subDir in subDirs:
            if "collection" not in subDir:
                # this is a normal species dir, add the species info directly
                species_name = subDir
                speciesData.append(
                    {
                        "name": species_name,
                        "rdf": {
                            "core": "ftp://%s%s/%s/%s.ttl.gz" % (self.url, rdfDir, species_name, species_name),
                            "xrefs": "ftp://%s%s/%s/%s_xrefs.ttl.gz" % (self.url, rdfDir, species_name, species_name),
                        }
                    }
                )
            else:
                # enter the collection subdir and get the species data from there
                self.parseDivision("%s/%s" % (rdfDir, subDir), speciesData)
