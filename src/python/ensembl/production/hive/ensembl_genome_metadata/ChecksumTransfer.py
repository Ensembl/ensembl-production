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

from ensembl.production.hive.BaseProdRunnable import BaseProdRunnable
from sqlalchemy.engine.url import make_url
from sqlalchemy.orm.exc import NoResultFound
from ensembl.core.models import SeqRegion, SeqRegionAttrib, AttribType, CoordSystem, Meta
from ensembl.database import DBConnection
from ensembl.production.metadata.api.models import Assembly, AssemblySequence

class ChecksumTransfer(BaseProdRunnable):
    def run(self):
        db_uri = make_url(self.param_required("database_uri"))
        md_uri = make_url(self.param_required("metadata_uri"))
        md5 = self.param("md5")
        sha512t24u = self.param("sha512t24u")

        data = self.extract_data_from_core(db_uri)
        self.deposit_data_in_meta(md_uri,data,md5,sha512t24u)

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
                        Exception("Assembly Accession missing for this organism")
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

    def deposit_data_in_meta(self,md_uri,data,md5=1,sha512t24u=1):
        md = DBConnection(md_uri)
        with md.session_scope() as session:
            for species_id, species_data in data.items():
                assembly_acc = species_data['assembly_acc']
                seq_regions = species_data['seq_regions']

                try:
                    assembly = session.query(Assembly).filter(Assembly.accession == assembly_acc).one()
                except NoResultFound:
                    raise ValueError(f"Assembly with accession {assembly_acc} not found for species {species_id}")

                for seq_name, checksums in seq_regions.items():
                    assembly_seq = session.query(AssemblySequence).filter(
                        AssemblySequence.assembly_id == assembly.assembly_id).filter(
                        AssemblySequence.name == seq_name).first()
                    if not assembly_seq:
                        raise ValueError(f"AssemblySequence with name {seq_name} not found for assembly {assembly_acc}")

                    # Update checksums if they exist
                    if md5 and 'md5' in checksums:
                        assembly_seq.md5 = checksums['md5']
                    elif md5:
                        raise ValueError(f"MD5 checksum not found for {seq_name}")

                    if sha512t24u and 'sha512t24u' in checksums:
                        assembly_seq.sha512t24u = checksums['sha512t24u']
                    elif sha512t24u:
                        raise ValueError(f"SHA512t24u checksum not found for {seq_name}")
