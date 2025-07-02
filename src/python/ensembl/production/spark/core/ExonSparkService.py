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


class ExonSparkService:

    __type = 'exon_spark_service'

    def __init__(self,
                 session: SparkSession = None,
                 ) -> None:
        if not session:
            raise ValueError(
                'Connection details and session is required')
        self._spark = session

    """
    Returns exons DF with transcript IDs, loaded directly from database
    Database URL example: jdbc:mysql://localhost:3306/ensembl_core_human_110
    """
    def load_exons(self, db: str, user: str, password: str):
        exons = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "exon")\
            .option("user", user)\
            .option("password", password)\
            .load()


        exon_transcript = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "exon_transcript")\
            .option("user", user)\
            .option("password", password)\
            .load()

        exons = exons.join(exon_transcript, on=["exon_id"])
        return exons

    """
    Load exons with fs dump, performance boost
    """
    def load_exons_fs(self, db: str, user: str, password: str, tmp_folder: str):
        exons = self.load_exons(db, user, password)
        file_service = FileSystemSparkService(self._spark)
        return file_service.write_df_to_orc(exons, "exons", tmp_folder)

    """
    Dumps sequence to csv file, that allows to process sequence effictefly in
    parralel. Reading from database is done with SQLALchemy, so conn is SQL
    alchemy object. CSV file has two colums - coord and letter of
    sequence. If folder is not empty - it is removedbefore dump.
    """
    def create_seq_file(self, conn, seq_id, max_overlap: int, tmp_folder=None):
        # Select sequence from dna table
        if (max_overlap == None):
            max_overlap = 0
        query = text("SELECT sequence FROM dna WHERE seq_region_id=" + seq_id)
        exe = conn.execute(query)
        results = exe.scalars().all()
        if (tmp_folder == None):
            tmp_folder = "tmp/"
        # Create folder for csv file
        shutil.rmtree(tmp_folder + seq_id, ignore_errors=True)
        if (os.path.exists(tmp_folder) == False):
            os.mkdir(tmp_folder)
        os.mkdir(tmp_folder + seq_id)

        # In loop write every letter in new row. Every row is coord and dna letter 
        if (len(results) > 0):
            f = open(tmp_folder + seq_id + "/" + seq_id + ".csv", "w")
            i = 0
            j = 0
            f.write("coord" + "," + "letter" + "\n")
            for c in results[0]:
                i = i + 1
                f.write(str(i) + "," + c + "\n")
            # For circulatr regions we need additional quarter-circle coordinates
            j = i
            for c in results[0]:
                j = j + 1
                f.write(str(i) + "," + c + "\n")
                if (j > max_overlap):
                    break
            f.close()
            return i
        return None


    """
    Returns a dataframe of translatable exons from database.
    Database URL example: jdbc:mysql://localhost:3306/ensembl_core_human_110
    //MUST BE TESTED, in transcript service there is similar func, but more info, that is tested
    """
    def load_translatable_exons(self, db: str, user: str, password: str,\
                                tmp_folder=None):

        exons_raw = self.load_exons_fs(db, user, password, tmp_folder)
        translation_service = TranslationSparkService(self._spark)
        translatable_regions =\
        translation_service.get_translatable_regions(db, user,password, tmp_folder)

        # Remove exons outside of translateable region
        exons = exons_raw\
                .join(translatable_regions, on = [exons_raw.transcript_id ==\
                                                  translatable_regions.transcript_id])\
                .where((exons_raw.seq_region_start<=translatable_regions.region_end)\
                       & (exons_raw.seq_region_end>=translatable_regions.region_start))\
                .select(exons_raw["*"])\
                .orderBy("transcript_id", "rank")
        return exons


    """
    Returns exons dataframe with sequence column
    """
    def exons_with_seq(self, db: str, user: str, password: str,
                       tmp_folder="tmp/"):

        exons_raw = self.load_exons_fs(db, user, password, tmp_folder)
        regions = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "(select seq_region_id from transcript)tmp")\
            .option("user", user)\
            .option("password", password)\
            .load().dropDuplicates()
        file_service = FileSystemSparkService(self._spark)
        regions = file_service.write_df_to_orc(regions, "regions", tmp_folder)
        #We add to the end length of the region, if exon is curcular
        @udf(returnType=StringType())
        def adjust_end_circular(seq_region_start, seq_region_end,
                                region_length):
            if (seq_region_start > seq_region_end):
                seq_region_end = seq_region_end + region_length
            return seq_region_end

        # Using iterations on regions - because we really don't change
        # them, just use as index for dna table
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
                query = text("SELECT sequence FROM dna WHERE seq_region_id=" + seq_id)
                exe = conn.execute(query)
                results = exe.scalars().all()
                if(len(results) == 0):
                    print(seq_id)
                    continue
                results = results[0]
                # Here is a main spark algorythm to concat dna sequnce from
                # corresponding letters
                if (results == None):
                    contunue
                sequence_raw = results + results
                #Reverse compliment sequence for -1 strand
                @udf(returnType=StringType())
                def reverse_compliment(strand, start, end):
                    sequence = sequence_raw[int(start-1):int(end)].replace(" ", "")
                    if (strand == -1):
                        #Reverce seq
                        sequence = Seq(sequence)
                        sequence = sequence.reverse_complement()
                        return str(sequence)
                    return sequence
                #For each exon we append region length, for circular seq
                exonsDF = exons_raw.filter("seq_region_id=" +
                                           seq_id).withColumn("region_length",\
                                                              lit(len(results)))\
                                           .withColumn("seq_region_end",\
                                                            adjust_end_circular("seq_region_start",\
                                                            "seq_region_end",\
                                                             "region_length"))\
                                           .withColumn("sequence",\
                                                    reverse_compliment("seq_region_strand",\
                                                   "seq_region_start",\
                                                   "seq_region_end"))
               
                if (result is not None):
                    result = result.union(exonsDF)
                else:
                    result = exonsDF
        if (result == None):
            return
        #result.show(4)
        file_service = FileSystemSparkService(self._spark)
        return file_service.write_df_to_orc(result, "exons_with_seq", tmp_folder)
