#!/usr/bin/env bash

sed -i '' -e "/args/s/^#//" ./../pubspec.yaml
sed -i '' -e "/bignum/s/^#//" ./../pubspec.yaml
sed -i '' -e "/cipher/s/^#//" ./../pubspec.yaml
sed -i '' -e "/cipher.git/s/^#//" ./../pubspec.yaml

sed -i '' -e "/pointycastle/ s/^#*/#/" ./../pubspec.yaml

sed -i '' -e "/^#.*msgpack: \"^0.9.0\"/s/^#//" ./../pubspec.yaml

sed -i '' -e "/msgpack:*$/ s/^#*/#/" ./../pubspec.yaml
sed -i '' -e "/tbelousova\/msgpack.dart/ s/^#*/#/" ./../pubspec.yaml

sed -i '' -e "/^#.*json_diff: '^0.1.2'/s/^#//" ./../pubspec.yaml

sed -i '' -e "/^json_diff:*$/s/^#//" ./../pubspec.yaml
sed -i '' -e "/json_diff:*$/ s/^#*/#/" ./../pubspec.yaml
sed -i '' -e "/tbelousova\/dart-json_diff/ s/^#*/#/" ./../pubspec.yaml

sed -i '' -e "/build_runner/ s/^#*/#/" ./../pubspec.yaml
sed -i '' -e "/build_test/ s/^#*/#/" ./../pubspec.yaml
sed -i '' -e "/build_web_compilers/ s/^#*/#/" ./../pubspec.yaml

sed -i '' -e "/dsbroker:/s/^#//" ./../pubspec.yaml
sed -i '' -e "/broker-dart.git/s/^#//" ./../pubspec.yaml

sed -i '' -e "/sdk: '>=2.0.0'/ s/^#*/#/" ./../pubspec.yaml
sed -i '' -e "/sdk: '>=1.13.0/s/^#//" ./../pubspec.yaml


sed -i '' -e "/test: any/ s/^#*/#/" ./../pubspec.yaml
sed -i '' -e "/test: '0.12.15+8'/s/^#//" ./../pubspec.yaml

sed -i '' -e '/\/\/Dart2-close-block/s,^\/\/*,,' ./../lib/src/crypto/dart/pk.dart
sed -i '' -e '/Dart2-open-block/s,^\/\/,\/,' ./../lib/src/crypto/dart/pk.dart

sed -i '' -e '/^Dart1-close-block/s,^,\/\/,' ./../lib/src/crypto/dart/pk.dart
sed -i '' -e '/Dart1-open-block/s,^\/*,\/\/,' ./../lib/src/crypto/dart/pk.dart

sed -i '' -e '/^Dart1-close-block/s,^,\/\/,' ./../lib/src/crypto/dart/isolate.dart
sed -i '' -e '/Dart1-open-block/s,^\/*,\/\/,' ./../lib/src/crypto/dart/isolate.dart


sed -i '' -e '/\/\/Dart2-close-block/s,^\/\/*,,' ./../lib/responder.dart
sed -i '' -e '/Dart2-open-block/s,^\/\/,\/,' ./../lib/responder.dart

sed -i '' -e '/^Dart1-close-block/s,^,\/\/,' ./../lib/responder.dart
sed -i '' -e '/Dart1-open-block/s,^\/*,\/\/,' ./../lib/responder.dart

sed -i '' -e '/^[^\/].*asFuture<T>/s,^,\/\/,' ./../lib/src/requester/request/subscribe.dart
sed -i '' -e '/asFuture\/\*<E>/s,\/\/,,' ./../lib/src/requester/request/subscribe.dart

sed -i '' -e '/convert_consts/s,^\/*,\/\/,' ./../lib/nodes.dart
sed -i '' -e '/convert_consts/s,^\/*,\/\/,' ./../example/browser/camera.dart
sed -i '' -e '/convert_consts/s,^\/*,\/\/,' ./../lib/io.dart

sed -i '' -e '/dart:convert/s,^\/\/*,,' ./../example/browser/camera.dart
sed -i '' -e '/dart:convert/s,^\/\/*,,' ./../lib/broker_discovery.dart


cp ./../lib/convert_consts.dart1 ./../lib/convert_consts.dart