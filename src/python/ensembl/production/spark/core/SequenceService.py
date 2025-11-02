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
from pyspark.sql import SparkSession
from pyspark.sql.types import *
from sqlalchemy import text
from pyspark.sql.functions import lit, udf
from Bio.Seq import Seq
from ensembl.production.spark.core.FileSystemSparkService import FileSystemSparkService
from pyspark.sql.functions import regexp_replace, expr, concat, concat_ws, collect_list, col


__all__ = ['ExonSparkService']


class SequenceService:

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
    def build_top_level_seq(self, db: str, user: str, password: str, path_top = ""):
        
        #Get all transcripts seq_regions
        #Select seq_region_id from transcript group by seq_region_id
        #Check if they have immediate sequence if not
        #For every transcript region find all assemblies on sequence level and concat
        #select group_concat(d.sequence) from assembly a join dna d on d.seq_region_id=a.cmp_seq_region_id where a.asm_seq_region_id=131124 order by a.asm_start

        is_primary = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "(select * from coord_system where name = \"primary_assembly\")tmp")\
            .option("user", user)\
            .option("password", password)\
            .load().dropDuplicates().collect()
        
        assembly_GRCh38 = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "(select * from meta where meta_value = \"GRCh38\")tmp")\
            .option("user", user)\
            .option("password", password)\
            .load().dropDuplicates().collect()

        regions = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "(select sr.seq_region_id from seq_region sr join coord_system cs on cs.coord_system_id = sr.coord_system_id where cs.rank = 1)tmp")\
            .option("user", user)\
            .option("password", password)\
            .load().dropDuplicates()

        y_region_id = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "(select sr.seq_region_id from seq_region sr join coord_system cs on cs.coord_system_id=sr.coord_system_id where sr.name = \"Y\" and cs.rank = 1)tmp")\
            .option("user", user)\
            .option("password", password)\
            .load().dropDuplicates().collect()[0].seq_region_id
        x_region_id = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "(select sr.seq_region_id from seq_region sr join coord_system cs on cs.coord_system_id=sr.coord_system_id where sr.name = \"X\" and cs.rank = 1)tmp")\
            .option("user", user)\
            .option("password", password)\
            .load().dropDuplicates().collect()[0].seq_region_id
        
        url = "mysql://" + user + "@" + db.split("//")[1]
        if (len(password) > 0):
            url = "mysql://" + user + ":" + password + "@" + db.split("//")[1]
        engine = sqlalchemy.create_engine(url)

        with engine.connect() as conn:
            def get_region_sequence_assembled(seq_id):
                query = text("select d.sequence, a.asm_start, a.asm_end, a.cmp_start, a.cmp_end from assembly a join dna d on d.seq_region_id=a.cmp_seq_region_id where a.asm_seq_region_id=" + str(seq_id) + " order by a.asm_start")
                exe = conn.execute(query)
                results = exe
                sequence = ""
                prev_end = 0
                for res in results:
                    gap = res.asm_start - prev_end - 1 
                    prev_end = res.asm_end       
                    sequence = sequence + "N"*gap + res.sequence[res.cmp_start-1:res.cmp_end]
                return sequence

            #PARs regions
            if (len(assembly_GRCh38) > 0):
                #Creating x region
                x_seq = get_region_sequence_assembled(x_region_id)
                x_seq = "N"*10000 + "sequence"
                schema = StructType([StructField("seq_region_id", IntegerType(), True),
                    StructField("sequence", StringType(), True)]
                    )
                region_df = self._spark.createDataFrame([(int(x_region_id), str(x_seq))], schema)
                region_df.write.save(path=path_top, format='orc', mode='append', partitionBy="seq_region_id")

                #Creating y region
                y_seq = get_region_sequence_assembled(y_region_id)
                y_seq = x_seq[:2781479] + y_seq[0:54106423]\
                    + x_seq[155701382:156030895] + y_seq[54106423:]
                schema = StructType([StructField("seq_region_id", IntegerType(), True),
                    StructField("sequence", StringType(), True)]
                    )
                region_df = self._spark.createDataFrame([(int(y_region_id), str(y_seq))], schema)
                region_df.write.save(path=path_top, format='orc', mode='append', partitionBy="seq_region_id")

            data_collect = regions.collect()
            for row in data_collect:
                seq_id = str(row.seq_region_id)
                if (len(is_primary) > 0): # Then primary assembly exists
                    query = text("select sequence from dna where seq_region_id=" + seq_id)
                    exe = conn.execute(query)
                    results = exe.scalars().all()
                    if(results is None):
                        continue
                    sequence = ""
                    for res in results:
                        sequence = res
                else:
                    # If its par regions - we already done it
                    if (len(assembly_GRCh38) > 0) and ((seq_id == x_region_id) or (seq_id == y_region_id)):
                        continue
                    sequence = get_region_sequence_assembled(seq_id)

                schema = StructType([StructField("seq_region_id", IntegerType(), True),
                     StructField("sequence", StringType(), True)]
                     )
                region_df = self._spark.createDataFrame([(int(seq_id), str(sequence))], schema)
                region_df.write.save(path=path_top, format='orc', mode='append', partitionBy="seq_region_id")
        return 0
 