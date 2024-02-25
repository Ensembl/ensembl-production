#  See the NOTICE file distributed with this work for additional information
#  regarding copyright ownership.
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

"""
Hive DatasetFactory module to perform CRUD operation on dataset 
"""

import eHive
from ensembl.production.metadata.api.hive.dataset_factory import DatasetFactory

class HiveDatasetFactory(eHive.BaseRunnable):
  
  def fetch_input(self):
    #set default request method to update_dataset_status and set default params to update the dataset status
    self.request_methods =  ['update_dataset_status'] if self.param('request_methods') is None else self.param('request_methods')
    self.request_method_params =   {
      'update_dataset_status' : { 'dataset_uuid': self.param('dataset_uuid'), 'status': self.param('dataset_status')},
    } if  self.param('request_method_params') is None  else self.param('request_method_params')    
      
      
  def dispatch_request(self,request, **kwargs):
    method = getattr(self.dataset_factory, request, None)
    if method and callable(method):
        method(**kwargs.get('params'))
    else:
        raise ValueError(f"Invalid request method {method} ")

  def run(self):
    try:
      #initiate dataset factory instance      
      self.dataset_factory = DatasetFactory(metadata_uri=self.param_required('metadata_db_uri'))
      
      for request_method in self.request_methods:    
        response = self.dispatch_request(request_method, params=self.request_method_params[request_method])

       
    except KeyError as e:
        raise KeyError(f"Missing request parameters: {str(e)}")
    except Exception as e:
        raise Exception(f"An unexpected error occurred: {str(e)}")

  def write_output(self):
    pass
