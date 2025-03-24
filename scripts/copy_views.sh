#!/bin/bash

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2025] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# print out the shell commands needed to copy views from one database to
# another
# jgt 20250320

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'  # no colour

Help()
{
  echo "
this script prints out the commands needed to copy views from the specified
source MySQL instance to the specified target instance. It does NOT run the
commands; you need to cut and paste them into your shell yourself. We don't
attempt to run the commands because there may be dependencies between the views
(one view requires another view to exist) so you may need to re-order the
commands to get them to work.

By default, if a view already exists in the target database, the script skips
it and doesn't print the command needed to create it. You can force the script
to print all of the 'CREATE VIEW' commands by giving the '-n' option, which
skips the check and prints the command regardless.

You'll need to run this script from a shell that can see the MySQL aliases,
since it relies on those aliases for simplify connecting to the various
databases. Don't forget to use the admin account for the target DB or your
commands won't have the necessary permissions for creating the views.

Syntax: $0 -s <SRC> -t <TGT> -d <DB> [-h]
options:
  -s   source MySQL instance
  -S   source database name
  -t   target MySQL instance
  -T   target database name
  -n   don't check for views in the target DB
  -h   print this help message

Example: copy the views from the production instance of the metadata database
to a test instance on mysql-ens-test-1:

  $0 -s mysql-ens-production-1 -S ensembl_genome_metadata -t mysql-ens-test-1-ensadmin -T ensembl_genome_metadata_integrated_test
"
}

while getopts "s:S:t:T:nh" option; do
  case $option in
    h)
      Help
      exit;;
    \?)
      echo "Error: invalid option"
      Help
      exit;;
    s)
      SRC=$OPTARG;;
    S)
      SRC_DB=$OPTARG;;
    t)
      TGT=$OPTARG;;
    T)
      TGT_DB=$OPTARG;;
    n)
      SKIP_CHECK=1;;
  esac
done

printf "copying views from $GREEN$SRC:$SRC_DB$NC to $GREEN$TGT:$TGT_DB$NC\n\n"

# get the list of views; strip off the table header row
views=$($SRC -e 'SELECT TABLE_NAME FROM information_schema.tables  WHERE TABLE_TYPE LIKE "VIEW" and TABLE_SCHEMA = "ensembl_genome_metadata"' | tail -n +2)

echo "found these views in the source DB:"
for view in $views; do printf "  - $YELLOW$view$NC\n"; done
echo

for view in $views
do
  # echo "view: |$view|"

  # retrieve the view definition
  view_query_result=$($SRC $SRC_DB -e "SHOW CREATE VIEW $view" | tail -n +2)

  # strip off the inevitable unwanted fields and convert single quotes to
  # double quotes, otherwise we run into difficulties when wrapping the CREATE
  # statement in a shell command
  IFS=$'\t'
  tmp=($view_query_result)
  view_definition=$(echo ${tmp[1]} | tr "'" "\"")
  # echo "view definition: |$view_definition|"

  # check the same view doesn't already exist in the target DB
  if [ ! $SKIP_CHECK ]; then
    view_test=$($TGT -e "SHOW FULL TABLES IN $TGT_DB LIKE '$view'")
    if [ ! -z "${view_test}" ]; then
      printf "${RED}WARNING:${NC} ${YELLOW}$view${NC} already exists; skipping\n\n"
      continue
    fi
  fi

  printf "command to create view ${YELLOW}$view${NC}:\n"
  echo "$TGT $TGT_DB -e '$view_definition'"
  echo
done
