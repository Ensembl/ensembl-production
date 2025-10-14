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
    def build_top_level_seq(self, db: str, user: str, password: str, path = ""):
        
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

        url = "mysql://" + user + "@" + db.split("//")[1]
        if (len(password) > 0):
            url = "mysql://" + user + ":" + password + "@" + db.split("//")[1]
        engine = sqlalchemy.create_engine(url)
        if not os.path.exists(path):
            os.makedirs(path)
        with engine.connect() as conn:
            data_collect = regions.collect()
            for row in data_collect:
                seq_id = str(row.seq_region_id)
                if (len(is_primary) > 0): # Then primary assembly exists
                    query = text("select sequence from dna where seq_region_id=" + seq_id)
                    exe = conn.execute(query)
                    results = exe.scalars().all()
                    if(results is None):
                        continue
                    result = ""
                    for res in results:
                        result = res
                else:
                    query = text("select d.sequence, a.asm_start, a.asm_end, a.cmp_start, a.cmp_end from assembly a join dna d on d.seq_region_id=a.cmp_seq_region_id where a.asm_seq_region_id=" + seq_id + " order by a.asm_start")
                    exe = conn.execute(query)
                    results = exe
                    if(results is None):
                        continue
                    result = ""
                    prev_end = 0
                    for res in results:
                        gap = res.asm_start - prev_end - 1 
                        prev_end = res.asm_end       
                        result = result + "N"*gap + res.sequence[res.cmp_start-1:res.cmp_end]
                # Here is an algorythm to concat dna sequnce from
                # corresponding letters
                file_path =  "" + path + "/" + seq_id  + ".txt"             
                try:
                    os.remove(file_path)
                except OSError:
                    pass
                f = open(file_path, "a")
                f.write(result)
                f.close()

            #PARs region in human
            if (len(assembly_GRCh38) > 0):

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
                
                file_path_x =  "" + path + "/" + str(x_region_id)  + ".txt" 
                file_path_y =  "" + path + "/" + str(y_region_id)  + ".txt"   
                f_x = open(file_path_x, "r")  
                f_y = open(file_path_y, "r")          
                sequence_x = "N"*10000 + f_x.read()
                sequence_y = f_y.read()
                sequence_x_result = sequence_x
                sequence_y_result = "N"*10000 + sequence_x[10000:2781479] + sequence_y[0:54106423]\
                    + sequence_x[155701382:156030895] + sequence_y[54106423:]

                # Find region id of x
                # Open x file, prepend seq with 10k N, write to file. 
                # Open Y file, concat 10k N + X: 10001 - 2781479 + 
                # Y:2781480 - 56887902 + X: 155701383 - 156030895 + Y:57217416 - 57227415
                # Write Y file

                try:
                    os.remove(file_path_x)
                    os.remove(file_path_y)
                except OSError:
                    pass

                f = open(file_path_x, "a")
                f.write(sequence_x_result)
                f.close()

                f = open(file_path_y, "a")
                f.write(sequence_y_result)
                f.close()

        return 0
 