#!/usr/bin/env python

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Requirements:
#   Python 3.7+
# Usage example:
#   python dcparse.py parser_type /path/to/dc_dir -o failed_dc.json
# Print help:
#   python dcparse.py -h


import argparse
import json
import os
import re
from typing import Any, List, Dict, IO, Pattern


EMPTY_RE = re.compile(r'^$')


def skip_to(regex: Pattern, dc_file: IO, skip_empty: bool = True) -> str:
    for line in dc_file:
        if skip_empty and EMPTY_RE.match(line):
            continue
        match = regex.match(line)
        if match:
            return match.group(1)


def skip_multiple_lines(regex: Pattern, dc_file: IO, skip_empty: bool = True) -> List[str]:
    test_lines = []
    for line in dc_file:
        if skip_empty and EMPTY_RE.match(line):
            continue
        match = regex.match(line)
        if match:
            test_lines.append(match.group(1))
        else:
            return test_lines


class BaseDCParser:
    def load_failed(self, dc_file: IO, data: Dict[str, Any]) -> None:
        raise NotImplementedError('Calling BaseDCParser.load_failed')

    def write_data(self, data: Dict[str, Any], dc: str, species: str, test: str, test_lines: List[str]):
        data.setdefault(dc, {}).setdefault(species, {}).setdefault('tests', {}).setdefault(test, []).extend(test_lines)


class MultiDCParser(BaseDCParser):
    TEST_RE = re.compile(r'^ {8}(not ok .+)$')
    SPECIES_RE = re.compile(r'^ {4}not ok \d+ - (.+)$')
    DC_RE = re.compile(r'^not ok \d+ - (\w+)$')
    TEST_LINE_RE = re.compile(r'^ {8}#(.+)$')

    def load_failed(self, dc_file: IO, data: Dict[str, Any]) -> None:
        for line in dc_file:
            match = self.TEST_RE.match(line)
            if match:
                test = match.group(1)
                test_lines = skip_multiple_lines(self.TEST_LINE_RE, dc_file)
                species = skip_to(self.SPECIES_RE, dc_file)
                dc = skip_to(self.DC_RE, dc_file)
                self.write_data(data, dc, species, test, test_lines)


class MartDCParser(BaseDCParser):
    DC_RE = re.compile(r"^# {1}Checking (?P<dc>\w+) for new dataset (?P<species>\w+)$")
    TEST_RE = re.compile(r"^# {3}Failed test '(.+)'$")
    TEST_LINE_RE = re.compile(r'^# {3}(.+)$')

    def load_failed(self, dc_file: IO, data: Dict[str, Any]) -> None:
        dc = None
        test = None
        test_line = None
        species = None

        for line in dc_file:
            match = self.DC_RE.match(line)
            if match:
                dc = match.group('dc')
                species = match.group('species')
                continue
            match = self.TEST_RE.match(line)
            if match:
                test = match.group(1)
                continue
            match = self.TEST_LINE_RE.match(line)
            if match:
                test_line = match.group(1)
                self.write_data(data, dc, species, test, [test_line])


def parse_dc(parser: BaseDCParser, dc_dir: str, out_file: str) -> None:
    data: Dict[str, Any] = {}
    for filename in os.listdir(dc_dir):
        if filename.endswith('.txt'):
            filepath = os.path.join(dc_dir, filename)
            with open(filepath, 'r') as dc_f:
                parser.load_failed(dc_f, data)
    with open(out_file, 'w') as out_f:
        json.dump(data, out_f, indent=2)


def main():
    parser = argparse.ArgumentParser(description='DataChecks to JSON parser')
    parser.add_argument('parser', type=str, choices=['multi', 'mart'],
                        help='Parser type.')
    parser.add_argument('dc_dir', type=str,
                        help='Path DataCheck files directory. All .txt files will be loaded.')
    parser.add_argument('-o', '--output-file', type=str,
                        help='Path to output JSON file. (Defaults to <dc_dir>/failed_dcs.json)')
    args = parser.parse_args()

    if args.output_file:
        out_file = args.output_file
    else:
        out_file = os.path.join(args.dc_dir, 'failed_dcs.json')

    if args.parser == 'multi':
        parser = MultiDCParser()
    elif args.parser == 'mart':
        parser = MartDCParser()

    parse_dc(parser, args.dc_dir, out_file)


if __name__ == '__main__':
    main()

