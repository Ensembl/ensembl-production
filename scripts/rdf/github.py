#!/usr/bin/env python
"""Module providing a function which allows to push a project (i.e. Ensembl, EnsemblGenomes)
VOID file to the respective branch in the EBI SPOT GitHub repository."""

import requests
import base64
import json
import datetime

def push_to_repo_branch(gitHubFileName, fileName, branch, token):
    message = "Automated update " + str(datetime.datetime.now())
    path = "https://api.github.com/repos/EBISPOT/RDF-platform/branches/%s" % branch

    r = requests.get(path, headers = {'Authorization': token })
    rjson = r.json()
    treeurl = rjson['commit']['commit']['tree']['url']
    r2 = requests.get(treeurl, headers = {'Authorization': token })
    r2json = r2.json()
    sha = None

    for file in r2json['tree']:
        # Found file, get the sha code
        if file['path'] == gitHubFilename:
            sha = file['sha']

    # if sha is None after the for loop, we did not find the file name!
    if sha is None:
        print "Could not find " + gitHubFilename + " in repos 'tree' "
        raise Exception

    # assume file is gizipped
    with gzip.open(fileName, 'rb') as data:
        data_as_string = data.read()
        content = base64.b64encode(data_as_string)
    
    # gathered all the data, now let's push
    inputdata = {}
    inputdata["path"] = gitHubFileName
    inputdata["branch"] = branch
    inputdata["message"] = message
    inputdata["content"] = content
    inputdata["sha"] = str(sha)

    updateURL = "https://api.github.com/repos/EBISPOT/RDF-platform/contents/" + gitHubFileName
    try:
        rPut = requests.put(updateURL, headers = {'Authorization': token }, data = json.dumps(inputdata))
        if rPut.status_code == 404:
            print "Status code 404 when I tried to push - so I raise an error!"
            raise Exception
    except requests.exceptions.RequestException as e:
        print 'Something went wrong! I will print all the information that is available so you can figure out what happend!'
        print rPut
        print rPut.headers
        print rPut.text
        print e
