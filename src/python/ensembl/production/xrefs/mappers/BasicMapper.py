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

"""Base module to handle xref mapping."""

import re
import os
import sys
import warnings
import logging
import subprocess

from sqlalchemy import select, insert, update, func, delete, desc, text
from sqlalchemy.engine import Engine, Connection
from sqlalchemy.orm import Session, sessionmaker, aliased
from sqlalchemy.sql.expression import case
from sqlalchemy.sql import Select
from typing import Dict, Any, List, Optional, Tuple

from ensembl.core.models import (
    Gene as GeneORM,
    Transcript as TranscriptORM,
    Translation as TranslationORM,
    Meta as MetaCORM,
    AltAllele as AltAlleleCORM,
    t_alt_allele_attrib as AltAlleleAttribORM,
    ObjectXref as ObjectXrefCORM,
    Xref as XrefCORM,
    ExternalDb as ExternalDbORM,
    UnmappedObject as UnmappedObjectORM,
    UnmappedReason as UnmappedReasonORM,
    Analysis as AnalysisORM,
    OntologyXref as OntologyXrefORM,
    ExternalSynonym as ExternalSynonymORM,
    DependentXref as DependentXrefCORM,
    IdentityXref as IdentityXrefCORM,
    SeqRegionAttrib as SeqRegionAttribORM,
    AttribType as AttribTypeORM,
)

from ensembl.xrefs.xref_update_db_model import (
    GeneTranscriptTranslation as GeneTranscriptTranslationORM,
    GeneStableId as GeneStableIdORM,
    TranscriptStableId as TranscriptStableIdORM,
    TranslationStableId as TranslationStableIdORM,
    Meta as MetaUORM,
    ProcessStatus as ProcessStatusORM,
    ObjectXref as ObjectXrefUORM,
    AltAllele as AltAlleleUORM,
    Source as SourceUORM,
    Xref as XrefUORM,
    IdentityXref as IdentityXrefUORM,
    DependentXref as DependentXrefUORM,
    GeneDirectXref as GeneDirectXrefORM,
    TranscriptDirectXref as TranscriptDirectXrefORM,
    TranslationDirectXref as TranslationDirectXrefORM,
    Mapping as MappingORM,
    MappingJobs as MappingJobsORM,
    CoordinateXref as CoordinateXrefORM,
    Synonym as SynonymORM,
    Pairs as PairsORM,
    PrimaryXref as PrimaryXrefORM,
    DisplayXrefPriority as DisplayXrefPriorityORM,
    GeneDescPriority as GeneDescPriorityORM,
)

from datetime import datetime


class BasicMapper:
    def __init__(self, args: Dict[str, Any] = None) -> None:
        if args is None:
            args = {}

        self._xref = args.get("xref")
        self._core = args.get("core")
        self._dna_file = args.get("dna_file")
        self._protein_file = args.get("protein_file")
        self._log_file = args.get("log_file")
        self._species_dir = args.get("species_dir")

    def xref(self, xref_db_engine: Engine = None) -> Engine:
        """Getter/Setter for the xref DB engine.

        Parameters
        ----------
        xref_db_engine: sqlalchemy.engine.Engine, optional
            The xref DB engine

        Returns
        -------
        The xref DB engine.
        """
        if xref_db_engine:
            self._xref = xref_db_engine

        return self._xref

    def core(self, core_db_engine: Engine = None) -> Engine:
        """Getter/Setter for the core DB engine.

        Parameters
        ----------
        core_db_engine: sqlalchemy.engine.Engine, optional
            The core DB engine

        Returns
        -------
        The core DB engine.
        """
        if core_db_engine:
            self._core = core_db_engine

        return self._core

    def dna_file(self, dna_file: str = None) -> str:
        """Getter/Setter for the dna file.

        Parameters
        ----------
        dna_file: str, optional
            The path to the dna file

        Returns
        -------
        The dna file path
        """
        if dna_file:
            self._dna_file = dna_file

        return self._dna_file

    def protein_file(self, protein_file: str = None) -> str:
        """Getter/Setter for the protein file.

        Parameters
        ----------
        protein_file: str, optional
            The path to the protein file

        Returns
        -------
        The protein file path
        """
        if protein_file:
            self._protein_file = protein_file

        return self._protein_file

    def log_file(self, log_file: str = None) -> str:
        """Getter/Setter for the log file.

        Parameters
        ----------
        log_file: str, optional
            The path to the log file

        Returns
        -------
        The log file path
        """
        if log_file:
            self._log_file = log_file

        return self._log_file

    def species_dir(self, species_dir: str = None) -> str:
        """Getter/Setter for the species directory.

        Parameters
        ----------
        species_dir: str, optional
            The path to the species directory

        Returns
        -------
        The species directory
        """
        if species_dir:
            self._species_dir = species_dir

        return self._species_dir

    def official_name(self) -> None:
        return None

    def add_meta_pair(self, meta_key: str, meta_value: str) -> None:
        """Adds a row to the meta table.

        Parameters
        ----------
        meta_key: str
            The value of the 'meta_key' column in the meta table
        meta_value: str
            The value of the 'meta_value' column in the meta table
        """
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        with self.xref().connect() as dbi:
            dbi.execute(
                insert(MetaUORM).values(
                    meta_key=meta_key, meta_value=meta_value, date=now
                )
            )

    def get_meta_value(self, meta_key: str) -> str:
        """Gets a value from the meta table based on key.

        Parameters
        ----------
        meta_key: str
            The value of the 'meta_key' column in the meta table
        """
        with self.xref().connect() as dbi:
            query = (
                select(MetaUORM.meta_value)
                .where(MetaUORM.meta_key == meta_key)
                .order_by(MetaUORM.meta_id.desc())
            )
            value = dbi.execute(query).first()

        if value:
            value = value[0]
        return value

    def update_process_status(self, status: str) -> None:
        """Adds a row to the process_status table.

        Parameters
        ----------
        status: str
            The value of the 'status' column on the process_status table
        """
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        with self.xref().connect() as dbi:
            dbi.execute(insert(ProcessStatusORM).values(status=status, date=now))

    def set_up_logging(self) -> None:
        log_file = self.log_file()

        console_handler = logging.StreamHandler()
        file_handler = logging.FileHandler(log_file, mode="a")
        console_handler.setLevel(logging.WARNING)
        file_handler.setLevel(logging.DEBUG)

        logging.basicConfig(
            level=logging.DEBUG,
            format="%(asctime)s | %(levelname)s | %(message)s",
            datefmt="%d-%b-%Y %H:%M:%S",
            handlers=[console_handler, file_handler],
        )

    def log_progress(self, message: str) -> None:
        logging.info(message)

    def get_object_xref_id(self, ensembl_id: int, xref_id: int, ensembl_type: str, linkage_type: str, dbi: Connection, master_xref_id: int = None, status: str = None) -> int:
        """Retrieves the object_xref row ID from ensembl ID, xref ID, ensembl type, and linkage type.

        Parameters
        ----------
        ensembl_id: int
            The ensEMBL feature internal ID
        xref_id: int
            The xref ID related to the object xref
        ensembl_type: str
            The feature type (gene, transcript, or translation)
        linkage_type: str
            The type of link between the xref and ensEMBL feature
        master_xref_id: int, optional
            The xref ID of the xref that this object xref is dependent on
        status: str, optional
            The object xref status
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        The object xref ID, if found (else None).
        """
        object_xref_id = None

        query = select(ObjectXrefUORM.object_xref_id).where(
            ObjectXrefUORM.ensembl_id == ensembl_id,
            ObjectXrefUORM.xref_id == xref_id,
            ObjectXrefUORM.ensembl_object_type == ensembl_type,
            ObjectXrefUORM.linkage_type == linkage_type,
        )
        if master_xref_id is not None:
            query = query.where(ObjectXrefUORM.master_xref_id == master_xref_id)
        if status is not None:
            query = query.where(ObjectXrefUORM.ox_status == status)

        result = dbi.execute(query).fetchall()

        if result:
            object_xref_id = result[0][0]

        return object_xref_id

    def add_object_xref(self, ensembl_id: int, xref_id: int, ensembl_type: str, linkage_type: str, dbi: Connection, master_xref_id: int = None, status: str = None) -> int:
        """Adds data into object xref table in a database.

        Parameters
        ----------
        ensembl_id: int
            The ensEMBL feature internal ID
        xref_id: int
            The xref ID related to the object xref
        ensembl_type: str
            The feature type (gene, transcript, or translation)
        linkage_type: str
            The type of link between the xref and ensEMBL feature
        master_xref_id: int, optional
            The xref ID of the xref that this object xref is dependent on
        status: str, optional
            The object xref status
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        The inserted object xref ID.
        """
        query = insert(ObjectXrefUORM).values(
            ensembl_id=ensembl_id,
            xref_id=xref_id,
            ensembl_object_type=ensembl_type,
            linkage_type=linkage_type,
        )
        if master_xref_id is not None:
            query = query.values(master_xref_id=master_xref_id)
        if status is not None:
            query = query.values(ox_status=status)
        dbi.execute(query)

        object_xref_id = self.get_object_xref_id(
            ensembl_id, xref_id, ensembl_type, linkage_type, dbi, master_xref_id, status
        )
        return object_xref_id

    def biomart_fix(self, db_name: str, type1: str, type2: str, dbi: Connection) -> None:
        logging.info(
            f"{db_name} is associated with both {type1} and {type2} object types. Fixing."
        )

        # Figure out where to move xref to
        to_type, from_type, to_id, from_id = None, None, None, None
        if type1 == "Gene" or type2 == "Gene":
            to_type = "Gene"

            if type1 == "Translation" or type2 == "Translation":
                from_type = "Translation"
            else:
                from_type = "Transcript"
        else:
            to_type = "Transcript"
            from_type = "Translation"

        logging.info(f"Moving all associations from {from_type} to {to_type}")

        to_id = getattr(GeneTranscriptTranslationORM, to_type.lower() + "_id")
        from_id = getattr(GeneTranscriptTranslationORM, from_type.lower() + "_id")

        # Move the object xref
        query = (
            update(ObjectXrefUORM)
            .values(ensembl_object_type=to_type, ensembl_id=to_id)
            .where(
                ObjectXrefUORM.ensembl_object_type == from_type,
                ObjectXrefUORM.ensembl_id == from_id,
                XrefUORM.xref_id == ObjectXrefUORM.xref_id,
                XrefUORM.source_id == SourceUORM.source_id,
                ObjectXrefUORM.ox_status == "DUMP_OUT",
                SourceUORM.name == db_name,
            )
            .prefix_with("IGNORE")
        )
        dbi.execute(query)

        # Delete moved object xref
        query = (
            select(ObjectXrefUORM.object_xref_id)
            .outerjoin(
                IdentityXrefUORM,
                IdentityXrefUORM.object_xref_id == ObjectXrefUORM.object_xref_id,
            )
            .where(
                ObjectXrefUORM.ensembl_object_type == from_type,
                XrefUORM.xref_id == ObjectXrefUORM.xref_id,
                XrefUORM.source_id == SourceUORM.source_id,
                ObjectXrefUORM.ox_status == "DUMP_OUT",
                SourceUORM.name == db_name,
            )
        )
        for row in dbi.execute(query).mappings().all():
            dbi.execute(
                delete(ObjectXrefUORM).where(
                    ObjectXrefUORM.object_xref_id == row.object_xref_id
                )
            )
            dbi.execute(
                delete(IdentityXrefUORM).where(
                    IdentityXrefUORM.object_xref_id == row.object_xref_id
                )
            )

        # Delete dependent xref
        sub_query = select(ObjectXrefUORM.object_xref_id)
        query = delete(DependentXrefUORM).where(
            DependentXrefUORM.object_xref_id.not_in(sub_query)
        )
        dbi.execute(query)

    def update_object_xref_status(self, object_xref_id: int, status: str, dbi: Connection) -> None:
        query = (
            update(ObjectXrefUORM)
            .where(ObjectXrefUORM.object_xref_id == object_xref_id)
            .values(ox_status=status)
        )
        dbi.execute(query)
