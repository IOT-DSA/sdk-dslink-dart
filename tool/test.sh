#!/usr/bin/env bash

ARGS="${@}"

if [ -z "${ARGS}" ]
then
  ARGS="test/ -p vm -j 6"
fi

# This is broken. Investigate later.
# pub run test ${ARGS}
dart test/all.dart
