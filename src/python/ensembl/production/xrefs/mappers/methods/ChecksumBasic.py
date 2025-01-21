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

"""Base method module for handling checksums."""

from Bio import SeqIO
from Bio.Seq import Seq
import hashlib

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper
from sqlalchemy.engine import Connection
from typing import List, Dict, Any

DEFAULT_BATCH_SIZE = 1000
DEFAULT_LOG_SIZE = 10000

class ChecksumBasic:
    def __init__(self, args: Dict[str, Any] = None) -> None:
        if args is None:
            args = {}

        self._mapper = args.get("MAPPER")
        if args.get("BATCH_SIZE"):
            self._batch_size = args["BATCH_SIZE"]
        else:
            self._batch_size = DEFAULT_BATCH_SIZE

    def mapper(self, mapper: BasicMapper = None) -> BasicMapper:
        if mapper:
            self._mapper = mapper

        return self._mapper

    def batch_size(self, batch_size: int = None) -> int:
        if batch_size:
            self._batch_size = batch_size

        return self._batch_size

    def run(self, target: str, source_id: int, object_type: str, dbi: Connection) -> List[Dict[str, Any]]:
        results = []
        tmp_list = []
        count = 0
        total_count = 0
        batch_size = self.batch_size()

        for record in SeqIO.parse(target, "fasta"):
            tmp_list.append(record)
            count += 1

            if count % batch_size == 0:
                results.extend(self.perform_mapping(tmp_list, source_id, object_type, dbi))
                total_count += count
                if total_count % DEFAULT_LOG_SIZE == 0:
                    self.mapper().log_progress(f"Finished batch mapping of {total_count} sequences")
                count = 0
                tmp_list.clear()

        # Final mapping if there were some left over
        if tmp_list:
            results.extend(self.perform_mapping(tmp_list, source_id, object_type, dbi))
            total_count += count
            self.mapper().log_progress(f"Finished batch mapping of {total_count} sequences")

        return results

    def md5_checksum(self, sequence: Seq) -> str:
        digest = hashlib.md5()
        digest.update(sequence.encode())

        return digest.hexdigest()
