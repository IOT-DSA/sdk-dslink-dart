#!/usr/bin/env bash
set -e

./tool/analyze.sh
./tool/test.sh

if [ "${TRAVIS_DART_VERSION}" == "dev" ] && [ "${TRAVIS_PULL_REQUEST}" == "false" ] && [ "${TRAVIS_BRANCH}" == "master" ] && [ "${TRAVIS_UPLOAD_DOCS}" == "true" ]
then
  if [ ! -d ${HOME}/.ssh ]
  then
    mkdir ${HOME}/.ssh
  fi

  git config --global user.name "Travis CI"
  git config --global user.email "travis@iot-dsa.org"
  openssl aes-256-cbc -K $encrypted_afe27f9b0c58_key -iv $encrypted_afe27f9b0c58_iv -in tool/id_rsa.enc -out ${HOME}/.ssh/id_rsa -d
  chmod 600 ${HOME}/.ssh/id_rsa
  echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ${HOME}/.ssh/config
  ./tool/docs.sh --upload
fi

if [ "${TRAVIS_DART_VERSION}" == "stable" ] && [ "${TRAVIS_PULL_REQUEST}" == "false" ] && [ "${TRAVIS_BRANCH}" == "master" ]
then
  if [ "${COVERALLS_TOKEN}" ]
  then
    pub global activate dart_coveralls
    pub global run dart_coveralls report \
      --token ${COVERALLS_TOKEN} \
      --retry 2 \
      --exclude-test-files \
      test/all.dart
  fi
fi
