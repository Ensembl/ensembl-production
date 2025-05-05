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

"""
Fetch InterPro and seg files from the proteome directory and load them into the core database.
"""
import os
import logging
import eHive
import glob


logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class HiveGenomeFactory(eHive.BaseRunnable):
  
    def run(self):
        # Get the parameters
        proteome_fasta = os.path.abspath(self.param_required('proteome_fasta'))
        proteome_dir = os.path.dirname(proteome_fasta)        
        checksum_dir = os.path.join(proteome_dir, 'checksum')
        nochecksum_dir = os.path.join(proteome_dir, 'nochecksum')
        found_pairs = []
        found_singles = []
        missing_reports = []

        # Check if the proteome directory is a valid directory
        if not (os.path.exists(proteome_dir)):
            raise eHive.exceptions.HiveException(f"Proteome directory {proteome_dir} does not exist")
        if not (os.path.exists(checksum_dir) and os.path.exists(nochecksum_dir)):
            raise eHive.exceptions.HiveException(f"checksum or nochecksum directories not found in {proteome_dir}") 
        
        #Check seg files in numeric folders at toplevel of proteome directory
        logging.info("Checking for seg files in numeric folders")

        for entry in os.listdir(proteome_dir):
            entry_path = os.path.join(proteome_dir, entry)
            if os.path.isdir(entry_path) and entry.isdigit():
                seg_files = glob.glob(os.path.join(entry_path, '*.seg.txt'))
                if seg_files:
                    found_singles.extend([os.path.abspath(f) for f in seg_files])
                else:
                    missing_reports.append(f"Missing seg.txt in folder: {os.path.abspath(entry_path)}")
        

        logging.info("\nChecking checksum directory...")
        checksum_dir = os.path.join(proteome_dir, 'checksum')
        if os.path.isdir(checksum_dir):
            for entry in os.listdir(checksum_dir):
                entry_path = os.path.join(checksum_dir, entry)
                if os.path.isdir(entry_path):
                    # Pair .fa.nolookup files
                    tsv_files = glob.glob(os.path.join(entry_path, '*.fa.nolookup.tsv'))
                    xml_files = glob.glob(os.path.join(entry_path, '*.fa.nolookup.xml'))

                    pairs, unmatched_tsv, unmatched_xml = self.pair_files(tsv_files, xml_files, '.fa.nolookup')
                    found_pairs.extend(pairs)
                    for t in unmatched_tsv:
                        missing_reports.append(f"Missing corresponding .fa.nolookup.xml for {os.path.abspath(t)}")
                    for x in unmatched_xml:
                        missing_reports.append(f"Missing corresponding .fa.nolookup.tsv for {os.path.abspath(x)}")

                    # Pair .fa.lookup files
                    tsv_files = glob.glob(os.path.join(entry_path, '*.fa.lookup.tsv'))
                    xml_files = glob.glob(os.path.join(entry_path, '*.fa.lookup.xml'))

                    pairs, unmatched_tsv, unmatched_xml = self.pair_files(tsv_files, xml_files, '.fa.lookup')
                    found_pairs.extend(pairs)
                    for t in unmatched_tsv:
                        missing_reports.append(f"Missing corresponding .fa.lookup.xml for {os.path.abspath(t)}")
                    for x in unmatched_xml:
                        missing_reports.append(f"Missing corresponding .fa.lookup.tsv for {os.path.abspath(x)}")

        # Check nochecksum folders (pairing local tsv and xml)
        logging.info("\nChecking nochecksum files...")
        nochecksum_dir = os.path.join(proteome_dir, 'nochecksum')
        if os.path.isdir(nochecksum_dir):
            for entry in os.listdir(nochecksum_dir):
                entry_path = os.path.join(nochecksum_dir, entry)
                if os.path.isdir(entry_path):
                    tsv_files = glob.glob(os.path.join(entry_path, '*.fa.local.tsv'))
                    xml_files = glob.glob(os.path.join(entry_path, '*.fa.local.xml'))

                    if tsv_files and xml_files:
                        # We assume only one pair per folder in nochecksum
                        found_pairs.append((os.path.abspath(tsv_files[0]), os.path.abspath(xml_files[0])))
                    else:
                        if tsv_files:
                            missing_reports.append(f"Missing corresponding .fa.local.xml for {os.path.abspath(tsv_files[0])}")
                        if xml_files:
                            missing_reports.append(f"Missing corresponding .fa.local.tsv for {os.path.abspath(xml_files[0])}")
        
        for tsv, xml in found_pairs:
            logging(f"TSV: {tsv}  |  XML: {xml}")
            self.dataflow(
                {
                    "outfile_tsv": tsv,
                    "outfile_xml": xml
                }, 3
            )
        
        logging.info("--- Found seg.txt Files ---")
        for seg_file in found_singles:
            self.dataflow(
                {
                    "seg": seg_file,
                }, 2
            )





    @staticmethod    
    def pair_files(tsv_files, xml_files, ext_to_strip):
        pairs = []
        unmatched_tsv = []
        unmatched_xml = []

        # Build dict for quick lookup
        xml_dict = {os.path.basename(f).replace(ext_to_strip + '.xml', ''): f for f in xml_files}

        for tsv in tsv_files:
            base = os.path.basename(tsv).replace(ext_to_strip + '.tsv', '')
            if base in xml_dict:
                pairs.append((os.path.abspath(tsv), os.path.abspath(xml_dict[base])))
                del xml_dict[base]
            else:
                unmatched_tsv.append(tsv)

        unmatched_xml.extend(xml_dict.values())
        return pairs, unmatched_tsv, unmatched_xml

        
# sub write_output {
#     my ($self) = @_;
#     my $file_varname = $self->param('file_varname', 'proteome_file'); 
#     $self->dataflow_output_id({$file_varname => $self->param('proteome_file')}, 1);
# }

# 1;
