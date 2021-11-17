from pathlib import Path

import eHive

from .datafile.utils import manifest_rows
from .datafile.serializers import metadata_from_db, metadata_from_manifest
from .BaseProdRunnable import BaseProdRunnable


class DataFileCrawler(BaseProdRunnable):
    def run(self):
        file_metadata_list = []
        errors = []
        root_dir = Path(self.param("root_dir")).resolve()
        metadata_db_url = self.param("metadata_db_url")
        manifests = root_dir.rglob("MANIFEST")
        for manifest in manifests:
            with open(manifest, 'r') as manifest_file:
                try:
                    for manifest_row in manifest_rows(manifest_file):
                        manifest_dir = (root_dir / manifest).parent
                        manifest_data = metadata_from_manifest(manifest_row, manifest_dir)
                        species = manifest_data['species']
                        ens_release = manifest_data['ens_release']
                        db_data, err = metadata_from_db(metadata_db_url, species, ens_release)
                        if err:
                            msg = f"Error fetching metadata from DB {metadata_db_url}: {err}"
                            errors.append(msg)
                        else:
                            file_metadata_list.append({**manifest_data, **db_data})
                except ValueError as exc:
                    msg = f"Error while reading {manifest.resolve()}: {exc}"
                    errors.append(msg)
        self.param('file_metadata_list', file_metadata_list)
        self.param('errors', errors)

    def write_output(self):
        for data in self.param('file_metadata_list'):
            self.flow_output_data(data)
        self.write_result({"errors": self.param("errors")})
