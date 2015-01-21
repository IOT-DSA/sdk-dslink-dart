import 'dart:io';
import 'package:dslink/http_client.dart';
import 'package:dslink/src/crypto/pk.dart';
import 'package:dslink/requester.dart';
import 'package:dslink/common.dart';
import 'dart:async';
import 'package:cipher/digests/sha384.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cipher/digests/sha256.dart';

main() async {
  SHA256Digest sha = new SHA256Digest();
     print(sha.process(new Uint8List.fromList(UTF8.encode(''))));
     
     
  String str = new File('certs/private_key.txt').readAsStringSync();
  PrivateKey key = new PrivateKey.loadFromString(str);

  var link = new HttpClientLink('http://localhost:8080/conn', 'test-client-', key, isRequester: true);
  link.init();
  Requester requester = await link.onRequesterReady;

//  var updates = requester.invoke('/conns/test-responder-8', {
//    'msg': 'hello world'
//  });
//  
//  await for (var update in updates) {
//    print(update.rows);
//  }
  
  Stream<RequesterListUpdate> updates = requester.list('/conns/test-responder-8');

  await for (RequesterListUpdate update in updates) {
    print(update.changes);
  }
  
//  Stream<ValueUpdate> updates  = requester.subscribe('/conns/test-responder-8');
//  await for (ValueUpdate update in updates) {
//    print(update.value);
//  }
}
