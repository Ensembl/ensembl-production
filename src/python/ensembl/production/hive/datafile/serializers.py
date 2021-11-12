from dataclasses import asdict
from pathlib import Path
from parsers import FileMetadata
from python.ensembl.production.hive.datafile.utils import ENSMetadata
from typing import Optional, Tuple

from .utils import remove_none, substitute_none, get_metadata_from_db, ManifestRow


def metadata_from_manifest(manifest_row: ManifestRow, manifest_dir: Path):
    data = manifest_row._asdict()
    data['file_path'] = str(manifest_dir / manifest_row.file_name)
    return data


def metadata_from_db(
    metadata_db_url: str, species: str, ens_release: int
) -> Tuple[Optional[dict], Optional[str]]:
    ens_metadatas, err = get_metadata_from_db(metadata_db_url, species, ens_release)
    if err:
        return None, err
    data = ens_metadatas[0]._asdict()
    data['release_date'] = data['release_date'].astimezone().isoformat()
    return data, None


def record_to_data(record: FileMetadata, compact: bool = False) -> dict:
    data = asdict(record)
    if compact:
        data['optional_data'] = remove_none(data['optional_data'])
    else:
        substitute_none(data['optional_data'])
    return data
