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

"""Base method module for handling mysql checksums."""

from sqlalchemy import select
from typing import Any, Dict, List
from Bio.SeqRecord import SeqRecord
from sqlalchemy.engine import Connection

from ensembl.xrefs.xref_source_db_model import ChecksumXref as ChecksumXrefSORM

from ensembl.production.xrefs.mappers.methods.ChecksumBasic import ChecksumBasic

class MySQLChecksum(ChecksumBasic):
    def perform_mapping(self, sequences: List[SeqRecord], source_id: int, object_type: str, dbi: Connection) -> List[Dict[str, Any]]:
        final_results = []

        for sequence in sequences:
            checksum = self.md5_checksum(str(sequence.seq)).upper()
            upi = None

            query = select(ChecksumXrefSORM.accession).where(
                ChecksumXrefSORM.checksum == checksum,
                ChecksumXrefSORM.source_id == source_id,
            )
            results = dbi.execute(query).mappings().all()
            
            if len(results) > 1:
                upis = [row.accession for row in results]
                raise LookupError(
                    f"The sequence {sequence.id} had a checksum of {checksum} but this resulted in more than one UPI: {upis}"
                )
            elif results:
                upi = results[0].accession

            if upi:
                final_results.append(
                    {"id": sequence.id, "upi": upi, "object_type": object_type}
                )

        return final_results
