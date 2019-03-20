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
# limitations under the License

"""Module providing a function which allows to push a project (i.e. Ensembl, EnsemblGenomes)
VOID file to the respective branch in the EBI SPOT GitHub repository."""

import requests
import base64
import json
import datetime

def push_to_repo_branch(gitHubFileName, fileName, branch, user, token):
    message = "Automated update " + str(datetime.datetime.now())
    path = "https://api.github.com/repos/EBISPOT/RDF-platform/branches/%s" % branch

    r = requests.get(path, auth=(user,token))
    if not r.ok:
        print("Error when retrieving branch info from %s" % path)
        print("Reason: %s [%d]" % (r.text, r.status_code))
        raise RuntimeError((r.text, r.status_code))
    rjson = r.json()
    treeurl = rjson['commit']['commit']['tree']['url']
    r2 = requests.get(treeurl, auth=(user,token))
    if not r2.ok:
        print("Error when retrieving commit tree from %s" % treeurl)
        print("Reason: %s [%d]" % (r2.text, r2.status_code))
        raise RuntimeError((r.text, r.status_code))
    r2json = r2.json()
    sha = None

    for file in r2json['tree']:
        # Found file, get the sha code
        if file['path'] == gitHubFileName:
            sha = file['sha']

    # if sha is None after the for loop, we did not find the file name!
    if sha is None:
        print "Could not find " + gitHubFileName + " in repos 'tree' "
        raise Exception

    with open(fileName) as data:
        content = base64.b64encode(data.read())

    # gathered all the data, now let's push
    inputdata = {}
    inputdata["path"] = gitHubFileName
    inputdata["branch"] = branch
    inputdata["message"] = message
    inputdata["content"] = content
    if sha:
        inputdata["sha"] = str(sha)

    updateURL = "https://api.github.com/repos/EBISPOT/RDF-platform/contents/" + gitHubFileName
    try:
        rPut = requests.put(updateURL, auth=(user,token), data = json.dumps(inputdata))
        if not rPut.ok:
            print("Error when pushing to %s" % updateURL)
            print("Reason: %s [%d]" % (rPut.text, rPut.status_code))
            raise Exception
    except requests.exceptions.RequestException as e:
        print 'Something went wrong! I will print all the information that is available so you can figure out what happend!'
        print rPut
        print rPut.headers
        print rPut.text
        print e
