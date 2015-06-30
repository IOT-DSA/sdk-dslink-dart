#!/usr/bin/env bash
set -e
if [ -d "build" ]
then
  rm -rf build
fi
pub global activate dartdoc > /dev/null
mkdir -p build/docs
pub global run dartdoc --output build/docs
if [ "$1" == "--upload" ]
then
  git clone git@github.com:IOT-DSA/docs.git -b gh-pages --depth 1 build/tmp
  rm -rf build/tmp/sdks/dart
  mkdir -p build/tmp/sdks/dart
  cp -R build/docs/* build/tmp/sdks/dart/
  cd build/tmp
  git add .
  git commit -m "Update Docs for Dart SDK"
  git push origin gh-pages
fi
