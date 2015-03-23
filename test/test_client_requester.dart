import 'dart:io';
import 'package:dslink/client.dart';
import 'package:dslink/src/crypto/pk.dart';
import 'package:dslink/requester.dart';
import 'package:dslink/common.dart';
import 'dart:async';

main() async {
  PrivateKey key = new PrivateKey.loadFromString('1aEqqRYk-yf34tcLRogX145szFsdVtrpywDEPuxRQtM BGt1WHhkwCn2nWSDXHTg-IxruXLrPPUlU--0ghiBIQC7HMWWcNQGAoO03l_BQYx7_DYn0sn2gWW9wESbixzWuKg');

  var link = new HttpClientLink('http://localhost:8080/conn', 'test-rick-', key,
      isRequester: true);
  link.connect();
  Requester requester = await link.onRequesterReady;

  var c;
  c = requester.subscribe('/conns/locker-a/locker1/opened',(ValueUpdate update0){
    print(update0.value);
    c.cancel();
  });


}
