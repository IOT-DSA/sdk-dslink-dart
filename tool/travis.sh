#!/usr/bin/env bash
set -e

./tool/analyze.sh
./tool/test.sh
./tool/docs.sh --upload
