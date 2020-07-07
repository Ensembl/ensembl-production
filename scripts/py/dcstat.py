#!/usr/bin/env python

# Requirements:
#   Python 3.7+
# Usage example:
#   python dcstat.py /path/to/failed_dcs.json -v 2 -d CompareXref CompareGOXref -s ovis_aries bos_taurus
# Print help:
#   python dcstat.py -h


import argparse
from functools import partial
import json
import re
from typing import NamedTuple, List, Pattern, Callable


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
            if not valid_test_func(test_lines):  # type: ignore
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
    first, second = regex.match(error_log).groups() # type: ignore
    return compare_func(first, second)


gene_names_re = re.compile(r"^.+?\s+\'(?P<current>\d+\.\d)\'\s+<=\s+\'(?P<previous>\d+)\'.+$")

def compare_projected_gene_names(current: str, previous: str) -> bool:
    # Obviously we can do fancier things here
    return float(current) <= float(previous)


xref_exists_re = re.compile(r"^.+?\s+\'(?P<current>\d+)\'\s+>\s+\'(?P<previous>\d+)\'.+$")

def compare_xref_exists(current: str, previous: str) -> bool:
    # Obviously we can do fancier things here
    return int(current) > int(previous)



got_expected_re = re.compile(r"^.+?\s+got: \'(?P<got>\d+)\'\s+expected: \'(?P<expected>\d+)\'.+$")

def compare_got_expected(got: str, expected: str) -> bool:
    # Obviously we can do fancier things here
    return int(got) == int(expected)


# TODO: Specify more analysis here
ANALYSIS_MAP = {
    'CompareGOXref': valid_compare_xref,
    'CompareProjectedGOXrefs': valid_compare_xref,
    'CompareXref': valid_compare_xref,
    'CompareProjectedGeneNames': partial(compare_two, gene_names_re, compare_projected_gene_names),
    'DuplicateTranscriptNames': partial(compare_two, got_expected_re, compare_got_expected),
    'DuplicateXref': partial(compare_two, got_expected_re, compare_got_expected),
    'HGNCMultipleGenes': partial(compare_two, got_expected_re, compare_got_expected),
    'XrefTypes': partial(compare_two, got_expected_re, compare_got_expected),
    'ForeignKeys': partial(compare_two, got_expected_re, compare_got_expected),
    'StableIdDisplayXref': partial(compare_two, got_expected_re, compare_got_expected),
    'XrefPrefixes': partial(compare_two, got_expected_re, compare_got_expected),
    'DisplayXrefExists': partial(compare_two, xref_exists_re, compare_xref_exists),
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
                            lines.append(f'\t\t{result}')
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
    args = parser.parse_args()

    with open(args.dc_file, 'r') as f:
        dcs = json.load(f)

    filter_species = None
    if args.filter_species:
        filter_species = set(args.filter_species)

    stats = dc_stats(dcs, filter_species)
    print(f'{"DATACHECK":<30}{"REPORTED":<20}{"SUSPICIOUS":<10}')

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
