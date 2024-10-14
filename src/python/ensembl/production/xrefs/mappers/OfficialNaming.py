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

"""Mapper module for setting the feature names."""

from ensembl.production.xrefs.mappers.BasicMapper import *


class OfficialNaming(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        self._official_name = mapper.official_name()
        mapper.set_up_logging()

    def official_name(self, official_name: str = None) -> str:
        if official_name:
            self._official_name = official_name

        return self._official_name

    def run(self, species_id: int, verbose: bool) -> None:
        logging.info("Starting official naming")

        # If no offical name then we do not want to go any further
        dbname = self.official_name()
        if not dbname:
            self.update_process_status("official_naming_done")
            return

        xref_dbi = self.xref().connect()

        # If there are any official names on transcripts or translations, move them onto gene level
        if dbname == "MGI":
            self.biomart_fix("MGI", "Translation", "Gene", xref_dbi)
            self.biomart_fix("MGI", "Transcript", "Gene", xref_dbi)
        if dbname == "ZFIN_ID":
            self.biomart_fix("ZFIN_ID", "Translation", "Gene", xref_dbi)
            self.biomart_fix("ZFIN_ID", "Transcript", "Gene", xref_dbi)
        if dbname == "RGD":
            self.biomart_fix("RGD", "Translation", "Gene", xref_dbi)
            self.biomart_fix("RGD", "Transcript", "Gene", xref_dbi)

        # Get the current max values for xref and object_xref
        max_xref_id = xref_dbi.execute(select(func.max(XrefUORM.xref_id))).scalar()
        max_xref_id = int(max_xref_id)
        max_object_xref_id = xref_dbi.execute(
            select(func.max(ObjectXrefUORM.object_xref_id))
        ).scalar()
        max_object_xref_id = int(max_object_xref_id)

        # Get labels, descriptions, and synonyms
        display_label_to_desc = self.get_display_label_data(dbname, xref_dbi)
        synonyms = self.get_synonyms(dbname, xref_dbi)

        # Get source IDs
        dbname_to_source_id = self.get_dbname_to_source_id(dbname, xref_id)

        # Reset gene and transcript stable id display data
        self.reset_display_xrefs(xref_dbi)

        # Get the gene and transcript stable IDs and internal IDs
        gene_to_transcripts, gene_id_to_stable_id, tran_id_to_stable_id = {}, {}, {}
        sorted_gene_ids = []

        query = (
            select(
                GeneTranscriptTranslationORM.gene_id,
                GeneTranscriptTranslationORM.transcript_id,
                GeneStableIdORM.stable_id.label("gene_stable_id"),
                TranscriptStableIdORM.stable_id.label("transcript_stable_id"),
            )
            .where(
                GeneTranscriptTranslationORM.gene_id == GeneStableIdORM.internal_id,
                GeneTranscriptTranslationORM.transcript_id
                == TranscriptStableIdORM.internal_id,
            )
            .order_by(GeneStableIdORM.stable_id, TranscriptStableIdORM.stable_id)
        )
        for row in xref_dbi.execute(query).mappings().all():
            if not gene_to_transcripts.get(row.gene_id):
                sorted_gene_ids.append(row.gene_id)

            gene_to_transcripts.setdefault(row.gene_id, []).append(row.transcript_id)
            gene_id_to_stable_id[row.gene_id] = row.gene_stable_id
            tran_id_to_stable_id[row.transcript_id] = row.transcript_stable_id

        # Get the object xref IDs that we should ignore (EntrezGene xref dependent on RefSeq_predicted xrefs)
        ignore_object = {}

        MasterXref = aliased(XrefUORM)
        DependentXref = aliased(XrefUORM)

        MasterSource = aliased(SourceUORM)
        DependentSource = aliased(SourceUORM)

        query = select(ObjectXrefUORM.object_xref_id.distinct()).where(
            ObjectXrefUORM.xref_id == DependentXrefUORM.dependent_xref_id,
            DependentXrefUORM.dependent_xref_id == DependentXref.xref_id,
            DependentXrefUORM.master_xref_id == MasterXref.xref_id,
            MasterXref.source_id == MasterSource.source_id,
            DependentXref.source_id == DependentSource.source_id,
            MasterSource.name.like("Refseq%predicted"),
            DependentSource.name.like("EntrezGene"),
            ObjectXrefUORM.ox_status == "DUMP_OUT",
        )
        for row in xref_dbi.execute(query).mappings().all():
            ignore_object[row.object_xref_id] = 1

        xref_added, seen_gene, official_name_used = {}, {}, {}

        # Go through all genes
        for gene_id in sorted_gene_ids:
            transcript_source = dbname
            gene_symbol, gene_symbol_xref_id, is_lrg = None, None, 0

            # Get offical name if it has one
            gene_symbol, gene_symbol_xref_id = self.get_official_domain_name(
                {
                    "gene_id": gene_id,
                    "gene_id_to_stable_id": gene_id_to_stable_id,
                    "official_name_used": official_name_used,
                    "dbname": dbname,
                    "verbose": verbose,
                },
                xref_dbi,
            )

            if gene_symbol_xref_id:
                official_name_used[gene_symbol_xref_id] = 1

            # If not found see if there is an LRG entry
            if not gene_symbol:
                gene_symbol, gene_symbol_xref_id, is_lrg = self.find_lrg_hgnc(
                    gene_id, xref_dbi
                )

            # If not found look for other valid database sources (RFAM and miRBase, EntrezGene)
            if not gene_symbol:
                (
                    gene_symbol,
                    gene_symbol_xref_id,
                    transcript_source,
                    display_label_to_desc,
                ) = self.find_from_other_sources(
                    ignore_object,
                    {
                        "gene_id": gene_id,
                        "display_label_to_desc": display_label_to_desc,
                        "transcript_source": transcript_source,
                    },
                    xref_dbi,
                )

            if gene_symbol:
                description = display_label_to_desc.get(gene_symbol)
                xref_dbi.execute(
                    update(GeneStableIdORM)
                    .where(GeneStableIdORM.internal_id == gene_id)
                    .values(display_xref_id=gene_symbol_xref_id)
                )

                if not is_lrg:
                    # Set transcript names
                    max_xref_id, max_object_xref_id, xref_added, seen_gene = (
                        self.set_transcript_display_xrefs(
                            {
                                "max_xref_id": max_xref_id,
                                "max_object_xref_id": max_object_xref_id,
                                "gene_id": gene_id,
                                "gene_id_to_stable_id": gene_id_to_stable_id,
                                "gene_symbol": gene_symbol,
                                "description": description,
                                "source_id": dbname_to_source_id.get(
                                    f"{transcript_source}_trans_name"
                                ),
                                "xref_added": xref_added,
                                "seen_gene": seen_gene,
                                "transcript_ids": gene_to_transcripts.get(gene_id, []),
                                "transcript_source": transcript_source,
                                "species_id": species_id,
                            },
                            xref_dbi,
                        )
                    )

        xref_dbi.close()

        self.update_process_status("official_naming_done")

    def get_display_label_data(self, dbname: str, dbi: Connection) -> Dict[str, str]:
        label_to_desc = {}

        # Connect synonyms to xref descriptions
        query = select(SynonymORM.synonym, XrefUORM.description).where(
            XrefUORM.xref_id == SynonymORM.xref_id,
            SourceUORM.source_id == XrefUORM.source_id,
            SourceUORM.name.like(dbname),
        )
        for row in dbi.execute(query).mappings().all():
            label_to_desc[row.synonym] = row.description

        # Connect display labels to xref descriptions
        no_descriptions = 0
        query = select(XrefUORM.label, XrefUORM.description).where(
            XrefUORM.source_id == SourceUORM.source_id, SourceUORM.name.like(dbname)
        )
        for row in dbi.execute(query).mappings().all():
            if not row.description:
                no_descriptions += 1
            else:
                label_to_desc[row.label] = row.description

        if no_descriptions:
            logging.warn(f"Descriptions not defined for {no_descriptions} labels")

        return label_to_desc

    def get_synonyms(self, dbname: str, dbi: Connection) -> Dict[str, str]:
        synonyms = {}

        # Connect synonyms with xref labels
        query = select(SynonymORM.synonym, XrefUORM.label).where(
            XrefUORM.xref_id == SynonymORM.xref_id,
            SourceUORM.source_id == XrefUORM.source_id,
            SourceUORM.name.like(dbname),
        )
        for row in dbi.execute(query).mappings().all():
            synonyms[row.synonym] = row.label

        return synonyms

    def get_dbname_to_source_id(self, dbname: str, dbi: Connection) -> Dict[str, int]:
        dbname_to_source_id = {}

        sources_list = [
            "RFAM_trans_name",
            "miRBase_trans_name",
            "EntrezGene_trans_name",
        ]
        sources_list.append(f"{dbname}_trans_name")
        sources_list.append(dbname)

        source_error = 0
        for source_name in sources_list:
            source_id = dbi.execute(
                select(SourceUORM.source_id).where(SourceUORM.name.like(source_name))
            ).scalar()

            if not source_id:
                logging.warn(f"Could not find external database '{source_name}'")
                source_error += 1
            else:
                dbname_to_source_id[source_name] = source_id

        if source_error:
            raise LookupError(
                f"Could not find name for {source_error} databases. Therefore Exiting. Please add these sources"
            )

        return dbname_to_source_id

    def reset_display_xrefs(self, dbi: Connection) -> None:
        dbi.execute(update(TranscriptStableIdORM).values(display_xref_id=None))

        dbi.execute(update(GeneStableIdORM).values(display_xref_id=None, desc_set=0))

    def get_official_domain_name(self, args: Dict[str, Any], dbi: Connection) -> Tuple[str, int]:
        gene_id = args["gene_id"]
        gene_id_to_stable_id = args["gene_id_to_stable_id"]
        official_name_used = args["official_name_used"]
        dbname = args["dbname"]
        verbose = args["verbose"]

        gene_symbol, gene_symbol_xref_id = None, None
        display_names, xref_id_to_display = {}, {}
        best_level, name_count = 999, 0
        xref_ids_list, object_xref_ids_list = [], []

        # Get the display labels mapped to the gene ID, and extract the ones with the highest priority
        query = select(
            XrefUORM.label,
            XrefUORM.xref_id,
            ObjectXrefUORM.object_xref_id,
            SourceUORM.priority,
        ).where(
            XrefUORM.xref_id == ObjectXrefUORM.xref_id,
            XrefUORM.source_id == SourceUORM.source_id,
            SourceUORM.name == dbname,
            ObjectXrefUORM.ox_status == "DUMP_OUT",
            ObjectXrefUORM.ensembl_id == gene_id,
            ObjectXrefUORM.ensembl_object_type == "Gene",
        )
        for row in dbi.execute(query).mappings().all():
            xref_ids_list.append(row.xref_id)
            object_xref_ids_list.append(row.object_xref_id)
            xref_id_to_display[row.xref_id] = row.label

            name_count += 1

            if row.priority < best_level:
                display_names.clear()
                display_names[row.xref_id] = 1
                best_level = row.priority
            elif row.priority == best_level:
                display_names[row.xref_id] = 1

        # Check if the best names has been found, and remove the others if so
        if name_count > 1 and len(display_names) == 1:
            if verbose:
                logging.info(
                    f"For gene {gene_id_to_stable_id[gene_id]}, we have multiple {dbname} names"
                )

            gene_symbol, gene_symbol_xref_id = self.set_the_best_display_name(
                display_names,
                xref_ids_list,
                object_xref_ids_list,
                xref_id_to_display,
                verbose,
                dbi,
            )
            if gene_symbol:
                return gene_symbol, gene_symbol_xref_id

        # Perfect case, one best name found
        if len(display_names) == 1:
            xref_id = display_names.keys()[0]
            return xref_id_to_display[xref_id], xref_id

        # Try to find the best names out of multiple ones
        if len(display_names) > 1:
            temp_best_identity = 0
            best_ids, best_list = [], []

            # Fail xrefs with worse % identity if we can (query or target identity whichever is greater)
            case_stmt = case(
                [
                    (
                        IdentityXrefUORM.query_identity
                        >= IdentityXrefUORM.target_identity,
                        IdentityXrefUORM.query_identity,
                    )
                ],
                else_=IdentityXrefUORM.target_identity,
            ).label("best_identity")
            query = (
                select(XrefUORM.xref_id, case_stmt)
                .where(
                    XrefUORM.xref_id == ObjectXrefUORM.xref_id,
                    XrefUORM.source_id == SourceUORM.source_id,
                    ObjectXrefUORM.object_xref_id == IdentityXrefUORM.object_xref_id,
                    SourceUORM.name == dbname,
                    ObjectXrefUORM.ox_status == "DUMP_OUT",
                    ObjectXrefUORM.ensembl_id == gene_id,
                    ObjectXrefUORM.ensembl_object_type == "Gene",
                )
                .order_by(desc("best_identity"))
            )
            for row in dbi.execute(query).mappings().all():
                if row.best_identity > temp_best_identity:
                    best_ids.clear()
                    best_ids[row.xref_id] = 1
                    temp_best_identity = row.best_identity
                elif row.best_identity == temp_best_identity:
                    best_ids[row.xref_id] = 1
                else:
                    break

            for xref_id in display_names.keys():
                best_list[xref_id_to_display[xref_id]] = 1

            # Check if we were able to reduce the number of xrefs based on % identity
            if len(best_ids) > 0 and len(best_ids) < len(display_names):
                display_names = best_ids
                if verbose:
                    logging.info(
                        f"For gene {gene_id_to_stable_id[gene_id]}, we have multiple {dbname} names"
                    )

                gene_symbol, gene_symbol_xref_id = self.set_the_best_display_name(
                    display_names,
                    xref_ids_list,
                    object_xref_ids_list,
                    xref_id_to_display,
                    verbose,
                    dbi,
                )
                if gene_symbol and len(display_names) == 1:
                    return gene_symbol, gene_symbol_xref_id

            # Take the name which hasn't been already assigned to another gene, if possible
            xref_not_used = None
            for xref_id in display_names.keys():
                if not official_name_used.get(xref_id):
                    xref_not_used = xref_id

            if xref_not_used:
                if verbose:
                    logging.info(f"For gene {gene_id_to_stable_id[gene_id]}:")
                for xref_id in display_names.keys():
                    if xref_id == xref_not_used:
                        if verbose:
                            logging.info(f"\t{xref_id_to_display[xref_id]} chosen")
                        gene_symbol = xref_id_to_display[xref_id]
                        gene_symbol_xref_id = xref_id
                    else:
                        if verbose:
                            logging.info(
                                f"\t{xref_id_to_display[xref_id]} (left as {dbname} reference but not gene symbol)"
                            )
            else:
                index = 0
                for xref_id in display_names.keys():
                    if not index:
                        if verbose:
                            logging.info(
                                f"\t{xref_id_to_display[xref_id]} chosen as first"
                            )
                        gene_symbol = xref_id_to_display[xref_id]
                        gene_symbol_xref_id = xref_id
                    else:
                        if verbose:
                            logging.info(
                                f"\t{xref_id_to_display[xref_id]} (left as {dbname} reference but not gene symbol)"
                            )
                    index += 1

        return gene_symbol, gene_symbol_xref_id

    def set_the_best_display_name(self, display_names: Dict[int, int], xref_list: List[int], object_xref_list: List[int], xref_id_to_display: Dict[int, str], verbose: bool, dbi: Connection) -> Tuple[str, int]:
        gene_symbol, gene_symbol_xref_id = None, None

        for xref_id in xref_list:
            # Remove object xrefs that are not in the best display names list
            if not display_names.get(xref_id):
                if verbose:
                    logging.info(f"Removing {xref_id_to_display[xref_id]} from gene")
                self.update_object_xref_status(
                    object_xref_list[xref_id], "MULTI_DELETE", dbi
                )
            else:
                if verbose:
                    logging.info(f"Keeping the best one {xref_id_to_display[xref_id]}")
                gene_symbol = xref_id_to_display[xref_id]
                gene_symbol_xref_id = xref_id

        return gene_symbol, gene_symbol_xref_id

    def find_lrg_hgnc(self, gene_id: int, dbi: Connection) -> Tuple[str, int, bool]:
        gene_symbol, gene_symbol_xref_id = None, None
        is_lrg = False

        # Look for LRG_HGNC_notransfer, if found then find HGNC equiv and set to this
        query = select(
            XrefUORM.label,
            XrefUORM.xref_id,
            ObjectXrefUORM.object_xref_id,
            SourceUORM.priority,
        ).where(
            XrefUORM.xref_id == ObjectXrefUORM.xref_id,
            XrefUORM.source_id == SourceUORM.source_id,
            SourceUORM.name == "LRG_HGNC_notransfer",
            ObjectXrefUORM.ensembl_id == gene_id,
            ObjectXrefUORM.ensembl_object_type == "Gene",
        )
        for row in dbi.execute(query).mappings().all():
            # Set status to NO_DISPLAY as we do not want this transferred, just the equivalent hgnc
            self.update_object_xref_status(row.object_xref_id, "NO_DISPLAY")

            new_xref_id, priority = None, None
            query = (
                select(XrefUORM.xref_id, SourceUORM.priority)
                .where(
                    XrefUORM.xref_id == ObjectXrefUORM.xref_id,
                    XrefUORM.source_id == SourceUORM.source_id,
                    XrefUORM.label == row.label,
                    SourceUORM.name == "HGNC",
                    ObjectXrefUORM.ox_status == "DUMP_OUT",
                )
                .order_by(SourceUORM.priority)
            )
            result = dbi.execute(query).fetchall()
            if result:
                new_xref_id, priority = result[0]

            if new_xref_id:
                gene_symbol = row.label
                gene_symbol_xref_id = new_xref_id
                is_lrg = True

        return gene_symbol, gene_symbol_xref_id, is_lrg

    def find_from_other_sources(self, ignore: Dict[int, int], args: Dict[str, Any], dbi: Connection) -> Tuple[str, int, str, Dict[str, str]]:
        gene_id = args["gene_id"]
        display_label_to_desc = args["display_label_to_desc"]
        transcript_source = args["transcript_source"]

        gene_symbol, gene_symbol_xref_id = None, None
        other_name_number, found_gene = {}, {}

        for dbname in ["miRBase", "RFAM", "EntrezGene"]:
            query = select(
                XrefUORM.label,
                XrefUORM.xref_id,
                ObjectXrefUORM.object_xref_id,
                XrefUORM.description,
            ).where(
                XrefUORM.xref_id == ObjectXrefUORM.xref_id,
                XrefUORM.source_id == SourceUORM.source_id,
                SourceUORM.name == dbname,
                ObjectXrefUORM.ox_status == "DUMP_OUT",
                ObjectXrefUORM.ensembl_id == gene_id,
                ObjectXrefUORM.ensembl_object_type == "Gene",
            )
            for row in dbi.execute(query).mappings().all():
                if found_gene.get(gene_id):
                    break
                if re.search(r"^LOC", row.label) or re.search(r"^SSC", row.label):
                    continue
                if ignore.get(row.object_xref_id):
                    continue

                gene_symbol = row.label
                gene_symbol_xref_id = row.xref_id
                transcript_source = dbname
                display_label_to_desc[row.label] = row.description

                if other_name_number.get(gene_symbol):
                    other_name_number[gene_symbol] += 1
                else:
                    other_name_number[gene_symbol] = 1

                if dbname != "EntrezGene":
                    gene_symbol = f"{gene_symbol}.{other_name_number[gene_symbol]}"

                found_gene[gene_id] = 1

        return gene_symbol, gene_symbol_xref_id, transcript_source, display_label_to_desc

    def set_transcript_display_xrefs(self, args: Dict[str, Any], dbi: Connection) -> Tuple[int, int, Dict[str, int], Dict[str, int]]:
        max_xref_id = args["max_xref_id"]
        max_object_xref_id = args["max_object_xref_id"]
        gene_id = args["gene_id"]
        gene_id_to_stable_id = args["gene_id_to_stable_id"]
        gene_symbol = args["gene_symbol"]
        description = args["description"]
        source_id = args["source_id"]
        xref_added = args["xref_added"]
        seen_gene = args["seen_gene"]
        transcript_ids = args["transcript_ids"]
        transcript_source = args["transcript_source"]
        species_id = args["species_id"]

        # Do nothing is LRG
        if re.search("LRG", gene_id_to_stable_id.get(gene_id)):
            return

        ext = 201
        if seen_gene.get(gene_symbol):
            ext = seen_gene[gene_symbol]

        # Go thourgh transcripts
        for transcript_id in transcript_ids:
            transcript_name = f"{gene_symbol}-{ext}"

            if not source_id:
                raise LookupError(
                    f"transcript_name = {transcript_name} for transcript_id {transcript_id} but NO source_id for this entry for {transcript_source}???"
                )

            index = f"{transcript_name}:{source_id}"
            if not xref_added.get(index):
                # Add new xref for the transcript name
                max_xref_id += 1
                dbi.execute(
                    insert(XrefUORM)
                    .values(
                        xref_id=max_xref_id,
                        source_id=source_id,
                        accession=transcript_name,
                        label=transcript_name,
                        version=0,
                        species_id=species_id,
                        info_type="MISC",
                        info_text="",
                        description=description,
                    )
                    .prefix_with("IGNORE")
                )

                xref_added[index] = max_xref_id

            # Update the transcript display xref
            dbi.execute(
                update(TranscriptStableIdORM)
                .where(TranscriptStableIdORM.internal_id == transcript_id)
                .values(display_xref_id=xref_added[index])
            )

            # Add a corresponding object and identity xrefs
            max_object_xref_id += 1
            dbi.execute(
                insert(ObjectXrefUORM).values(
                    object_xref_id=max_object_xref_id,
                    ensembl_id=transcript_id,
                    ensembl_object_type="Transcript",
                    xref_id=xref_added[index],
                    linkage_type="MISC",
                    ox_status="DUMP_OUT",
                )
            )

            dbi.execute(
                insert(IdentityXrefUORM).values(
                    object_xref_id=max_object_xref_id,
                    query_identity=100,
                    target_identity=100,
                )
            )

            ext += 1

        seen_gene[gene_symbol] = ext

        return max_xref_id, max_object_xref_id, xref_added, seen_gene
