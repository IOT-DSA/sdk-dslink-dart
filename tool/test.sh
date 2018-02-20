#!/usr/bin/env bash
set -e

ARGS="${@}"

if [ -z "${ARGS}" ]
then
  ARGS="test/ -p vm"
fi

exec pub run test ${ARGS}
