#  See the NOTICE file distributed with this work for additional information
#  regarding copyright ownership.
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

from ensembl.core.models import SeqRegion, SeqRegionAttrib, AttribType, CoordSystem, Meta
from ensembl.utils.database import DBConnection
from ensembl.production.metadata.api.models import Assembly, AssemblySequence
from sqlalchemy import update
from sqlalchemy.engine.url import make_url
from sqlalchemy.sql import bindparam

from ensembl.production.hive.BaseProdRunnable import BaseProdRunnable


class ChecksumTransfer(BaseProdRunnable):
    def run(self):
        db_uri = make_url(self.param_required("database_uri"))
        md_uri = make_url(self.param_required("metadata_uri"))
        data = self.extract_data_from_core(db_uri)
        self.deposit_data_in_meta(md_uri, data)

    def extract_data_from_core(self, db_uri):
        db = DBConnection(db_uri)
        with db.session_scope() as session:
            query = session.query(
                CoordSystem.species_id, SeqRegion.name, AttribType.code, SeqRegionAttrib.value
            ).join(
                SeqRegion, CoordSystem.coord_system_id == SeqRegion.coord_system_id
            ).join(
                SeqRegionAttrib, SeqRegion.seq_region_id == SeqRegionAttrib.seq_region_id
            ).join(
                AttribType, SeqRegionAttrib.attrib_type_id == AttribType.attrib_type_id
            ).filter(
                AttribType.code.in_(['md5_toplevel', 'sha512t24u_toplevel'])
            )

            data = query.all()
            result = {}
            for species_id, name, code, value in data:
                if species_id not in result:
                    assemb = session.query(Meta.meta_value).filter(
                        Meta.meta_key == "assembly.accession").filter(Meta.species_id == species_id).one_or_none()
                    if assemb is None:
                        print(f"Assembly Accession missing for species_id: {species_id}")
                        continue
                    else:
                        assembly_acc = assemb[0]
                    result[species_id] = {
                        'assembly_acc': assembly_acc,
                        'seq_regions': {}
                    }

                if name not in result[species_id]['seq_regions']:
                    result[species_id]['seq_regions'][name] = {}
                if code == 'md5_toplevel':
                    result[species_id]['seq_regions'][name]['md5'] = value
                elif code == 'sha512t24u_toplevel':
                    result[species_id]['seq_regions'][name]['sha512t24u'] = value
            return result

    def deposit_data_in_meta(self, md_uri, data):
        md = DBConnection(md_uri)
        with md.session_scope() as session:
            updates = []

            for species_id, species_data in data.items():
                assembly_acc = species_data['assembly_acc']
                seq_regions = species_data['seq_regions']

                # Fetch all relevant AssemblySequence records
                assembly_seqs = session.query(AssemblySequence).join(Assembly).filter(
                    Assembly.accession == assembly_acc,
                    AssemblySequence.name.in_(seq_regions.keys())
                ).all()

                assembly_seq_dict = {seq.name: seq for seq in assembly_seqs}

                # Check Seq_region exists in metadata database but not in our dictionary
                for seq in assembly_seqs:
                    if seq.name not in seq_regions:
                        raise ValueError(
                            f"AssemblySequence with name {seq.name} exists in metadata database but is not found in the provided data for assembly {assembly_acc}")

                for seq_name, checksums in seq_regions.items():
                    assembly_seq = assembly_seq_dict.get(seq_name)
                    if not assembly_seq:
                        raise ValueError(
                            f"AssemblySequence with name {seq_name} not found in metadata database for assembly {assembly_acc}")

                    update_data = {}
                    if 'md5' in checksums:
                        update_data['md5'] = checksums['md5']
                    if 'sha512t24u' in checksums:
                        update_data['sha512t24u'] = checksums['sha512t24u']

                    if update_data:
                        update_data["pk_assembly_sequence_id"] = assembly_seq.assembly_sequence_id
                        updates.append(update_data)

            # Perform the bulk update
            if updates:
                stmt = update(AssemblySequence).where(
                    AssemblySequence.assembly_sequence_id == bindparam("pk_assembly_sequence_id")
                ).values(
                    md5=bindparam("md5"),
                    sha512t24u=bindparam("sha512t24u")
                )
                session.execute(stmt, updates)
