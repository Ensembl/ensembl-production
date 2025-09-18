# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import sqlalchemy
import os
import shutil
from pyspark.sql import SparkSession
from pyspark.sql.types import *
from sqlalchemy import text
from pyspark.sql.functions import lit, udf
from Bio.Seq import Seq
from ensembl.production.spark.core.TranslationSparkService import TranslationSparkService
from ensembl.production.spark.core.FileSystemSparkService import FileSystemSparkService
__all__ = ['ExonSparkService']


class SequnceService:

    __type = 'exon_spark_service'

    def __init__(self,
                 session: SparkSession = None,
                 ) -> None:
        if not session:
            raise ValueError(
                'Connection details and session is required')
        self._spark = session

    """
    Creates a sequence on top level (features level) from contig level, write to file
    """
    def build_top_level_seq(self, db: str, user: str, password: str, path: None):
        if (path is None):
            path = "genome_sequence"
        
        #Get all transcripts seq_regions
        #Select seq_region_id from transcript group by seq_region_id
        #Check if they have immediate sequence if not
        #For every transcript region find all assemblies on sequence level and concat
        #select group_concat(d.sequence) from assembly a join dna d on d.seq_region_id=a.cmp_seq_region_id where a.asm_seq_region_id=131124 order by a.asm_start

        regions = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "(select seq_region_id from transcript)tmp")\
            .option("user", user)\
            .option("password", password)\
            .load().dropDuplicates()
        
        #Fetching schema
        sequence = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "(select * from sequence where seq_region_id = -3)tmp")\
            .option("user", user)\
            .option("password", password)\
            .load().dropDuplicates()
        file_service = FileSystemSparkService(self._spark)
        sequence = file_service.write_df_to_orc(sequence, "sequence_genome", "")

        url = "mysql://" + user + ":" + password + "@" + db.split("//")[1]
        if (len(password) > 0):
            url = "mysql://" + user + ":" + password + "@" + db.split("//")[1]
        engine = sqlalchemy.create_engine(url)
        result = None
        with engine.connect() as conn:
            data_collect = regions.collect()
            # looping thorough each row of the regions dataframe
            for row in data_collect:
                seq_id = str(row.seq_region_id)
                query = text("select group_concat(d.sequence) from assembly a join dna d on d.seq_region_id=a.cmp_seq_region_id where a.asm_seq_region_id=" + seq_id + " order by a.asm_start")
                exe = conn.execute(query)
                results = exe.scalars().all()
                if(len(results) == 0):
                    print(seq_id)
                    continue
                results = results[0]
                if(len(results) == 0):
                    print(seq_id)
                    continue
                # Here is an algorythm to concat dna sequnce from
                # corresponding letters
                region_sequence = [[seq_id, results]]
                tmp_seq = self._spark.createDataFrame(region_sequence)
                sequence = sequence.union(tmp_seq)
        return 0
 