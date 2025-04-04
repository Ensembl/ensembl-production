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
import os
import shutil
from pyspark.sql import SparkSession
from pyspark.sql.types import *
from ensembl.production.spark.core.FileSystemSparkService import FileSystemSparkService

__all__ = ['TranslationSparkService']

class TranslationSparkService:

    __type = 'translation_spark_service'

    def __init__(self,
                 session: SparkSession = None,
                 ) -> None:
        if not session:
            raise ValueError(
                'Connection details and session is required')
        self._spark = session
        self._tmp_folder = ["tmp"]


    """
    Returns transcripts df, loaded directly from database
    Database URL example: jdbc:mysql://localhost:3306/ensembl_core_human_110
    """
    def load_transcripts(self, db: str, user: str, password: str):
        transcripts = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
                .option("dbtable", "transcript")\
            .option("user", user)\
            .option("password", password)\
            .load()

        return transcripts

    """
    Load transcripts with fs dump, performance boost
    """
    def load_transcripts_fs(self, db: str, user: str, password: str, tmp_folder: str):
        transcripts = self.load_transcripts(db, user, password)
        file_service = FileSystemSparkService(self._spark)
        return file_service.write_df_to_orc(transcripts, "transcripts", tmp_folder)

    """
    Returns translations df, loaded directly from database
    Database URL example: jdbc:mysql://localhost:3306/ensembl_core_human_110
    """
    def load_translations(self, db: str, user: str, password: str):
        translations = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "translation")\
            .option("user", user)\
            .option("password", password)\
            .load()

        return translations

    """
    Load translations with fs dump, performance boost
    """
    def load_translations_fs(self, db: str, user: str, password: str, tmp_folder: str):
        translations = self.load_translations(db, user, password)
        file_service = FileSystemSparkService(self._spark)
        return file_service.write_df_to_orc(translations, "translations", tmp_folder)


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
    Returns transcript with translation start-end coordinates on this
    transcript
    """
    def get_translatable_regions(self, db: str, user: str, password: str,\
                                tmp_folder=None):
        exons = self.load_exons_fs(db, user, password, tmp_folder)
        transcripts = self.load_transcripts_fs(db, user, password, tmp_folder)
        translations = self.load_translations_fs(db, user, password, tmp_folder)

        transcripts_with_translations = transcripts.drop("seq_region_start",\
                                                         "seq_region_end").withColumnRenamed("canonical_translation_id", "translation_id")\
                .join(translations.drop("transcript_id"), ["translation_id"])

        def _adjust_translation_start_end(row):
            exon_start = int(row.seq_region_start)
            exon_end = int(row.seq_region_end)
            translation_start = int(row.seq_start)
            translation_end = int(row.seq_end)

            region_start = exon_start
            region_end = exon_end

            if row.seq_region_strand == 1:
                region_start = exon_start - 1 + translation_start
                region_end = exon_start - 1 + translation_end
            else:
                region_start = exon_end + 1 - translation_end
                region_end = exon_end + 1 - translation_start

            return Row(row.transcript_id, region_start, region_end,
                       row.phase)
        # For exons we need to drop transcript_id not t oconfuse with
        # translation_transcript_id and take only current exons
        exons = exons.drop("transcript_id").filter("is_current==1").drop_duplicates(["exon_id"])

        #Of start exons we need only seq_region_start
        start_exons = transcripts_with_translations.join(exons,\
                                on =\
                                [(transcripts_with_translations.start_exon_id==exons.exon_id)], how =\
                                "inner").select("seq_region_start", "translation_id",\
                                                                                 "phase")
        #Of end_exons we need all but seq_region_start
        end_exons = transcripts_with_translations.join(exons,\
                            on = [(transcripts_with_translations.end_exon_id==exons.exon_id)],\
                            how = "inner").drop("seq_region_start").drop("exon_transcript_id")

        #Now each translatable region has seq_region_start and seq_region_end of exons
        translatable_regions = start_exons.join(end_exons, ["translation_id"])

        translatable_regions = translatable_regions.rdd.map(lambda x:_adjust_translation_start_end(x))\
                .toDF(["transcript_id", "region_start", "region_end",
                       "phase"])

        return translatable_regions
