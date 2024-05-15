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

"""Checksum module for the Xref Download pipeline."""

from ensembl.xrefs.Base import *

class Checksum(Base):
  def run(self):
    base_path     = self.param_required('base_path')
    source_db_url = self.param_required('source_db_url')
    skip_download = self.param_required('skip_download', {'type': 'bool'})

    logging.info('Checksum starting with parameters:')
    logging.info(f'Param: base_path = {base_path}')
    logging.info(f'Param: source_db_url = {source_db_url}')
    logging.info(f'Param: skip_download = {skip_download}')

    # Connect to source db
    db_engine = self.get_db_engine(source_db_url)

    # Check if checksums already exist
    table_nonempty = 0
    if skip_download:
      with db_engine.connect() as dbi:
        query = select(func.count(ChecksumXrefSORM.checksum_xref_id))
        table_nonempty = dbi.execute(query).scalar()

    # Load checksums from files into db
    if not table_nonempty:
      self.load_checksum(base_path, source_db_url)
      logging.info('Checksum data loaded')
    else:
      logging.info('Checksum data already exists, skipping loading')

