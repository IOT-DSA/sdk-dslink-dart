import 'dart:io';
import 'package:dslink/client.dart';
import 'package:dslink/src/crypto/pk.dart';
import 'package:dslink/requester.dart';
import 'package:dslink/common.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:dslink/utils.dart';

main() async {
  PrivateKey key = new PrivateKey.loadFromString('1aEqqRYk-yf34tcLRogX145szFsdVtrpywDEPuxRQtM BGt1WHhkwCn2nWSDXHTg-IxruXLrPPUlU--0ghiBIQC7HMWWcNQGAoO03l_BQYx7_DYn0sn2gWW9wESbixzWuKg');

  var link = new HttpClientLink('http://rnd.iot-dsa.org/conn', 'rick-req-', key,
      isRequester: true);
  link.connect();
  Requester requester = await link.onRequesterReady;
  updateLogLevel('debug');

  // configure

  requester.subscribe('/upstream/benchmarks/conns/Benchmark-1/Node_1/Metric_1', (ValueUpdate update){print('${update.ts} : ${update.value}');}, 1);
}
