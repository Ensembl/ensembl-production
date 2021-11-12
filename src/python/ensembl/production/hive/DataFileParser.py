from dataclasses import asdict
import json

import eHive

from ensembl.production.hive.datafile.parsers import FileParserError, EMBLFileParser, FASTAFileParser, BAMFileParser


PARSERS = {
    "embl": EMBLFileParser,
    "genbank": EMBLFileParser,
    "gff3": EMBLFileParser,
    "gtf": EMBLFileParser,
    "fasta": FASTAFileParser,
    "bamcov": BAMFileParser,
}


class DataFileParser(eHive.BaseRunnable):
    def fetch_input(self):
        input_data = json.loads(self.param("data"))
        self.param("file_format", input_data.get("file_format"))
        self.param("file_path", input_data.get("file_path"))

    def run(self):
        file_format = self.param('file_format')
        file_path = self.param('file_path')
        ParserClass = PARSERS.get(file_format)
        if ParserClass is None:
            self.warning(f"Invalid file_format: {file_format} for {file_path}", is_error=True)
        parser = ParserClass(
            ftp_dir_ens=self.param("ftp_dir_ens"),
            ftp_dir_eg=self.param("ftp_dir_eg"),
            ftp_url_ens=self.param("ftp_url_ens"),
            ftp_url_eg=self.param("ftp_url_eg"),
        )
        try:
            file_metadata = parser.get_metadata(json.loads(self.param("data")))
        except FileParserError as err:
            self.warning(f"Error: {err}: {err.errors}", is_error=True)
        self.param('file_metadata', file_metadata)

    def write_output(self):
        self.dataflow({
            'job_id': self.input_job.dbID,
            'output': json.dumps(asdict(self.param("file_metadata")))
        }, 2)