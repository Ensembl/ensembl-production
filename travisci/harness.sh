#!/bin/bash

export PERL5LIB=$PWD/bioperl-live-bioperl-release-1-2-3:$PWD/ensembl-test/modules:$PWD/ensembl/modules:$PWD/ensembl-compara/modules:$PWD/ensembl-hive/modules:$PWD/ensembl-orm/modules:$PWD/modules

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD/htslib

export PATH=$PATH:$PWD/htslib

echo "Running test suite"
echo "Using $PERL5LIB"
if [ "$COVERALLS" = 'true' ]; then
    # PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl-test' perl $PWD/ensembl-test/scripts/runtests.pl -verbose $PWD/modules/t $SKIP_TESTS
    PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl-test' prove -v $PWD/modules/t/production_pipeline.t
    
else
    # perl $PWD/ensembl-test/scripts/runtests.pl $PWD/modules/t $SKIP_TESTS
    prove -v $PWD/modules/t/production_pipeline.t
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
