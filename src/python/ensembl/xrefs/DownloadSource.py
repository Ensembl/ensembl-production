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

"""Download module to download xref and version files."""

from ensembl.xrefs.Base import *

class DownloadSource(Base):
  def run(self):
    base_path     = self.param_required('base_path')
    parser        = self.param_required('parser')
    name          = self.param_required('name')
    priority      = self.param_required('priority')
    source_db_url = self.param_required('source_db_url')
    file          = self.param_required('file')
    skip_download = self.param_required('skip_download', {'type': 'bool'})
    db            = self.param('db')
    version_file  = self.param('version_file')
    preparse      = self.param('preparse', None, {'type': 'bool'})
    rel_number    = self.param('rel_number')
    catalog       = self.param('catalog')

    logging.info(f'DownloadSource starting for source {name}')

    # Download the main xref file
    extra_args = {}
    extra_args['skip_download_if_file_present'] = skip_download
    extra_args['db'] = db
    if rel_number and catalog:
      extra_args['rel_number'] = rel_number
      extra_args['catalog'] = catalog
    file_name = self.download_file(file, base_path, name, extra_args)

    # Download the version file
    version = ""
    if version_file:
      extra_args['release'] = 'version'
      version = self.download_file(version_file, base_path, name, extra_args)

    # Update source db
    db_engine = self.get_db_engine(source_db_url)
    with db_engine.connect() as dbi:
      query = insert(SourceSORM).values(name=name, parser=parser).prefix_with('IGNORE')
      dbi.execute(query)

      query = select(SourceSORM.source_id).where(SourceSORM.name==name)
      source_id = dbi.execute(query).scalar()

      if preparse is None: preparse = False
      query = insert(VersionORM).values(source_id=source_id, uri=file_name, index_uri=db, count_seen=priority, revision=version, preparse=preparse).prefix_with('IGNORE')
      dbi.execute(query)

