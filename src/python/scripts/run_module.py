#!/usr/bin/env python

#  Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
#  Copyright [2016-2025] EMBL-European Bioinformatics Institute
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

import importlib

from ensembl.common.Params import Params

def main():
  params = Params()

  module_name = params.param_required('module')
  class_name = module_name.split(".")[-1]

  module = importlib.import_module(module_name)
  module_class = getattr(module, class_name)
  module_instance = module_class()

  module_instance.run()

if __name__ == '__main__':
  main()
