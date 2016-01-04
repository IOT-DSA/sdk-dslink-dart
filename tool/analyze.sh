#!/usr/bin/env bash
set -e

FILES=(
    bin/beacon.dart
    lib/browser_client.dart
    lib/client.dart
    lib/common.dart
    lib/dslink.dart
    lib/nodes.dart
    lib/requester.dart
    lib/responder.dart
    lib/server.dart
    lib/socket_client.dart
    lib/socket_server.dart
    lib/utils.dart
    lib/worker.dart
    lib/io.dart
    lib/historian.dart
)

for FILE in ${FILES[@]}
do
  dartanalyzer ${FILE}
done
