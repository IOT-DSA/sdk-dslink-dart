#!/usr/bin/env bash
set -e

./tool/analyze.sh
./tool/test.sh
if [ "${TRAVIS_DART_VERSION}" == "stable" ] && [ "${TRAVIS_PULL_REQUEST}" == "false" ]
then
  openssl aes-256-cbc -K $encrypted_afe27f9b0c58_key -iv $encrypted_afe27f9b0c58_iv -in tool/id_rsa.enc -out ~\/.ssh/id_rsa -d
  ./tool/docs.sh --upload
fi
