#  See the NOTICE file distributed with this work for additional information
#  regarding copyright ownership.
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

"""Scheduling module to create download jobs for all xref sources in config file."""

from ensembl.production.xrefs.Base import *

class ScheduleDownload(Base):
  def run(self):
    config_file     = self.param_required('config_file')
    source_db_url   = self.param_required('source_db_url')
    reuse_db        = self.param_required('reuse_db', {'type': 'bool'})
    skip_preparse   = self.param('skip_preparse', None, {'type': 'bool', 'default' : False})

    logging.info('ScheduleDownload starting with parameters:')
    logging.info(f'Param: config_file = {config_file}')
    logging.info(f'Param: source_db_url = {source_db_url}')
    logging.info(f'Param: reuse_db = {reuse_db}')
    logging.info(f'Param: skip_preparse = {skip_preparse}')

    # Create the source db from url
    self.create_source_db(source_db_url, reuse_db)

    # Extract sources to download from config file
    sources = []
    with open(config_file) as conf_file:
      sources = json.load(conf_file)

    if len(sources) < 1:
      raise IOError(f'No sources found in config file {config_file}. Need sources to run pipeline')

    for source_data in sources:
      name         = source_data['name']
      parser       = source_data['parser']
      priority     = source_data['priority']
      file         = source_data['file']
      db           = source_data.get('db')
      version_file = source_data.get('release')
      preparse     = source_data.get('preparse')
      rel_number   = source_data.get('release_number')
      catalog      = source_data.get('catalog')

      logging.info(f'Source to download: {name}')

      # Revert to the old parser if not pre-parsing
      if preparse and skip_preparse:
        parser = source_data['old_parser']
        preparse = 0

      # Pass the source parameters into download jobs
      self.write_output('sources', {
        'parser'       : parser,
        'name'         : name,
        'priority'     : priority,
        'db'           : db,
        'version_file' : version_file,
        'preparse'     : preparse,
        'file'         : file,
        'rel_number'   : rel_number,
        'catalog'      : catalog
      })

