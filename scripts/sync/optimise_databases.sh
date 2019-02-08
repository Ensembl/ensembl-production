#!/bin/bash --

srv="mysql-ens-staging-3"

${srv} mysqlcheck  --all-databases --optimize --auto-repair

srv="mysql-ens-staging-4"

${srv} mysqlcheck  --all-databases --optimize --auto-repair
