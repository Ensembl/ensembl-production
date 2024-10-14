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

"""Base xref parser module to include all common functions used by xref parsers."""

from ensembl.production.xrefs.Base import *


class BaseParser(Base):
    """Class to represent the base of xref parser modules. Inherits the xref Base class."""

    def __init__(self, testing: bool = False) -> None:
        if not testing:
            super().__init__()

        self._direct_xref_tables = {
            "gene": GeneDirectXrefORM,
            "transcript": TranscriptDirectXrefORM,
            "translation": TranslationDirectXrefORM,
        }
        self._xref_dependent_mapped = {}

    def get_source_id_for_source_name(self, source_name: str, dbi: Connection, priority_desc: str = None) -> int:
        """Retrieves a source ID from its name and priority description from a database.

        Parameters
        ----------
        source_name: str
            The name of the source
        dbi: sqlalchemy.engine.Connection
            The database connection to query in
        priority_desc: str, optional
            The priority description of the source (default is None)

        Returns
        -------
        The source ID.

        Raises
        ------
        KeyError
          If no ID was found for the provided source name.
        """
        low_name = source_name.lower()

        if priority_desc:
            low_desc = priority_desc.lower()
            query = select(SourceUORM.source_id).where(
                func.lower(SourceUORM.name) == low_name,
                func.lower(SourceUORM.priority_description) == low_desc,
            )
            source_name = f"{source_name} ({priority_desc})"
        else:
            query = select(SourceUORM.source_id).where(
                func.lower(SourceUORM.name) == low_name
            )

        result = dbi.execute(query)
        if result:
            source_id = result.scalar()
        else:
            raise KeyError(f"No source_id for source_name={source_name}")

        return source_id

    def get_source_name_for_source_id(self, source_id: int, dbi: Connection) -> str:
        """Retrieves a source name from its ID from a database.

        Parameters
        ----------
        source_id: int
            The ID of the source
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        The source name.

        Raises
        ------
        KeyError
          If no name was found for the provided source ID.
        """
        result = dbi.execute(
            select(SourceUORM.name).where(SourceUORM.source_id == source_id)
        )
        if result:
            source_name = result.scalar()
        else:
            raise KeyError(
                f"There is no entity with source-id {source_id} in the source-table of the xref-database. The source-id and the name of the source-id is hard-coded in populate_metadata.sql and in the parser. Couldn't get source name for source ID {source_id}"
            )

        return source_name

    def set_release(self, source_id: int, s_release: str, dbi: Connection) -> None:
        """Sets the release value for a source in the source table of a database.

        Parameters
        ----------
        source_id: str
            The source ID
        s_release: str
            The release string
        dbi: sqlalchemy.engine.Connection
            The database connection to update in
        """
        dbi.execute(
            update(SourceUORM)
            .where(SourceUORM.source_id == source_id)
            .values(source_release=s_release)
        )

    def upload_xref_object_graphs(self, xrefs: List[Dict[str, Any]], dbi: Connection) -> None:
        """Adds xref data into a database.
        Uploads main xref data, related direct xrefs, dependent xrefs, and synonyms.

        Parameters
        ----------
        xrefs: list
            List of xrefs to upload
        dbi: sqlalchemy.engine.Connection
            The database connection to update in

        Raises
        ------
        IOError
            Failure is setting or retrieving an xref ID.
        """
        count = len(xrefs)
        if count:
            for xref in xrefs:
                if not xref.get("ACCESSION") or not xref.get("SOURCE_ID"):
                    continue

                # Create entry in xref table and get ID
                xref_id = self.add_xref(
                    {
                        "accession": xref["ACCESSION"],
                        "source_id": xref["SOURCE_ID"],
                        "species_id": xref["SPECIES_ID"],
                        "label": xref.get("LABEL", xref["ACCESSION"]),
                        "description": xref.get("DESCRIPTION"),
                        "version": xref.get("VERSION", 0),
                        "info_type": xref.get("INFO_TYPE", "MISC"),
                    },
                    dbi,
                    True,
                )

                # Add direct xrefs
                if xref.get("DIRECT_XREFS"):
                    for direct_xref in xref["DIRECT_XREFS"]:
                        direct_xref_id = self.add_xref(
                            {
                                "accession": xref["ACCESSION"],
                                "source_id": direct_xref["SOURCE_ID"],
                                "species_id": xref["SPECIES_ID"],
                                "label": xref.get("LABEL", xref["ACCESSION"]),
                                "description": xref.get("DESCRIPTION"),
                                "version": xref.get("VERSION", 0),
                                "info_type": direct_xref.get("LINKAGE_TYPE"),
                            },
                            dbi,
                            True,
                        )

                        # direct_xref_id = self.get_xref_id(xref['ACCESSION'], direct_xref['SOURCE_ID'], xref['SPECIES_ID'], dbi)
                        self.add_direct_xref(
                            direct_xref_id,
                            direct_xref["STABLE_ID"],
                            direct_xref["ENSEMBL_TYPE"],
                            direct_xref["LINKAGE_TYPE"],
                            dbi,
                        )

                # Error checking
                if not xref_id:
                    raise IOError(
                        "xref_id is not set for %s %s %s %s %s"
                        % (
                            xref["ACCESSION"],
                            xref["LABEL"],
                            xref["DESCRIPTION"],
                            xref["SOURCE_ID"],
                            xref["SPECIES_ID"],
                        )
                    )

                # Create entry in primary_xref table with sequence; if this is a "cumulative"
                # entry it may already exist, and require an UPDATE rather than an INSERT
                if xref.get("SEQUENCE"):
                    exists = dbi.execute(
                        select(PrimaryXrefORM.xref_id).where(
                            PrimaryXrefORM.xref_id == xref_id
                        )
                    ).scalar()

                    if exists:
                        query = (
                            update(PrimaryXrefORM)
                            .where(PrimaryXrefORM.xref_id == xref_id)
                            .values(sequence=xref["SEQUENCE"])
                        )
                    else:
                        query = insert(PrimaryXrefORM).values(
                            xref_id=xref_id,
                            sequence=xref["SEQUENCE"],
                            sequence_type=xref["SEQUENCE_TYPE"],
                            status=xref.get("STATUS"),
                        )
                    dbi.execute(query)

                # If there are synonyms, add entries in the synonym table
                if xref.get("SYNONYMS"):
                    for synonym in xref["SYNONYMS"]:
                        self.add_synonym(xref_id, synonym, dbi)

                # If there are dependent xrefs, add xrefs and dependent xrefs for them
                if xref.get("DEPENDENT_XREFS"):
                    for dependent_xref in xref.get("DEPENDENT_XREFS"):
                        # Insert the xref and get its xref_id
                        dependent_xref_id = self.add_xref(
                            {
                                "accession": dependent_xref["ACCESSION"],
                                "source_id": dependent_xref["SOURCE_ID"],
                                "species_id": xref["SPECIES_ID"],
                                "label": dependent_xref.get("LABEL"),
                                "description": dependent_xref.get("DESCRIPTION"),
                                "version": dependent_xref.get("VERSION"),
                                "info_type": "DEPENDENT",
                            },
                            dbi,
                        )
                        if not dependent_xref_id:
                            continue

                        # Add the linkage_annotation and source id it came from
                        self.add_dependent_xref_maponly(
                            dependent_xref_id,
                            dependent_xref["LINKAGE_SOURCE_ID"],
                            xref_id,
                            dependent_xref.get("LINKAGE_ANNOTATION"),
                            dbi,
                        )

                        # If there are synonyms, add entries in the synonym table
                        if dependent_xref.get("SYNONYMS"):
                            for synonym in dependent_xref.get("SYNONYMS"):
                                self.add_synonym(dependent_xref_id, synonym, dbi)

                # Add the pair data. refseq dna/pep pairs usually
                if xref_id and xref.get("PAIR"):
                    dbi.execute(
                        insert(PairsORM).values(
                            source_id=xref["SOURCE_ID"],
                            accession1=xref["ACCESSION"],
                            accession2=xref["PAIR"],
                        )
                    )

    def get_xref_id(self, accession: str, source_id: int, species_id: int, dbi: Connection) -> Optional[int]:
        """Retrieves the xref row ID from accession, source ID, and species ID.

        Parameters
        ----------
        accession: str
            The xref accession
        source_id: int
            The xref source ID
        species_id: int
            The species ID
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        The xref ID, if found (else None).
        """
        xref_ids = []

        query = select(XrefUORM.xref_id).where(
            XrefUORM.accession == accession,
            XrefUORM.source_id == source_id,
            XrefUORM.species_id == species_id,
        )

        for row in dbi.execute(query).mappings().all():
            xref_ids.append(row.xref_id)

        if len(xref_ids) > 0:
            return xref_ids[0]

        return None

    def add_direct_xref(self, general_xref_id: int, ensembl_stable_id: str, ensembl_type: str, linkage_type: str, dbi: Connection) -> None:
        """Adds data into direct xref tables in a database.

        Parameters
        ----------
        general_xref_id: int
            The xref ID related to the direct xref
        ensembl_stable_id: str
            The ensEMBL stable ID related to the direct xref
        ensembl_type: str
            The feature type (gene, transcript, or translation)
        linkage_type: str
            The type of link between the xref and ensEMBL feature
        dbi: sqlalchemy.engine.Connection
            The database connection to update in
        """
        # Check if such a mapping exists yet
        existing_xref_ids = self.get_direct_xref_id(
            ensembl_stable_id, ensembl_type, linkage_type, dbi
        )
        if general_xref_id in existing_xref_ids:
            return None

        ensembl_type = ensembl_type.lower()
        dbi.execute(
            insert(self._direct_xref_tables[ensembl_type]).values(
                general_xref_id=general_xref_id,
                ensembl_stable_id=ensembl_stable_id,
                linkage_xref=linkage_type,
            )
        )

    def add_to_direct_xrefs(self, args: Dict[str, Any], dbi: Connection) -> None:
        """Adds direct xref data into both the xref table and direct xref tables in a database.
        This calls the functions add_xref and add_direct_xref.

        Parameters
        ----------
        args: dict
            The direct xref arguments. These include:
            - stable_id: The ensEMBL feature stable ID
            - ensembl_type: The feature type (gene, transcript, or translation)
            - accession: The xref accession
            - source_id: The xref source ID
            - species_id: The species ID
            - version (optional): The xref version (default is 0)
            - label (optional): The xref label (default is the xref accession)
            - description (optional): The xref description
            - linkage (optional): The type of link between the xref and ensEMBL
            - info_text (optional): Additional info related to the xref (default is empty string)
            - info_type (optional): The type of xref being added (default is DIRECT)
        dbi: sqlalchemy.engine.Connection
            The database connection to update in
        """
        stable_id = args["stable_id"]
        ensembl_type = args["ensembl_type"]
        accession = args["accession"]
        source_id = args["source_id"]
        species_id = args["species_id"]
        version = args.get("version", 0)
        label = args.get("label", accession)
        description = args.get("description")
        linkage = args.get("linkage")
        info_text = args.get("info_text", "")

        args["info_type"] = args.get("info_type", "DIRECT")

        # If the accession already has an xref find it else cretae a new one
        direct_xref_id = self.add_xref(args, dbi)
        self.add_direct_xref(direct_xref_id, stable_id, ensembl_type, linkage, dbi)

    def get_direct_xref_id(self, stable_id: str, ensembl_type: str, link: str, dbi: Connection) -> int:
        """Retrieves the direct xref row ID from stable ID, ensEMBL type and linkage type.

        Parameters
        ----------
        stable_id: str
            The ensEMBL feature stable ID
        ensembl_type: str
            The feature type (gene, transcript, or translation)
        link: str
            The type of link between the xref and ensEMBL
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        The direct xref ID(s).
        """
        direct_xref_ids = []

        ensembl_type = ensembl_type.lower()
        ensembl_table = self._direct_xref_tables[ensembl_type]
        query = select(ensembl_table.general_xref_id).where(
            ensembl_table.ensembl_stable_id == stable_id,
            ensembl_table.linkage_xref == link,
        )

        for row in dbi.execute(query).mappings().all():
            direct_xref_ids.append(row.general_xref_id)

        return direct_xref_ids

    def add_xref(self, args: Dict[str, Any], dbi: Connection, update_label_desc: bool = False) -> int:
        """Adds data into xref table in a database and returns the xref ID.
        This function first checks if an xref already exists with the provided data.

        Parameters
        ----------
        args: dict
            The direct xref arguments. These include:
            - accession: The xref accession
            - source_id: The xref source ID
            - species_id: The species ID
            - label (optional): The xref label (default is the xref accession)
            - description (optional): The xref description
            - version (optional): The xref version (default is 0)
            - info_type (optional): The type of xref being added (default is MISC)
            - info_text (optional): Additional info related to the xref (default is empty string)
        dbi: sqlalchemy.engine.Connection
            The database connection to update in
        update_label_desc: bool, optional
            If set to True, the xref label and description will be updated even if the xref data already exists in the database (default is False)

        Returns
        -------
        The xref ID (existing or newly added).
        """
        accession = args["accession"]
        source_id = args["source_id"]
        species_id = args["species_id"]
        label = args.get("label", accession)
        description = args.get("description")
        version = args.get("version", 0)
        info_type = args.get("info_type", "MISC")
        info_text = args.get("info_text", "")

        # If the description is more than 255 characters, chop it off and add
        # an indication that it has been truncated to the end of it.
        if description and len(description) > 255:
            description = description[0:249] + " /.../"

        # See if it already exists. If so return the xref_id for this one.
        xref_id = self.get_xref_id(accession, source_id, species_id, dbi)
        if xref_id:
            if update_label_desc:
                if label:
                    dbi.execute(
                        update(XrefUORM)
                        .where(XrefUORM.xref_id == xref_id)
                        .values(label=label)
                    )
                if description:
                    dbi.execute(
                        update(XrefUORM)
                        .where(XrefUORM.xref_id == xref_id)
                        .values(description=description)
                    )
            return xref_id

        # Add new xref
        dbi.execute(
            insert(XrefUORM).values(
                accession=accession,
                version=version,
                label=label,
                description=description,
                source_id=source_id,
                species_id=species_id,
                info_type=info_type,
                info_text=info_text,
            )
        )

        xref_id = self.get_xref_id(accession, source_id, species_id, dbi)
        return xref_id

    def add_dependent_xref(self, args: Dict[str, Any], dbi: Connection) -> int:
        """Adds data into the xref table and dependent xref table in a database.

        Parameters
        ----------
        args: dict
            The direct xref arguments. These include:
            - master_xref_id: The main xref ID which the dependent xref is dependent on
            - accession: The dependent xref accession
            - source_id: The dependent xref source ID
            - species_id: The species ID
            - version (optional): The dependent xref version (default is 0)
            - label (optional): The dependent xref label (default is the dependent xref accession)
            - description (optional): The dependent xref description
            - linkage (optional): The source ID of the main xref which the dependent xref id dependent on
            - info_text (optional): Additional info related to the dependent xref (default is empty string)
            - info_type (optional): The type of xref being added (default is DEPENDENT)
        dbi: sqlalchemy.engine.Connection
            The database connection to update in

        Returns
        -------
        The dependent xref ID.
        """
        master_xref_id = args["master_xref_id"]
        accession = args["accession"]
        source_id = args["source_id"]
        species_id = args["species_id"]
        version = args.get("version", 0)
        label = args.get("label", accession)
        description = args.get("description")
        linkage = args.get("linkage")
        info_text = args.get("info_text", "")

        args["info_type"] = args.get("info_type", "DEPENDENT")

        # If the accession already has an xref find it else cretae a new one
        dependent_xref_id = self.add_xref(args, dbi)
        self.add_dependent_xref_maponly(
            dependent_xref_id, source_id, master_xref_id, linkage, dbi
        )

        return dependent_xref_id

    def add_dependent_xref_maponly(self, dependent_id: int, dependent_source_id: int, master_id: int, master_source_id: int, dbi: Connection, update_info_type: bool = False) -> None:
        """Adds data into the dependent xref table in a database.
        This function only adds the dependent connection if it hasn't been added before (from a cache).

        Parameters
        ----------
        dependent_id: int
            The dependent xref ID
        dependent_source_id: int
            The source ID of the dependent xref
        master_id: int
            The master xref ID
        master_source_id: int
            The source ID of the master xref
        dbi: sqlalchemy.engine.Connection
            The database connection to update in
        update_info_type: bool, optional
            If set to True, the info_type column of the xref table related to the dependent xref will be updated to 'DEPENDENT' (default is False)
        """
        index = f"{master_id}|{dependent_id}"
        if (
            not self._xref_dependent_mapped.get(index)
            or self._xref_dependent_mapped[index] != master_source_id
        ):
            dbi.execute(
                insert(DependentXrefUORM)
                .values(
                    master_xref_id=master_id,
                    dependent_xref_id=dependent_id,
                    linkage_annotation=master_source_id,
                    linkage_source_id=dependent_source_id,
                )
                .prefix_with("IGNORE")
            )

            self._xref_dependent_mapped[index] = master_source_id

        if update_info_type:
            self._update_xref_info_type(dependent_id, "DEPENDENT", dbi)

    def _update_xref_info_type(self, xref_id: int, info_type: str, dbi: Connection) -> None:
        """Updates the info_type column of the xref table.

        Parameters
        ----------
        xref_id: int
            The xref ID
        info_type: str
            The info type value to update
        dbi: sqlalchemy.engine.Connection
            The database connection to update in
        """
        dbi.execute(
            update(XrefUORM)
            .where(XrefUORM.xref_id == xref_id)
            .values(info_type=info_type)
        )

    def get_xref_sources(self, dbi: Connection) -> Dict[str, int]:
        """Retrieves the xref source names and ID from a database.

        Parameters
        ----------
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        A dict variable containing {'source_name' : 'source_ID'} items.
        """
        sourcename_to_sourceid = {}

        query = select(SourceUORM.name, SourceUORM.source_id)

        for row in dbi.execute(query).mappings().all():
            sourcename_to_sourceid[row.name] = row.source_id

        return sourcename_to_sourceid

    def add_synonym(self, xref_id: int, synonym: str, dbi: Connection) -> None:
        """Adds synonym data into the synonym table if a database.

        Parameters
        ----------
        xref_id: int
            The xref ID related to the synonym
        synonym: str
            The xref synonym
        dbi: sqlalchemy.engine.Connection
            The database connection to update in
        """
        dbi.execute(
            insert(SynonymORM)
            .values(xref_id=xref_id, synonym=synonym)
            .prefix_with("IGNORE")
        )

    def get_ext_synonyms(self, source_name: str, dbi: Connection) -> Dict[str, List[str]]:
        """Retrieves the list of synonyms for a specific xref source.

        Parameters
        ----------
        source_name: str
            The xref source name
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        A dict variable containing {'accession' or 'label' : [list of synonyms]} items.
        """
        ext_syns = {}
        seen = {}
        separator = ":"

        query = (
            select(XrefUORM.accession, XrefUORM.label, SynonymORM.synonym)
            .where(
                XrefUORM.xref_id == SynonymORM.xref_id,
                SourceUORM.source_id == XrefUORM.source_id,
            )
            .filter(SourceUORM.name.like(source_name))
        )

        count = 0
        for row in dbi.execute(query).mappings().all():
            acc_syn = row.accession + separator + row.synonym
            if not seen.get(acc_syn):
                ext_syns.setdefault(row.accession, []).append(row.synonym)
                ext_syns.setdefault(row.label, []).append(row.synonym)
                count += 1

            seen[acc_syn] = 1

        return ext_syns

    def build_dependent_mappings(self, source_id: int, dbi: Connection) -> None:
        """Builds the dependent mappings cache for a specific xref source.
        The resulting cache is a dict variable containing {'master_xref_id|dependent_xref_id' : 'linkage_annotation'} items.

        Parameters
        ----------
        source_id: int
            The xref source ID
        dbi: sqlalchemy.engine.Connection
            The database connection to query in
        """
        query = select(
            DependentXrefUORM.master_xref_id,
            DependentXrefUORM.dependent_xref_id,
            DependentXrefUORM.linkage_annotation,
        ).where(
            DependentXrefUORM.dependent_xref_id == XrefUORM.xref_id,
            XrefUORM.source_id == source_id,
        )

        for row in dbi.execute(query).mappings().all():
            self._xref_dependent_mapped[
                row.master_xref_id + "|" + row.dependent_xref_id
            ] = row.linkage_annotation

    def get_valid_codes(self, source_name: str, species_id: int, dbi: Connection) -> Dict[str, List[int]]:
        """Retrieves the xref accessions and IDs related to a specific xref source and species from a database.

        Parameters
        ----------
        source_name: str
            The xref source name
        species_id: int
            The species ID
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        A dict variable containing {'accession' : [list of xref IDs]} items.
        """
        valid_codes = {}
        sources = []

        big_name = "%" + source_name.upper() + "%"
        query = select(SourceUORM.source_id).filter(
            func.upper(SourceUORM.name).like(big_name)
        )
        for row in dbi.execute(query).fetchall():
            sources.append(row[0])

        for source_id in sources:
            query = select(XrefUORM.accession, XrefUORM.xref_id).where(
                XrefUORM.species_id == species_id, XrefUORM.source_id == source_id
            )
            for row in dbi.execute(query).fetchall():
                valid_codes.setdefault(row[0], []).append(row[1])

        return valid_codes

    def is_file_header_valid(self, columns_count: int, field_patterns: List[str], header: List[str], case_sensitive: bool = False) -> bool:
        """Checks whether the provided file header is valid by checking length and column patterns.

        Parameters
        ----------
        columns_count: int
            The number of columns to be expected in the header
        field_patterns: list
            The column patterns for the header to satisfy
        header: list
            The file header to check
        case_sensitive: bool, optional
            If set to True, header fieled will be parsed as is, as opposed to lower-case (default is False)

        Returns
        -------
        1 is the header is valid.
        0 if the header is not valid.
        """
        # Check number of columns
        if len(header) < columns_count:
            return False

        # Check column patterns
        for pattern in field_patterns:
            header_field = header.pop(0)
            if not case_sensitive:
                header_field = header_field.lower()
            if pattern and not re.search(pattern, header_field):
                return False

        # If we have made it this far, all should be in order
        return True

    def add_to_syn(self, accession: str, source_id: int, synonym: str, species_id: int, dbi: Connection) -> None:
        """Add synomyn data for an xref given its accession and source ID.

        Parameters
        ----------
        accession: str
            The xref accession
        source_id: int
            The xref source ID
        synonym: str
            The xref synonym
        species_id: int
            The species ID
        dbi: sqlalchemy.engine.Connection
            The database connection to update in

        Raises
        ------
        KeyError
            If no xref is found for accession, source ID, and species ID.
        """
        xref_id = self.get_xref_id(accession, source_id, species_id, dbi)
        if xref_id:
            self.add_synonym(xref_id, synonym, dbi)
        else:
            raise KeyError(
                f"Could not find acc {accession} in xref table source = {source_id} of species {species_id}"
            )

    def add_to_syn_for_mult_sources(self, accession: str, sources: List[int], synonym: str, species_id: int, dbi: Connection) -> None:
        """Adds synonym data for multiple sources.

        Parameters
        ----------
        accession: str
            The xref accession
        sources: list
            List of xref sources to add synonyms for
        synonym: str
            The xref synonym
        species_id: int
            The species ID
        dbi: sqlalchemy.engine.Connection
            The database connection to update in
        """
        for source_id in sources:
            xref_id = self.get_xref_id(accession, source_id, species_id, dbi)
            if xref_id:
                self.add_synonym(xref_id, synonym, dbi)

    def species_id_to_names(self, dbi: Connection) -> Dict[int, List[str]]:
        """Creates a dictionary that contains the name and aliases for every species ID.

        Parameters
        ----------
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        A dict variable containing {'species_id' : [list of names/synonyms]} items.
        """
        id_to_names = {}

        # Query the species table
        query = select(SpeciesORM.species_id, SpeciesORM.name)
        for row in dbi.execute(query).mappings().all():
            id_to_names[row.species_id] = [row.name]

        # Also populate the dict with all the aliases
        query = select(SpeciesORM.species_id, SpeciesORM.aliases)
        for row in dbi.execute(query).mappings().all():
            for name in re.split(r",\s*", row.aliases, flags=re.MULTILINE | re.DOTALL):
                id_to_names.setdefault(row.species_id, []).append(name)

        return id_to_names

    def species_id_to_taxonomy(self, dbi: Connection) -> Dict[int, List[int]]:
        """Creates a dictionary that contains the taxonomy IDs for every species ID.

        Parameters
        ----------
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        A dict variable containing {'species_id' : [list of taxonomy IDs]} items.
        """
        id_to_taxonomy = {}

        # Query the species table
        query = select(SpeciesORM.species_id, SpeciesORM.taxonomy_id)
        for row in dbi.execute(query).mappings().all():
            id_to_taxonomy.setdefault(row.species_id, []).append(row.taxonomy_id)

        return id_to_taxonomy

    def get_valid_xrefs_for_dependencies(self, dependent_name: str, reverse_ordered_source_list: List[str], dbi: Connection) -> Dict[str, int]:
        """Get a hash to go from accession of a dependent xref to master_xref_id for all of source names given.

        Parameters
        ----------
        dependent_name: str
            The dependent source name
        reverse_ordered_source_list: list
            List of source names
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        A dict variable containing {'accession' : 'master_xred_id'} items.
        """
        dependent_2_xref = {}
        dependent_sources = []
        sources = []

        query = select(SourceUORM.source_id).where(
            func.lower(SourceUORM.name) == dependent_name.lower()
        )
        for row in dbi.execute(query).fetchall():
            dependent_sources.append(row[0])

        for name in reverse_ordered_source_list:
            query = select(SourceUORM.source_id).where(
                func.lower(SourceUORM.name) == name.lower()
            )
            for row in dbi.execute(query).fetchall():
                sources.append(row[0])

        Xref1 = aliased(XrefUORM)
        Xref2 = aliased(XrefUORM)

        for dependent in dependent_sources:
            for source in sources:
                query = select(DependentXrefUORM.master_xref_id, Xref2.accession).where(
                    Xref1.xref_id == DependentXrefUORM.master_xref_id,
                    Xref1.source_id == source,
                    Xref2.xref_id == DependentXrefUORM.dependent_xref_id,
                    Xref2.source_id == dependent,
                )
                for row in dbi.execute(query).fetchall():
                    dependent_2_xref[row[1]] = row[0]

        return dependent_2_xref

    def get_source_ids_for_source_name_pattern(self, source_name: str, dbi: Connection) -> List[int]:
        """Gets a set of source IDs matching a source name pattern.

        Parameters
        ----------
        source_name: str
            The name of the source
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        A list of source IDs.
        """
        big_name = "%" + source_name.upper() + "%"
        sources = []

        query = select(SourceUORM.source_id).where(
            func.upper(SourceUORM.name).like(big_name)
        )
        for row in dbi.execute(query).fetchall():
            sources.append(row[0])

        return sources

    def get_acc_to_label(self, source_name: str, species_id: int, dbi: Connection) -> Dict[str, str]:
        """Creates a hash that uses the accession as a key and the label as the value.

        Parameters
        ----------
        source_name: str
            The name of the source
        species_id: int
            The species ID
        dbi: sqlalchemy.engine.Connection
            The database connection to query in

        Returns
        -------
        A dict variable containing {'accession' : 'label'} items.
        """
        acc_to_label = {}

        source_name = source_name + "%"
        query = select(XrefUORM.accession, XrefUORM.label).where(
            XrefUORM.source_id == SourceUORM.source_id,
            SourceUORM.name.like(source_name),
            XrefUORM.species_id == species_id,
        )
        for row in dbi.execute(query).mappings().all():
            acc_to_label[row.accession] = row.label

        return acc_to_label

    def extract_params_from_string(self, string: str, parameters: List[str]) -> List[str]:
        values = []

        for param in parameters:
            val = None

            match = re.search(param + r"[=][>](\S+?)[,]", string)
            if match:
                val = match.group(1)

            values.append(val)

        return values
