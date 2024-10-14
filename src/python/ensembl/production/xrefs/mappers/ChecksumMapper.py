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

"""Mapper module for processing Checksum xref data."""

from ensembl.production.xrefs.mappers.BasicMapper import *


class ChecksumMapper(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        self.mapper(mapper)
        mapper.set_up_logging()

    def target(self) -> None:
        return None

    def mapper(self, mapper: BasicMapper = None):
        if mapper:
            self._mapper = mapper

        return self._mapper

    def upload(self, results: List[Dict[str, Any]], species_id: int) -> None:
        if not species_id:
            logging.info("No species_id found, doing nothing")
            return

        source_id = self.source_id()

        logging.info("Deleting records from previous possible upload runs")
        with self.xref().connect() as xref_dbi:
            self._delete_entries("object_xref", source_id, xref_dbi)
            self._delete_entries("xref", source_id, xref_dbi)

        # Start session, in order to get inserted IDs
        Session = sessionmaker(self.xref())
        with Session.begin() as session:
            logging.info("Starting xref insertion")

            # Record UPIs to make sure we do not attempt to insert duplicate UPIs
            upi_xref_id = {}
            for row in results:
                upi = row["upi"]
                if upi_xref_id.get(upi):
                    row["xref_id"] = upi_xref_id[upi]
                else:
                    xref_object = XrefUORM(
                        source_id=source_id,
                        accession=upi,
                        label=upi,
                        version=1,
                        species_id=species_id,
                        info_type="CHECKSUM",
                    )
                    session.add(xref_object)
                    session.flush()
                    row["xref_id"] = xref_object.xref_id
                    upi_xref_id[upi] = xref_object.xref_id

            logging.info("Starting object_xref insertion")
            for row in results:
                object_xref_object = ObjectXrefUORM(
                    ensembl_id=row["id"],
                    ensembl_object_type=row["object_type"],
                    xref_id=row["xref_id"],
                    linkage_type="CHECKSUM",
                    ox_status="DUMP_OUT",
                )
                session.add(object_xref_object)

        logging.info("Finished insertions")

    def source_id(self) -> int:
        source_name = self.external_db_name()

        with self.xref().connect() as dbi:
            source_id = dbi.execute(
                select(SourceUORM.source_id).where(SourceUORM.name == source_name)
            ).scalar()

        return int(source_id)

    def _delete_entries(self, table: str, source_id: int, dbi: Connection) -> None:
        if table == "xref":
            query = delete(XrefUORM).where(XrefUORM.source_id == source_id)
        elif table == "object_xref":
            query = delete(ObjectXrefUORM).where(
                ObjectXrefUORM.xref_id == XrefUORM.xref_id,
                XrefUORM.source_id == source_id,
            )
        else:
            raise AttributeError(
                f"Invalid table to delete: {table}. Can either be 'xref' or 'object_xref'."
            )

        count = dbi.execute(query).rowcount

        logging.info(f"Deleted {count} entries from '{table}' table")
