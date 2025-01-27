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
from pyspark.sql import SparkSession
from pyspark.sql.types import *
import os
import shutil

__all__ = ['fileSystemSparkService']

"""
Service use to dump all db dataframes to file system tmp folder, and provides
final clean up
"""
class FileSystemSparkService:

    __type = 'file_system_spark_service'

    def __init__(self,
                 session: SparkSession = None,
                 ) -> None:
        if not session:
            raise ValueError(
                'Connection details and session is required')
        self._spark = session
        self._tmp_folder = ["tmp/"]

    """
    Writes dataframe to csv, and returns DF read from that csv file. Needed for
    big data ceses, as dataframe read from file is not placed in memory all in
    once, but processed in butches. Pyspark also writes not single file, but
    folder with data spread to butches, so folder path must be provided.
    Be carefull, data doesn't keep initial order, batches are written and read
    in parallel.
    If folder exists - it is cleaned before dump. Remove created folder later, when
    dataframe is no longer needed
    """
    def write_df_to_orc(self, df, output_file_path: str, tmp_folder=None):
        if (tmp_folder == None):
            tmp_folder = self._tmp_folder[0]
        index = 0

        while (os.path.exists(str(index) + tmp_folder + output_file_path)):
            index = index + 1
        folder_path = str(index) + tmp_folder + output_file_path
        self._tmp_folder.append(str(index) + tmp_folder)
        shutil.rmtree(folder_path, ignore_errors=True)
        df.write\
            .mode("overwrite")\
            .orc(folder_path)
        return self._spark.read.orc(folder_path).repartition(4)


    """
    Clean all tmp directories
    """
    def clean_tmp_dirs(self):
        for folder in self._tmp_folder:
            shutil.rmtree(folder, ignore_errors=True)
            return
