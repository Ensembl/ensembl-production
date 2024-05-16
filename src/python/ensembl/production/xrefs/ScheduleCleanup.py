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

"""Scheduling module to create cleanup jobs for specific xref sources."""

from ensembl.production.xrefs.Base import *

class ScheduleCleanup(Base):
  def run(self):
    base_path              = self.param_required('base_path')
    source_db_url          = self.param_required('source_db_url')
    clean_files            = self.param('clean_files')
    clean_dir              = self.param('clean_dir')
    split_files_by_species = self.param('split_files_by_species')

    logging.info('ScheduleCleanup starting with parameters:')
    logging.info(f'Param: base_path = {base_path}')
    logging.info(f'Param: source_db_url = {source_db_url}')
    logging.info(f'Param: clean_files = {clean_files}')
    logging.info(f'Param: clean_dir = {clean_dir}')
    logging.info(f'Param: split_files_by_species = {split_files_by_species}')

    # Connect to source db
    db_engine = self.get_db_engine(source_db_url)
    with db_engine.connect() as dbi:
      # Get name and version file for each source
      query = select(SourceSORM.name, VersionORM.revision).where(SourceSORM.source_id==VersionORM.source_id).distinct()
      sources = dbi.execute(query).mappings().all()

    for source in sources:
      # Only cleaning RefSeq and UniProt for now
      if not (re.search(r"^RefSeq_(dna|peptide)", source.name) or re.search(r"^Uniprot", source.name)): continue

      # Remove / char from source name to access directory
      clean_name = source.name
      clean_name = re.sub(r"\/", "", clean_name)

      # Send parameters into cleanup jobs for each source
      if os.path.exists(os.path.join(base_path, clean_name)):
        logging.info(f'Source to cleanup: {source.name}')

        self.write_output('cleanup_sources', {
          'name'         : source.name,
          'version_file' : source.revision
        })

