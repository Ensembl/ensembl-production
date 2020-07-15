#!/usr/bin/env python

# Requirements:
#   Python 3.7+
# Usage example:
#   python dcparse.py /path/to/dc_dir -o failed_dc.json
# Print help:
#   python dcparse.py -h


import argparse
import json
import os
import re
from typing import Any, List, Dict, IO, Pattern


test_re = re.compile(r'^ {8}(not ok .+)$')
species_re = re.compile(r'^ {4}not ok \d+ - (.+)$')
dc_re = re.compile(r'^not ok \d+ - (\w+)$')
test_line_re = re.compile(r'^ {8}#(.+)$')
empty_re = re.compile(r'^$')


def skip_to(regex: Pattern, dc_file: IO, skip_empty: bool = True) -> str:
    for line in dc_file:
        if skip_empty and empty_re.match(line):
            continue
        match = regex.match(line)
        if match:
            return match.group(1)


def skip_multiple_lines(regex: Pattern, dc_file: IO, skip_empty: bool = True) -> List[str]:
    test_lines = []
    for line in dc_file:
        if skip_empty and empty_re.match(line):
            continue
        match = regex.match(line)
        if match:
            test_lines.append(match.group(1))
        else:
            return test_lines


def load_failed(dc_file: IO, data: Dict[str, Any]) -> None:
    for line in dc_file:
        match = test_re.match(line)
        if match:
            test = match.group(1)
            test_lines = skip_multiple_lines(test_line_re, dc_file)
            species = skip_to(species_re, dc_file)
            dc = skip_to(dc_re, dc_file)
            data.setdefault(dc, {}).setdefault(species, {}).setdefault('tests', {}).setdefault(test, []).extend(test_lines)


def parse_dc(dc_dir: str, out_file: str) -> None:
    data: Dict[str, Any] = {}
    for filename in os.listdir(dc_dir):
        if filename.endswith('.txt'):
            filepath = os.path.join(dc_dir, filename)
            with open(filepath, 'r') as dc_f:
                load_failed(dc_f, data)
    with open(out_file, 'w') as out_f:
        json.dump(data, out_f, indent=2)


def main():
    parser = argparse.ArgumentParser(description='DataChecks to JSON parser')
    parser.add_argument('dc_dir', type=str,
                        help='Path DataCheck files directory. All .txt files will be loaded.')
    parser.add_argument('-o', '--output-file', type=str,
                        help='Path to output JSON file. (Defaults to <dc_dir>/failed_dcs.json)')
    args = parser.parse_args()

    if args.output_file:
        out_file = args.output_file
    else:
        out_file = os.path.join(args.dc_dir, 'failed_dcs.json')

    parse_dc(args.dc_dir, out_file)


if __name__ == '__main__':
    main()

