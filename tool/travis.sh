#!/usr/bin/env bash
set -e

./tool/analyze.sh
./tool/test.sh
if [ "${TRAVIS_DART_VERSION}" == "stable" ]
then
  ./tool/docs.sh --upload
fi
