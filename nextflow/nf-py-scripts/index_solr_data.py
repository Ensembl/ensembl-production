import json
import ijson.backends.python as ijson
import requests
import argparse


class SolrDataHandler:
    def __init__(self, solr_host, solr_collection):
        self.solr_host = solr_host
        self.solr_collection = solr_collection
        self.solr_url = "{sh}/solr/{sc}/update/json".format(sh=self.solr_host, sc=self.solr_collection)
        self.solr_commit_url = "{sh}/solr/{sc}/update?commit=true".format(sh=self.solr_host, sc=self.solr_collection)
        self.doc_format = {}
        self.doc_list = []
        self.headers = {"content-type": "application/json"}

    def single_file_parser(self, solr_json_file):
        with open(solr_json_file) as f:
            for gene in ijson.items(f, "item"):
                self.solr_index(doc_format=gene, eof_flag=False)
            # ForElse to detect EOF                !
            else:
                self.solr_index(doc_format=gene, eof_flag=True)
        print("=======", requests.get(self.solr_commit_url))

    def solr_index(self, doc_format, eof_flag):
        try:
            if not eof_flag:
                self.doc_list.append(doc_format)
            if len(self.doc_list) == 5000 or eof_flag:
                payload = json.dumps(self.doc_list)

                index_result = requests.post(
                    self.solr_url, data=payload, headers=self.headers
                )
                print('------', index_result)
                self.doc_list = []

                # return index_result
        except Exception as e:
            print(e)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog='index_solr_data.py',
        description='Index SOLR data')
    parser.add_argument('-sf', '--solr_file')  # Source JSON file to Index
    parser.add_argument('-sh', '--solr_host')  # SOLR Host
    parser.add_argument('-sc', '--solr_collection')  # SOLR Collection

    args = parser.parse_args()
    filename = args.solr_file
    solr_host = args.solr_host
    solr_collection = args.solr_collection
    sdh = SolrDataHandler(solr_host, solr_collection)
    sdh.single_file_parser(filename)