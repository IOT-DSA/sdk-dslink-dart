#!/usr/bin/env bash

ARGS="${@}"

if [ -z "${ARGS}" ]
then
  ARGS="test/ -p vm -j 6"
fi

pub run test ${ARGS}
