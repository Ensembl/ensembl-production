#!/bin/bash

export PERL5LIB=$PWD/bioperl-live:$PWD/ensembl-test/modules:$PWD/modules:$PWD/ensembl/modules:$PWD/ensembl-compara/modules:$PWD/ensembl-metadata/modules:$PWD/ensembl-datacheck/lib:$PWD/modules:$PWD/ensembl-hive/modules:$PWD/ensembl-orm/modules:$PWD/ensembl-metadata/modules:$PWD/ensembl-funcgen/modules:$PWD/ensembl-variation/modules:$PWD/modules:$PWD/ensembl-taxonomy/modules:$PWD/modules
export TEST_AUTHOR=$USER
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD/htslib

export PATH=$PATH:$PWD/htslib

echo "Running test suite"
echo "Using $PERL5LIB"
if [ "$COVERALLS" = 'true' ]; then
  PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl-test' perl $PWD/ensembl-test/scripts/runtests.pl -verbose $PWD/modules/t $SKIP_TESTS
else
  perl $PWD/ensembl-test/scripts/runtests.pl $PWD/modules/t $SKIP_TESTS
fi

rt=$?
if [ $rt -eq 0 ]; then
  if [ "$COVERALLS" = 'true' ]; then
    echo "Running Devel::Cover coveralls report"
    cover --nosummary -report coveralls
  fi
  exit $?
else
  exit $rt
fi
