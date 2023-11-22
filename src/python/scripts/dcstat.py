#!/usr/bin/env python

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2023] EMBL-European Bioinformatics Institute
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
#   python dcstat.py /path/to/failed_dcs.json -v 2 -d CompareXref CompareGOXref -s ovis_aries bos_taurus
# Print help:
#   python dcstat.py -h


import argparse
from functools import partial
import logging
import json
import re
from typing import NamedTuple, List, Pattern, Callable


logging.basicConfig(format='%(levelname)s: %(message)s')


logger = logging.getLogger(__name__)


class FailedTests(NamedTuple):
    title: str
    content: List[str]


class DBParams(NamedTuple):
    species: str
    db_type: str
    db_name: str


class Failure(NamedTuple):
    db_params: DBParams
    tests: List[FailedTests]


def collect_failures(dc_label: str, dc_data: dict, filter_species: set = None) -> List[Failure]:
    valid_test_func = ANALYSIS_MAP[dc_label]
    failures_list: List[Failure] = []
    for db_labels, dc_tests_elems in dc_data.items():
        db_params = DBParams(*db_labels.split(', '))
        if filter_species:
            if db_params.species not in filter_species:
                continue
        failures = []
        for test_label, test_lines in dc_tests_elems['tests'].items():
            try:
                valid = valid_test_func(test_lines)  # type: ignore
            except ValueError as e:
                # print(f'Test: {test_label}\n{test_lines}')
                logger.warning('Could not parse %s failures for "%s"', dc_label, test_label)
                valid = False
            if not valid:  # type: ignore
                failures.append(FailedTests(test_label, test_lines))
        if failures:
            failures_list.append(Failure(db_params, failures))
    return failures_list


xref_re = re.compile(r'^(?P<current_count>\d+) \< (?P<previous_count>\d+) \* (?P<treshold>\d+)\%$')

def valid_compare_xref(dc_result: List[str]) -> bool:
    parsed_results = []
    for line in dc_result:
        match = xref_re.match(line)
        if match:
            parsed_results.append(match.groupdict())
    return compare_xref(parsed_results)


def compare_xref(parsed_results: List[dict]) -> bool:
    # If at least one is 0 the DC is SUSPICIOUS!
    # Obviously we can do fancier things here
    for result in parsed_results:
        if result['current_count'] == '0':
            return False
    return True


def compare_two(regex: Pattern, compare_func: Callable, dc_result: List[str]) -> bool:
    error_log = ' '.join(dc_result)
    try:
        first, second = regex.match(error_log).groups() # type: ignore
    except AttributeError:
        raise ValueError('Test lines do not match regex')
    return compare_func(first, second)


gene_names_re = re.compile(r"^.+?\s+\'(?P<current>\d+\.\d)\'\s+<=\s+\'(?P<previous>\d+)\'.+$")

def compare_projected_gene_names(current: str, previous: str) -> bool:
    # Obviously we can do fancier things here
    return float(current) <= float(previous)


xref_exists_re = re.compile(r"^.+?\s+\'(?P<current>\d+)\'\s+>\s+\'(?P<previous>\d+)\'.+$")

def compare_xref_exists(current: str, previous: str) -> bool:
    # Obviously we can do fancier things here
    return int(current) > int(previous)



got_expected_re = re.compile(r"^.+?\s+got: \'(?P<got>\d+)\'\s+expected: \'(?P<expected>\d+)\'.*$")

got_expected_obj_re = re.compile(r"^.+?\s+\$got->.+? = (?P<got>.*?)\s+\$expected->.+? = (?P<expected>.*?).*$")


def compare_got_expected_int(got: str, expected: str) -> bool:
    # Obviously we can do fancier things here
    return int(got) == int(expected)

def compare_got_expected_str(got: str, expected: str) -> bool:
    # Obviously we can do fancier things here
    return got == expected


got_expected_int = partial(compare_two, got_expected_re, compare_got_expected_int)
got_expected_obj = partial(compare_two, got_expected_obj_re, compare_got_expected_str)


# TODO: Specify more analysis here
ANALYSIS_MAP = {
    'CompareGOXref': valid_compare_xref,
    'CompareProjectedGOXrefs': valid_compare_xref,
    'CompareXref': valid_compare_xref,
    'CompareProjectedGeneNames': partial(compare_two, gene_names_re, compare_projected_gene_names),
    'DuplicateTranscriptNames': got_expected_int,
    'DuplicateXref': got_expected_int,
    'HGNCMultipleGenes': got_expected_int,
    'XrefTypes': got_expected_int,
    'ForeignKeys': got_expected_int,
    'StableIdDisplayXref': got_expected_int,
    'XrefPrefixes': got_expected_int,
    'DisplayXrefExists': partial(compare_two, xref_exists_re, compare_xref_exists),
    'CanonicalTranscripts': got_expected_int,
    'GeneBiotypes': got_expected_int,
    'ProteinTranslation': got_expected_int,
    'VersionedGenes': got_expected_int,
    'FeatureBounds': got_expected_int,
    'TranscriptBounds': got_expected_int,
    'AnalysisFormat': got_expected_int,
    'SeqRegionTopLevel': got_expected_int,
    'ValidTranslations': got_expected_int,
    'ControlledAnalysis': got_expected_obj,
    'SchemaPatchesApplied': got_expected_obj,
    'CompareMetaKeys': got_expected_obj,
    'MetaKeyConditional': got_expected_obj,
    'CompareSchema': got_expected_obj,
}


def dc_stats(data: dict, filter_species: set = None) -> list:
    lines = []
    for dc_label, dc_data in data.items():
        if dc_label in ANALYSIS_MAP:
            collected_failures = collect_failures(dc_label, dc_data, filter_species)
            lines.append(f'{dc_label:<30}{len(dc_data):<20}\t{len(collected_failures):<10}')
        else:
            lines.append(f'{dc_label:<30}{len(dc_data):<20}{"DUNNO":<10}')
    return lines


def dc_failures(data: dict, dc_label: str, verbosity: int = 1, filter_species: set = None) -> list:
    lines = []
    if dc_label in ANALYSIS_MAP:
        collected_failures = collect_failures(dc_label, data[dc_label], filter_species)
        for failure in collected_failures:
            if verbosity >= 1:
                lines.append(f'{failure.db_params.db_name:<50}')
            if verbosity >= 2:
                for failed_test in failure.tests:
                    lines.append(f'\t{failed_test.title}')
                    if verbosity >= 3:
                        for result in failed_test.content:
                            lines.append(f'\t\t{result}\n')
    else:
        lines.append('Unknown DC')
    return lines


def main():
    parser = argparse.ArgumentParser(description='DataCheck Statistics & Report')
    parser.add_argument('dc_file', type=str,
                        help='Path to JSON DataCheck file to analize.')
    parser.add_argument('-d', '--dc', type=str, nargs='+',
                        help='List of DC names to show.')
    parser.add_argument('-v', '--verbosity', type=int, default=1,
            help='Verbosity level: 1) shows only DB names. 2) shows also failed tests names. 3) shows also errors log')
    parser.add_argument('-s', '--filter-species', type=str, nargs='+',
                        help='Filter results by species.')
    parser.add_argument('-Q', '--quiet', action='store_true',
                        help='Silence warnings and infos.')
    args = parser.parse_args()

    with open(args.dc_file, 'r') as f:
        dcs = json.load(f)

    if args.quiet:
        logger.setLevel(logging.ERROR)

    filter_species = None
    if args.filter_species:
        filter_species = set(args.filter_species)

    stats = dc_stats(dcs, filter_species)
    print(f'\n{"DATACHECK":<30}{"REPORTED":<20}{"SUSPICIOUS":<10}')

    dc_filter_labels = None
    if args.dc:
        dc_filter_labels = set(args.dc)

    for line in stats:
        if dc_filter_labels:
            if not line.split()[0] in dc_filter_labels:
                continue
        print(line)

    if args.dc:
        for dc_label in args.dc:
            failures = dc_failures(dcs, dc_label, args.verbosity, filter_species)
            print('\n\n')
            print(f'{dc_label}:\n')
            for line in failures:
                print(line)


if __name__ == '__main__':
    main()
